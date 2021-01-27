/*
	Copyright (C) 2015 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	This file contains the PacketTunnelProvider class. The PacketTunnelProvider class is a sub-class of NEPacketTunnelProvider, and is the integration point between the Network Extension framework and the SimpleTunnel tunneling protocol.
*/

import NetworkExtension
import SimpleTunnelServices
import SystemConfiguration
/// A packet tunnel provider object.
class PacketTunnelProvider: NEPacketTunnelProvider, TunnelDelegate, ClientTunnelConnectionDelegate {

	// MARK: Properties

	/// A reference to the tunnel object.
	var tunnel: ClientTunnel?

	/// The single logical flow of packets through the tunnel.
	var tunnelConnection: ClientTunnelConnection?

	/// The completion handler to call when the tunnel is fully established.
	var pendingStartCompletion: ((NSError?) -> Void)?

	/// The completion handler to call when the tunnel is fully disconnected.
	var pendingStopCompletion: ((Void) -> Void)?

	// MARK: NEPacketTunnelProvider
    var dnssvr:DNSServer?
	/// Begin the process of establishing the tunnel.
    /// Get a password from the keychain.
    func getPasswordWithPersistentReference(_ persistentReference: Data) -> String? {
        var result: String?
        let query: [AnyHashable: Any] = [
            kSecClass as AnyHashable : kSecClassGenericPassword,
            kSecReturnData as AnyHashable : kCFBooleanTrue,
            kSecValuePersistentRef as AnyHashable : persistentReference
        ]
        
        var returnValue: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &returnValue)
        
        if let passwordData = returnValue as? Data, status == errSecSuccess {
            result = NSString(data: passwordData, encoding: String.Encoding.utf8.rawValue) as? String
        }
        return result
    }
    func readPasswordDefaults() ->String {
        let defaults = UserDefaults(suiteName:"group.com.fuckgcd.Surf")
        return defaults?.object(forKey: "group.com.fuckgcd.password")  as! String
    }
    func prepareTunnelNetworkSettings(){
        
        let setting = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "240.0.0.2")
        let ipv4=NEIPv4Settings(addresses: ["240.0.0.1"], subnetMasks: ["255.255.255.255"])
        
        setting.iPv4Settings = ipv4
        var includedRoutes = [NEIPv4Route]()
        //includedRoutes.append(NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "0.0.0.0"))
        includedRoutes.append(NEIPv4Route.default())

        setting.iPv4Settings?.includedRoutes = includedRoutes
        var excludedRoutes = [NEIPv4Route]()
        var route = NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0")
        route.gatewayAddress = NEIPv4Route.default().gatewayAddress
        excludedRoutes.append(route)
        route = NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0")
        route.gatewayAddress = NEIPv4Route.default().gatewayAddress
        excludedRoutes.append(route)
        route = NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.192.0.0")
        route.gatewayAddress = NEIPv4Route.default().gatewayAddress
        excludedRoutes.append(route)
        setting.iPv4Settings?.excludedRoutes = excludedRoutes
        //newSettings.IPv4Settings?.includedRoutes = [NEIPv4Route.defaultRoute()]
        let dserver = SysUtil.loadSystemDNSServer() as String
        NSLog("dns server: %@", dserver)
        setting.dnsSettings = NEDNSSettings(servers: [ dserver ] )//dserver，["127.0.0.1"]
        NSLog("dns server: \(setting.dnsSettings)")

        setting.tunnelOverheadBytes = 150
        setting.proxySettings = NEProxySettings()
        setting.proxySettings?.autoProxyConfigurationEnabled = true;
        
        let path = Bundle.main.path(forResource: "2", ofType: "js")
        do {
            NSLog("use js")
            let js = try NSString(contentsOfFile: path!, encoding: String.Encoding.utf8.rawValue)
            setting.proxySettings?.proxyAutoConfigurationJavaScript = js as String
        }catch _ {
            NSLog("use url")
            setting.proxySettings?.proxyAutoConfigurationURL = URL(string: "http://192.168.2.69/2.js")
        }
        setting.tunnelOverheadBytes = 150
//        guard let settings = createTunnelSettingsFromConfiguration(newIPv4Dictionary) else {
//            pendingStartCompletion?(SimpleTunnelError.InternalError as NSError)
//            pendingStartCompletion = nil
//            return
//        }
        //settings.IPv4Settings
        NSLog("22222")
        setTunnelNetworkSettings(setting) { error in
            var startError: NSError?
            if let error = error {
                myLog(message: "Failed to set the tunnel network settings: \(error)")
                startError = SimpleTunnelError.BadConfiguration as NSError
            }
            else {
                // Now we can start reading and writing packets to/from the virtual interface.
                self.tunnelConnection?.startHandlingPackets()
                NSLog("pass self.tunnelConnection?.startHandlingPackets")
            }
            print(startError)
            // Now the tunnel is fully established, call the start completion handler.
            self.pendingStartCompletion?(startError)
            self.pendingStartCompletion = nil
            //set_config("108.61.126.194","14860","passwordxx","aes-256-cfb")
            //local_main()
            let  proxy = DispatchQueue(label: "proxy", attributes: [])
            proxy.async { () -> Void in
                let config = self.protocolConfiguration
                NSLog("-------%@",config);
                NSLog("get password")
                let passwd = self.readPasswordDefaults()//self.getPasswordWithPersistentReference(config.passwordReference!)
                NSLog("get password %@",passwd);
                guard let serverAddress = self.protocolConfiguration.serverAddress else {
                    NSLog("config error")
                    return
                }
                NSLog("%@",serverAddress);
                if let colonRange = serverAddress.rangeOfCharacter(from: CharacterSet(charactersIn: ":"), options: [], range: nil) {
                    // The server is specified in the configuration as <host>:<port>.
                    let hostname = serverAddress.substring(with: (serverAddress.startIndex ..< colonRange.lowerBound))
                    let portString = "22" //FIXME
                    //let portString = serverAddress.substring(with: (<#T##String.CharacterView corresponding to your index##String.CharacterView#>.index(after: colonRange.lowerBound) ..< serverAddress.endIndex))
                    myLog(message: "server host name : \(hostname) and port \(portString) ")
                    guard !hostname.isEmpty && !portString.isEmpty else {
                        NSLog("server config error")
                        return
                    }
                    
                    //endpoint = NWHostEndpoint(hostname:hostname, port:portString)
                    set_config(hostname,portString,passwd,config.username!)
                    local_main()
                    let config = self.protocolConfiguration
                    NSLog("-------%@",config);
                }
                self.dnssvr = DNSServer()
                //self.dnssvr?.startServer()
            }
        }

    }
    func startHandlingPackets() {
        packetFlow.readPackets { inPackets, inProtocols in
            self.handlePackets(inPackets, protocols: inProtocols)
        }
    }
    func handlePackets(_ packets: [Data], protocols: [NSNumber]) {
        NSLog("handlePackets %@", packets.count)
        // Read more packets.
        self.packetFlow.readPackets { inPackets, inProtocols in
            self.handlePackets(inPackets, protocols: inProtocols)
        }

    }
	override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        
        //vpn 拨号开始
		let newTunnel = ClientTunnel()
		newTunnel.delegate = self

		if let error = newTunnel.startTunnel(self) {
			completionHandler(error as NSError)
		}
		else {
			// Save the completion handler for when the tunnel is fully established.
			pendingStartCompletion = completionHandler
			tunnel = newTunnel
		}
        
	}

	/// Begin the process of stopping the tunnel.
	override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
		// Clear out any pending start completion handler.
        stopSocks()
		pendingStartCompletion = nil

		// Save the completion handler for when the tunnel is fully disconnected.
		pendingStopCompletion = completionHandler
		tunnel?.closeTunnel()
	}

	/// Handle IPC messages from the app.
	override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
		guard let messageString = NSString(data: messageData, encoding: String.Encoding.utf8.rawValue) else {
			completionHandler?(nil)
			return
		}

		myLog(message: "Got a message from the app: \(messageString)")

		let responseData = "Hello app".data(using: String.Encoding.utf8)
		completionHandler?(responseData)
	}

	// MARK: TunnelDelegate

	/// Handle the event of the tunnel connection being established.
	func tunnelDidOpen(_ targetTunnel: Tunnel) {
		// Open the logical flow of packets through the tunnel.
        NSLog("stop here")
        
        prepareTunnelNetworkSettings()
        //startHandlingPackets()
        return;
		let newConnection = ClientTunnelConnection(tunnel: tunnel!, clientPacketFlow: packetFlow, connectionDelegate: self)
		newConnection.open()
		tunnelConnection = newConnection
        
	}

	/// Handle the event of the tunnel connection being closed.
	func tunnelDidClose(_ targetTunnel: Tunnel) {
		if pendingStartCompletion != nil {
			// Closed while starting, call the start completion handler with the appropriate error.
			pendingStartCompletion?(tunnel?.lastError)
			pendingStartCompletion = nil
		}
		else if pendingStopCompletion != nil {
			// Closed as the result of a call to stopTunnelWithReason, call the stop completion handler.
			pendingStopCompletion?()
			pendingStopCompletion = nil
		}
		else {
			// Closed as the result of an error on the tunnel connection, cancel the tunnel.
			cancelTunnelWithError(tunnel?.lastError)
		}
		tunnel = nil
	}

	/// Handle the server sending a configuration.
	func tunnelDidSendConfiguration(_ targetTunnel: Tunnel, configuration: [String : AnyObject]) {
        print(configuration);
	}

	// MARK: ClientTunnelConnectionDelegate

	/// Handle the event of the logical flow of packets being established through the tunnel.
	func tunnelConnectionDidOpen(_ connection: ClientTunnelConnection, configuration: [AnyHashable: Any]) {

		// Create the virtual interface settings.
		guard let settings = createTunnelSettingsFromConfiguration(configuration) else {
			pendingStartCompletion?(SimpleTunnelError.InternalError as NSError)
			pendingStartCompletion = nil
			return
		}
        NSLog("send properties:%@ and setTunnelNetworkSettings %s",settings,#file)
		// Set the virtual interface settings.
		setTunnelNetworkSettings(settings) { error in
			var startError: NSError?
			if let error = error {
				myLog(message: "Failed to set the tunnel network settings: \(error)")
				startError = SimpleTunnelError.BadConfiguration as NSError
			}
			else {
				// Now we can start reading and writing packets to/from the virtual interface.
				self.tunnelConnection?.startHandlingPackets()
			}

			// Now the tunnel is fully established, call the start completion handler.
			self.pendingStartCompletion?(startError)
			self.pendingStartCompletion = nil
		}
	}

	/// Handle the event of the logical flow of packets being torn down.
	func tunnelConnectionDidClose(_ connection: ClientTunnelConnection, error: NSError?) {
		tunnelConnection = nil
		tunnel?.closeTunnelWithError(error)
	}

	/// Create the tunnel network settings to be applied to the virtual interface.
	func createTunnelSettingsFromConfiguration(_ configuration: [AnyHashable: Any]) -> NEPacketTunnelNetworkSettings? {
		guard let tunnelAddress = tunnel?.remoteHost,
			let address = getValueFromPlist(plist: configuration as [NSObject : AnyObject], keyArray: [.IPv4, .Address]) as? String,
			let netmask = getValueFromPlist(plist: configuration as [NSObject : AnyObject], keyArray: [.IPv4, .Netmask]) as? String
			else { return nil }

		let newSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: tunnelAddress)
		var fullTunnel = true

		newSettings.iPv4Settings = NEIPv4Settings(addresses: [address], subnetMasks: [netmask])

		if let routes = getValueFromPlist(plist: configuration as [NSObject : AnyObject], keyArray: [.IPv4, .Routes]) as? [[String: AnyObject]] {
			var includedRoutes = [NEIPv4Route]()
			for route in routes {
				if let netAddress = route[SettingsKey.Address.rawValue] as? String,
					let netMask = route[SettingsKey.Netmask.rawValue] as? String
				{
					includedRoutes.append(NEIPv4Route(destinationAddress: netAddress, subnetMask: netMask))
				}
			}
			newSettings.iPv4Settings?.includedRoutes = includedRoutes
			fullTunnel = false
		}
		else {
			// No routes specified, use the default route.
			newSettings.iPv4Settings?.includedRoutes = [NEIPv4Route.default()]
		}

		if let DNSDictionary = configuration[SettingsKey.DNS.rawValue] as? [String: AnyObject],
			let DNSServers = DNSDictionary[SettingsKey.Servers.rawValue] as? [String]
		{
			newSettings.dnsSettings = NEDNSSettings(servers: DNSServers)
			if let DNSSearchDomains = DNSDictionary[SettingsKey.SearchDomains.rawValue] as? [String] {
				newSettings.dnsSettings?.searchDomains = DNSSearchDomains
				if !fullTunnel {
					newSettings.dnsSettings?.matchDomains = DNSSearchDomains
				}
			}
		}

		newSettings.tunnelOverheadBytes = 150

		return newSettings
	}
//    /// Copy the default resolver configuration from the system on which the server is running.
//    class func copyDNSConfigurationFromSystem() -> ([String], [String]) {
//        let globalDNSKey = SCDynamicStoreKeyCreateNetworkGlobalEntity(kCFAllocatorDefault, kSCDynamicStoreDomainState, kSCEntNetDNS)
//        var DNSServers = [String]()
//        var DNSSearchDomains = [String]()
//        
//        // The default resolver configuration can be obtained from State:/Network/Global/DNS in the dynamic store.
//        
//        if let globalDNS = SCDynamicStoreCopyValue(nil, globalDNSKey) as? [NSObject: AnyObject],
//            servers = globalDNS[kSCPropNetDNSServerAddresses as String] as? [String]
//        {
//            if let searchDomains = globalDNS[kSCPropNetDNSSearchDomains as String] as? [String] {
//                DNSSearchDomains = searchDomains
//            }
//            DNSServers = servers
//        }
//        
//        return (DNSServers, DNSSearchDomains)
//    }
}
