#!/bin/bash

# variables (per pi)
export newhost=LCHR
# can be either 4ktouch, 4kscreen, standalone or LCHR

# DO FOR ALL
echo "Getting updates and installing utilities"
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install fbi git rsync rpi-update matchbox-window-manager uzbl xinit nodm Xorg unclutter feh jq tint2
git clone https://github.com/Photocentric3D/Photonic3D.git photonic-repo
sudo rpi-update

if [[ "[ "$newhost" == "4kscreen" ]" || "[ "$newhost" == "LCHR" ]" || "[ "$newhost" == "standalone" ]" ]]
	then
		echo "update photonic"
# would prefer to call this to update to a particular version,
# but the auto-update in start.sh will flatten updates made in the next section
# so doing this first.
		sudo /opt/cwh/stop.sh
		sudo /opt/cwh/start.sh
fi


# redirect boot terminal output not to screen
echo "removing pi branding"
sudo mv /boot/cmdline.txt /boot/cmdline.old 
sudo sh -c 'echo -n "loglevel=3 logo.nologo " > /boot/cmdline.txt'
sudo sh -c 'cat /boot/cmdline.old >> /boot/cmdline.txt'
sudo sed -i "s/tty1/tty/g" /boot/cmdline.txt

echo "installing common files"
sudo rsync -avr photonic-repo/host/common/ /
sudo rsync -avr photonic-repo/host/resourcesnew/printflow /opt/cwh/resourcesnew/ #keep printflow without the 
sudo cp photonic-repo/host/os/Linux/armv61/pdp /opt/cwh/os/Linux/armv61/pdp
sudo cp photonic-repo/host/resourcesnew/printflow/holdingpage.html /home/pi/holdingpage.html
cp /etc/splash.png ~/.splash.png
sudo chown root /etc/splash.png
sudo chmod 777 /etc/splash.png
sudo chmod a+x /etc/init.d/aasplashscreen
sudo insserv /etc/init.d/aasplashscreen

echo "disabling screen power down"
if [ -e "/etc/default/nodm" ]
	then
		sudo sed -i "s/=false/=true/g" /etc/default/nodm
		sudo sed -i "s/root/pi/g" /etc/default/nodm
	else
		echo "nodm doesn't exist"
fi
#this already happens once due to our rsync of an X11 config, but why not just make sure, eh?

echo "Working on per printer settings..."
sudo sh -c 'echo \#Photocentric mods >> /boot/config.txt'

if [[ "[ "$newhost" == "4ktouch" ]" || "[ "$newhost" == "LCHR" ]" || "[ "$newhost" == "standalone" ]" ]]
	then
		# Touchscreen pis only
		echo "Modifying config files for touchscreen"
		sudo sh -c 'echo disable_splash=1 >> /boot/config.txt'
		sudo sh -c 'echo lcd_rotate=2 >> /boot/config.txt'
		sudo sh -c 'echo avoid_warnings=1 >> /boot/config.txt'
		echo "installing kiosk browser"
		#wget http://steinerdatenbank.de/software/kweb-1.7.4.tar.gz
		#tar -xzf kweb-1.7.4.tar.gz
		#cd kweb-1.7.4
		#./debinstall
		#rm -rf kweb-1.7.4
		wget -qO - http://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
		sudo sh -c 'echo "deb http://dl.bintray.com/kusti8/chromium-rpi jessie main" | sudo tee -a /etc/apt/sources.list'
		sudo apt-get update && sudo apt-get install -y youtube-dl
		#HACK: installing youtube-dl just because it causes kweb installation script to ask a question that must be replied to on keyboard otherwise
		sudo apt-get install -y kweb
		
		echo "Setting up kiosk-only mode"
		touch /home/pi/.xsession
		echo \#\!/bin/bash >> /home/pi/.xsession
		echo xset s off >> /home/pi/.xsession
		echo xset -dpms >> /home/pi/.xsession
		echo xset s noblank >> /home/pi/.xsession
		
		
		if [ $newhost == "4ktouch" ]; 
			then
				target=4kscreen
			else
				target=$newhost
		fi
		
		
		if [ $newhost == "4ktouch" ]; 
			then
			echo unclutter -jitter 1 -idle 0.2 -noevents -root \& feh --bg /home/pi/.splash.png \& exec matchbox-window-manager -use_titlebar no \& >> /home/pi/.xsession
			echo while true\; do >> /home/pi/.xsession
			echo \#uzbl -u /home/pi/holdingpage.html?target=http://$target.local:9091/printflow -c /home/pi/uzbl.conf \&\; >> /home/pi/.xsession
			echo kweb -KJ /home/pi/holdingpage.html?target=http://$target.local:9091/printflow; >> /home/pi/.xsession
			#echo exec matchbox-window-manager -use_titlebar no\; >> /home/pi/.xsession
			echo sleep 2s\; >> /home/pi/.xsession
			echo done >> /home/pi/.xsession
			else
			echo setting up kiosk browser with photonic install
			#TODO
		fi
		
		#keeping this as a fallback for kweb as sometimes kweb servers can be offline
		touch /home/pi/uzbl.conf
		echo set show_status=0 >> /home/pi/uzbl.conf
		echo set geometry=maximized >> /home/pi/uzbl.conf
		
fi

if [ "$newhost" == "4ktouch" ]
	then
		#4K touchscreen only

		#enabling NTP listening 
		echo setting up network time client
		sudo sed -i "s/\#disable/disable/g" /etc/ntp.conf
		sudo sed -i "s/\#broadcastclient/broadcastclient/g" /etc/ntp.conf
		sudo /etc/init.d/ntp restart
fi

if [ "$newhost" == "4kscreen" ]
	then
		echo "Installing 4k support"
		sudo sh -c 'echo hdmi_group=2 >> /boot/config.txt'
		sudo sh -c 'echo hdmi_mode=87 >> /boot/config.txt'
		sudo sh -c 'echo hdmi_cvt 3840 2160 24 >> /boot/config.txt'
		sudo sh -c 'echo max_framebuffer_width=3840 >> /boot/config.txt'
		sudo sh -c 'echo max_framebuffer_height=2160 >> /boot/config.txt'
		sudo sh -c 'echo hdmi_pixel_freq_limit=400000000 >> /boot/config.txt'
		
		#TODO - add network time propogation to support 4ktouch. Currently built into WG images, but not setup by shell script yet
		echo "setting up Photocentric Pro profile"
		wget https://raw.githubusercontent.com/Photocentric3D/Photonic3D/master/host/printers/Photocentric%20Pro.json -O printerprofile.json
		curl -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' -d @printerprofile.json 'http://localhost:9091/services/printers/save'
fi

if [ "$newhost" == "LCHR" ]
	then
		echo "setting up high resolution screen"
		sudo sh -c 'echo hdmi_group=2 >> /boot/config.txt'
		sudo sh -c 'echo hdmi_mode=87 >> /boot/config.txt'
		sudo sh -c 'echo hdmi_cvt 2048 1536 30 >> /boot/config.txt'
		sudo sh -c 'echo max_framebuffer_width=2048 >> /boot/config.txt'
		sudo sh -c 'echo max_framebuffer_height=1536 >> /boot/config.txt'
		sudo sh -c 'echo hdmi_pixel_freq_limit=400000000 >> /boot/config.txt'

		echo "installing Photocentric Liquid Crystal HR profile"
		wget https://raw.githubusercontent.com/Photocentric3D/Photonic3D/master/host/printers/photocentric%20hr.json -O printerprofile.json
		curl -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' -d @printerprofile.json 'http://localhost:9091/services/printers/save'
fi


if [ "$newhost" == "standalone" ]
	then
		echo "creating standalone image..."
		#TODO
		echo "installing Photocentric 10 profile"
		wget https://raw.githubusercontent.com/Photocentric3D/Photonic3D/master/host/printers/photocentric%2010.json -O printerprofile.json
		curl -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' -d @printerprofile.json 'http://localhost:9091/services/printers/save'
fi

# Change hostname
# left this 'til last for good reasons. Keep it last now.
hostn=$(cat /etc/hostname)
echo "Existing hostname is $hostn, changing to $newhost"
sudo sed -i "s/$hostn/$newhost/g" /etc/hosts
sudo sed -i "s/$hostn/$newhost/g" /etc/hostname
echo "Your new hostname is $newhost, accessible from $newhost.local"

rm -rf photonic-repo

sudo apt-get clean
sudo reboot