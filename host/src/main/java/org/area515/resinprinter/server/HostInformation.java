package org.area515.resinprinter.server;

import java.net.InetAddress;
import java.util.ArrayList;
import java.util.List;

public class HostInformation {
	private String deviceName;
	private String manufacturer;
	private List<InetAddress> IP = new ArrayList<InetAddress>();
	
	private HostInformation() {}
	
	public HostInformation(String deviceName, String manufacturer) {
		this.deviceName = deviceName;
		this.manufacturer = manufacturer;
	}
	
	public HostInformation(String deviceName, String manufacturer, List<InetAddress> IP) {
		this.deviceName = deviceName;
		this.manufacturer = manufacturer;
		this.IP = IP;
	}

	public String getDeviceName() {
		return deviceName;
	}
	public void setDeviceName(String deviceName) {
		this.deviceName = deviceName;
	}

	public String getManufacturer() {
		return manufacturer;
	}
	public void setManufacturer(String manufacturer) {
		this.manufacturer = manufacturer;
	}
	
	public List<InetAddress> getIPs() {
		return IP;
	}
	
	public void setIPs(List<InetAddress> IP){
		this.IP = IP;
	}
}
