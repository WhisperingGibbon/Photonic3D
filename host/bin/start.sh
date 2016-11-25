#!/bin/bash

##### FUNCTIONS #####

function networkup {
  # Initialize number of attempts
  reachable=$1
  while [ $reachable -ne 0 ]; do
    # Ping supplied host
    ping -q -c 1 -W 1 "$2" > /dev/null 2>&1
    # Check return code
    if [ $? -eq 0 ]; then
      # Success, we can exit with the right return code
      echo 0
      return
    fi
    # Network down, decrement counter and try again
    let reachable-=1
    # Sleep for one second
    sleep 1
  done
  # Network down, number of attempts exhausted, quiting
  echo 1
}

function timestamp {
  echo $(date "+%d/%m/%y %H:%M:%S")
}

##### MAIN #####

#TimeStamp the output
#log.scrout
echo "["$(timestamp)"] Starting script"
#log.screrr
echo "["$(timestamp)"] Starting script"

# require superuser
if [[ $UID != 0 ]]; then
    echo "["$(timestamp)"] Please run this script with sudo:"
    echo "["$(timestamp)"] sudo $0 $*"
    echo "["$(timestamp)"] FAIL: Script not started as superuser" >&2
    exit 1
fi

source "$(dirname $(readlink -f $0))/repoconfig.sh"

echo "["$(timestamp)"] Local Config: $CONFIG_PROPS"

if [ -f ${CONFIG_PROPS} ]; then
  CONFIG_REPO=$(grep '^updateRepo' "${CONFIG_PROPS}" | cut -d= -f 2 | awk '$1=$1')
  if [[ ${CONFIG_REPO} ]]; then
    DEFAULT_REPO="${CONFIG_REPO}"
  fi
fi

if [ -z "$1" ]; then
	repo=${DEFAULT_REPO}
else
	if [[ $1 =~ .*Creation-Workshop-Host.* ]] || [[ $1 =~ .*Photonic3D.* ]]; then
		repo=$1
	else
		repo="$1/Photonic3D"
	fi;
fi;

if [ "$2" == "TestKit" ]; then
	downloadPrefix=photonic$2-
	installDirectory=/opt/cwh$2
else
	downloadPrefix=photonic-
	installDirectory=/opt/cwh
fi;


# get argument as to photocentric build flavour
if [ ! -z "$3" ]; then
  	PHOTOCENTRIC_HARDWARE=$3
	if [ ! $PHOTOCENTRIC_HARDWARE == "standalone" ]; then
		PHOTOCENTRIC_HARDWARE="Photocentric 10"
	fi	
	if [ ! $PHOTOCENTRIC_HARDWARE == "LCHR" ]; then
		PHOTOCENTRIC_HARDWARE="LC HR"
	fi	

fi

if [ ! -e /etc/photocentric/printerconfig.ini ]; then
	mkdir /etc/photocentric
	touch /etc/photocentric/printerconfig.ini
	echo "export printername=\"$PHOTOCENTRIC_HARDWARE\"" >> /etc/photocentric/printerconfig.ini
	export printername=$PHOTOCENTRIC_HARDWARE
fi


#Its pretty hard to keep these updated, let me know when they get too old
if [ "${cpu}" = "armv6l" -o "${cpu}" = "armv7l" ]; then
	javaURL="http://download.oracle.com/otn-pub/java/jdk/8u101-b13/jdk-8u101-linux-arm32-vfp-hflt.tar.gz"
elif [ "${cpu}" = "i686" ]; then
	javaURL="http://download.oracle.com/otn-pub/java/jdk/8u102-b14/jdk-8u102-linux-i586.tar.gz"
elif [ "${cpu}" = "x86_64" ]; then
	javaURL="http://download.oracle.com/otn-pub/java/jdk/8u102-b14/jdk-8u102-linux-x64.tar.gz"
elif [ "${cpu}" = "aarch64" ]; then
	javaURL="http://download.oracle.com/otn-pub/java/jdk/8u101-b13/jdk-8u101-linux-arm64-vfp-hflt.tar.gz"
fi

#This application will always need to have the display set to the following
export DISPLAY=:0.0
xinitProcess=`ps -ef | grep grep -v | grep xinit`
if [ -z "${xinitProcess}" ]; then
    echo No X server running, starting and configuring one
    startx &
    xhost +x
fi

if [ $(networkup 20 www.github.com) -eq 1 ]; then
	echo "["$(timestamp)"] unable to update, no network connection. Starting Photonic3D OFFLINE"
	echo "["$(timestamp)"] WARN: Script not started as superuser" >&2
else 
	if [ ! -f "/usr/lib/jni/librxtxSerial.so" ]; then
		echo "["$(timestamp)"] Installing RxTx"
		apt-get install --yes --force-yes librxtx-java
	fi

	#Copy the zip file from the current directory into the cwh directory for offline install
	mkdir -p ${installDirectory}
	mv ${downloadPrefix}.*.zip ${installDirectory}

	#install java if version is too old
	javaInstalled=`which java`
	if [ "$javaInstalled" = "" ]; then
		javaMajorVersion=0
		javaMinorVersion=0
	else
		javaMajorVersion=`java -version 2>&1 | grep "java version" | awk -F[\".] '{print "0"$2}'`
		javaMinorVersion=`java -version 2>&1 | grep "java version" | awk -F[\".] '{print "0"$3}'`
	fi

	if [ "$javaMinorVersion" -lt 8 -a "$javaMajorVersion" -le 1 ]; then
		downloadJavaFile=`echo ${javaURL} | awk -F/ '{print $(NF)}'`
		echo "["$(timestamp)"] Either Java is not installed, or an incorrect version of Java is installed. Installing from this URL: ${javaURL}"
		mkdir -p /usr/lib/jvm
		cd /usr/lib/jvm
		rm ${downloadJavaFile}
		wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "${javaURL}"

		firstSnapshot=`ls -1`
		echo "["$(timestamp)"] Unzipping and installing Java now"
		tar xzf ${downloadJavaFile}
		secondSnapshot=`ls -1`
		javaInstallFile=`echo "$firstSnapshot"$'\n'"$secondSnapshot" | sort | uniq -u`

		if [ -z "${javaInstallFile}" ]; then
			echo "["$(timestamp)"] A new version of Java is available, please update this script with the proper download URLS from: http://www.oracle.com/technetwork/java/javase/downloads/index.html"
			echo "["$(timestamp)"] FAIL: New version of java, but unable to install" >&2
			exit
		fi

		ln -sf /usr/lib/jvm/${javaInstallFile}/bin/java /usr/bin/java
		ln -sf /usr/lib/jvm/${javaInstallFile}/bin/javac /usr/bin/javac
		ln -sf /usr/lib/jvm/${javaInstallFile}/bin/keytool /usr/bin/keytool
		rm ${downloadJavaFile}
	fi

	#Determine if a new install is available
	echo "["$(timestamp)"] Checking for new version from Github Repo: ${repo}"
	cd ${installDirectory}
	LOCAL_TAG=$(grep repo.version build.number | cut -d = -f 2 | tr -d '\r')
	NETWORK_TAG=$(curl -L -s https://api.github.com/repos/${repo}/releases/latest | grep 'tag_name' | cut -d\" -f4)

	echo "["$(timestamp)"] Local Tag: "${LOCAL_TAG}
	echo "["$(timestamp)"] Network Tag: "${NETWORK_TAG}

	if [ -f ${downloadPrefix}.*.zip ]; then
		OFFLINE_FILE=$(ls ${downloadPrefix}.*.zip)
		echo "["$(timestamp)"] Performing offline install of ${OFFLINE_FILE}"

		mv ${OFFLINE_FILE} ~
		rm -r ${installDirectory}
		mkdir -p ${installDirectory}
		cd ${installDirectory}
		mv ~/${OFFLINE_FILE} .
		unzip ${OFFLINE_FILE}
		chmod 777 *.sh
		rm ${OFFLINE_FILE}
	elif [ -z "${NETWORK_TAG}" ]; then
		echo "["$(timestamp)"] Couldn't fetch version from GitHub, launching existing install."
		echo "["$(timestamp)"] WARN: Unable to get version from GitHub" >&2
	elif [ "${NETWORK_TAG}" != "${LOCAL_TAG}" -o "$2" == "force" ]; then
		echo "["$(timestamp)"] Installing latest version of ${downloadPrefix}: ${NETWORK_TAG}"

		DL_URL=$(curl -L -s https://api.github.com/repos/${repo}/releases/latest | grep 'browser_' | cut -d\" -f4 | grep -- -${NETWORK_TAG})
		DL_FILE=${DL_URL##*/}
		rm -f "/tmp/${DL_FILE}"
		wget -P /tmp "${DL_URL}"
		if [ $? -ne 0 ]; then
			echo "["$(timestamp)"] wget of ${DL_FILE} failed. Aborting update."
			echo "["$(timestamp)"] FAIL: wget of ${DL_FILE} failed. Exiting." >&2
			exit 1
		fi



		rm -r ${installDirectory}
		mkdir -p ${installDirectory}
		cd ${installDirectory}
		mv "/tmp/${DL_FILE}" .

		unzip ${DL_FILE}

		chmod 777 *.sh
		# grab dos2unix from the package manager if not installed
		command -v dos2unix >/dev/null 2>&1 || { apt-get install --yes --force-yes dos2unix >&2; }
		grep -lU $'\x0D' *.sh | xargs dos2unix
		# ensure the cwhservice always is linux format and executable
		grep -lU $'\x0D' /etc/init.d/cwhservice | xargs dos2unix
		chmod +x /etc/init.d/cwhservice
		chmod +x /opt/cwh/os/Linux/armv61/pdp
		rm ${DL_FILE}
	else
		echo "["$(timestamp)"] No install required"
		echo "["$(timestamp)"] INFO: Photonic up-to-date" >&2
	fi
  
fi



echo "["$(timestamp)"] Turning off screen saver and power saving"
xset s off         # don't activate screensaver
xset -dpms         # disable DPMS (Energy Star) features
xset s noblank     # don't blank the video device

echo "["$(timestamp)"] configuring printflow interface"
source /etc/photocentric/printerconfig.ini
touch photocentric/printflow/js/printerconfig.js
touch resourcesnew/printflow/js/printerconfig.js
echo var printerName = \"$printername\"\; > photocentric/printflow/js/printerconfig.js
echo var repo = \"$repo\"\; >> photocentric/printflow/js/printerconfig.js
echo var printerName = \"$printername\"\; > resourcesnew/printflow/js/printerconfig.js
echo var repo = \"$repo\"\; >> resourcesnew/printflow/js/printerconfig.js


if [ "$printername" != "Photocentric 10" ]; then
	# disable wlan0 because we don't want to use it
	echo "["$(timestamp)"] Disabling on-board wireless"
	echo "["$(timestamp)"] INFO: wlan0 disabled" >&2
	ifconfig wlan0 down
fi	

if [ ! -f "/etc/init.d/cwhservice" ]; then
	echo "["$(timestamp)"] Installing Photonic3D as a service"
	echo "["$(timestamp)"] INFO: Photonic installed as service" >&2
	cp ${installDirectory}/cwhservice /etc/init.d/
	chmod 777 /etc/init.d/cwhservice
	update-rc.d cwhservice defaults
fi

echo "["$(timestamp)"] Determining if one time install has occurred"
performedOneTimeInstall=$(grep performedOneTimeInstall ${CONFIG_PROPS} | awk -F= '{print $2}')
if [ -f "oneTimeInstall.sh" -a [${performedOneTimeInstall} != "true"] ]; then
	echo "["$(timestamp)"] INFO: Running one time installer script" >&2
	./oneTimeInstall.sh
fi

if [ -f "eachStart.sh" ]; then
	echo "["$(timestamp)"] INFO: Running eachstart script" >&2
	./eachStart.sh
fi

if [ -e "/opt/cwh/resourcesnew/printflow/js/printerconfig.js" ]; then
	echo "["$(timestamp)"] INFO: Running focus script" >&2
	./focus.sh &
fi

# kill any lingering pdp sessions
pkill -9 "pdp"


#log.scrout
echo "["$(timestamp)"] Launching Photonic"
#log.screrr
echo "["$(timestamp)"] INFO: Launching Photonic" >&2

if [ "$2" == "debug" ]; then
	pkill -9 -f "org.area515.resinprinter.server.Main"
	echo "Starting printer host server($2)"
	java -Xmx256m -Xms256m -Xdebug -Xrunjdwp:server=y,transport=dt_socket,address=4000,suspend=n -Dlog4j.configurationFile=debuglog4j2.properties -Djava.library.path=/usr/lib/jni:os/Linux/${cpu} -cp lib/*:. org.area515.resinprinter.server.Main > log.out 2> log.err &
	./datalog.sh &
elif [ "$2" == "TestKit" ]; then
	pkill -9 -f "org.area515.resinprinter.test.HardwareCompatibilityTestSuite"
	echo Starting test kit
	java -Xmx256m -Xms256m -Dlog4j.configurationFile=testlog4j2.properties -Djava.library.path=/usr/lib/jni:os/Linux/${cpu} -cp lib/*:. org.junit.runner.JUnitCore org.area515.resinprinter.test.HardwareCompatibilityTestSuite &
else
	pkill -9 -f "org.area515.resinprinter.server.Main"
	echo Starting printer host server
	java -Xmx256m -Xms256m -Dlog4j.configurationFile=log4j2.properties -Djava.library.path=/usr/lib/jni:os/Linux/${cpu} -cp lib/*:. org.area515.resinprinter.server.Main > log.out 2> log.err &
fi
echo "["$(timestamp)"] INFO: Photonic launced successfully. Start.sh complete." >&2
