var printStatus = "";
var jobId="";
var runningjobName="";
            
function startpage(){
        //handles page setup and the common things across all pages:
        
        setInterval(function() {
                //time handling/updating
		document.getElementById("time").innerHTML = moment().format("HH:mm:ss[<br>]DD-MMM-YY");
                //wifi updating
                wifiupdate();
                //redirect to print dialogue on user initiating a print
                printredirect();
	}, 1000);
}

function wifiupdate(){
	//TODO: JSON to query the server's wifi status and display it
        
        $.getJSON("../services/machine/wirelessNetworks/getWirelessStrength")
        .done(function (data){
		if ((typeof data !== 'undefined')&&(data !== null)){
			console.log(data);
			signalstrength = parseInt(data);
		}
		else{
			signalstrength = -100;
		}
		})
        .fail(function(){
                // there's been a problem - give signal strength the lowest value
                signalstrength = -100;
        });
        
	// in the meantime for testing purposes, choose a random number.
	// signalstrength = Math.floor(Math.random() * -60)-30; //signal strength in dBm
        
        //using this as a guide for decent signal strengths in dBm: https://support.metageek.com/hc/en-us/articles/201955754-Understanding-WiFi-Signal-Strength
        if (signalstrength > -45) {
		wifiurl="images/wifi-3.png";
        }
        else if (signalstrength > -67) {
                wifiurl="images/wifi-2.png";
        }
        else if (signalstrength > -72) {
                wifiurl="images/wifi-1.png";
        }
        else if (signalstrength > -80) {
                wifiurl="images/wifi-0.png";
        }
        else wifiurl="images/wifi-nc.png";

	document.getElementById("wifi").src = wifiurl;
}
            
function printredirect(){
        if ((typeof printerName === 'undefined')||(String(window.location.href).indexOf("error.html") >= 0)) {
            //do nothing as there'll be a new call in 1 second, or we're on the error page and we don't want to redirect from that without the user dismissing the error.
        }
        else{
		//send the user to the printdialogue page if a print is in progress.
                $.getJSON("../services/printJobs/getByPrinterName/"+encodeURI(printerName)).done(function (data){
			if ((typeof data !== 'undefined')&&(data !== null)){
				console.log(data);
				printStatus= (data.status);
                                jobId = (data.id);
                                runningjobName = (data.jobName);
			}
			else{
				//not printing
			}
		});
             
		if (printStatus=="Failed"){
                        //use cookies to check that this error has not been reported already for the unique job id. Otherwise you'll be stuck in a constant loop of being forced back to the error screen.
                        if ((typeof Cookies.get('lastfailedjob') === 'undefined')||(Cookies.get('lastfailedjob')!=jobId)){
                                Cookies.set('lastfailedjob',jobId);
                                window.location.href=("error.html?errorname=Print Failed&errordetails=The print of "+runningjobName+" [Job ID: "+jobId+"] has unexpectedly failed.&errordetails2=Please retry the print, and if the issue persists, contact Technical Support via <b>www.photocentric3d.com</b>");
                        }
		}
		if (printStatus=="Printing"){
			if (String(window.location.href).indexOf("printdialogue") < 0){
				window.location.href="printdialogue.html";
			}
		}
                if (printStatus=="Cancelling"){
                         if ((typeof Cookies.get('lastcancelledjob') === 'undefined')||(Cookies.get('lastcancelledjob')!=jobId)){
                                Cookies.set('lastcancelledjob',jobId);
                                window.location.href=("error.html?type=info&errorname=Print Cancelled&errordetails=The print of <b>"+runningjobName+"</b> [Job ID: "+jobId+"] was cancelled.");
                        }
		}
    }				
}

function urlParam (name){
	var results = new RegExp('[\?&]' + name + '=([^&#]*)').exec(window.location.href);
	if ((results !== null)&&(results[1] !== null)){
        	return results[1];
    	}
	else{
		return null;
	}
}