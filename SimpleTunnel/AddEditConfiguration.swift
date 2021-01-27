/*
	Copyright (C) 2015 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	This file contains the AddEditConfiguration class, which is responsible for controlling a view used to create or edit a VPN configuration.
*/

import UIKit
import NetworkExtension
import Security
import SimpleTunnelServices

/// A view controller object for a table view containing input fields used to specify configuration parameters for a VPN configuration.
class AddEditConfiguration: ConfigurationParametersViewController {

	// MARK: Properties

	/// A table view cell containing the text field where the name of the configuration is entered.
	@IBOutlet weak var nameCell: TextFieldCell!

	/// A table view cell containing the text field where the server address of the configuration is entered.
	@IBOutlet weak var serverAddressCell: TextFieldCell!

	/// A table view cell containing the text field where the username of the configuration is entered.
	@IBOutlet weak var usernameCell: TextFieldCell!

	/// A table view cell containing the text field where the password of the configuration is entered.
	@IBOutlet weak var passwordCell: TextFieldCell!

	/// A table view cell containing a switch used to enable and disable Connect On Demand for the configuration.
	@IBOutlet weak var onDemandCell: SwitchCell!

	/// A table view cell containing a switch used to enable and disable proxy settings for the configuration.
	@IBOutlet weak var proxiesCell: SwitchCell!

	/// A table view cell containing a switch used to enable and disable Disconnect On Sleep for the configuration.
	@IBOutlet weak var disconnectOnSleepCell: SwitchCell!

	/// A table view cell that when tapped transitions the app to a view where the Connect On Demand rules are managed.
	@IBOutlet weak var onDemandRulesCell: UITableViewCell!

	/// A table view cell that when tapped transitions the app to a view where the proxy settings are managed.
	@IBOutlet weak var proxySettingsCell: UITableViewCell!

	/// The NEVPNManager object corresponding to the configuration being added or edited.
	var targetManager: NEVPNManager = NEVPNManager.shared()

	// MARK: UIViewController

	/// Handle the event of the view being loaded into memory.
	override func viewDidLoad() {
		super.viewDidLoad()

		// Set up the table view cells

		cells = [
			nameCell,
			serverAddressCell,
			usernameCell,
			passwordCell,
			onDemandCell,
			proxiesCell,
			disconnectOnSleepCell
		].flatMap { $0 }

		// The switch in proxiesCell controls the display of proxySettingsCell
		proxiesCell.dependentCells = [ proxySettingsCell ]
		proxiesCell.getIndexPath = {
			return self.getIndexPathOfCell(self.proxiesCell)
		}
		proxiesCell.valueChanged = {
			self.updateCellsWithDependentsOfCell(self.proxiesCell)
		}

		// The switch in onDemandCell controls the display of onDemandRulesCell
		onDemandCell.dependentCells = [ onDemandRulesCell ]
		onDemandCell.getIndexPath = {
			return self.getIndexPathOfCell(self.onDemandCell)
		}
		onDemandCell.valueChanged = {
			self.updateCellsWithDependentsOfCell(self.onDemandCell)
			self.targetManager.isOnDemandEnabled = self.onDemandCell.isOn
		}

		disconnectOnSleepCell.valueChanged = {
			self.targetManager.protocolConfiguration?.disconnectOnSleep = self.disconnectOnSleepCell.isOn
		}

		nameCell.valueChanged = {
			self.targetManager.localizedDescription = self.nameCell.textField.text
		}

		serverAddressCell.valueChanged = {
			self.targetManager.protocolConfiguration?.serverAddress = self.serverAddressCell.textField.text
		}

		usernameCell.valueChanged = {
			self.targetManager.protocolConfiguration?.username = self.usernameCell.textField.text
		}
        
        
	}

	/// Handle the event of the view being displayed.
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		tableView.reloadData()

		// Set the text fields and switches per the settings in the configuration.

		nameCell.textField.text = targetManager.localizedDescription
		serverAddressCell.textField.text = targetManager.protocolConfiguration?.serverAddress
		usernameCell.textField.text = targetManager.protocolConfiguration?.username

		if let passRef = targetManager.protocolConfiguration?.passwordReference {
			passwordCell.textField.text = getPasswordWithPersistentReference(passRef)
		}
		else {
			//passwordCell.textField.text = nil
            self.readPasswordDefaults()
		}

		disconnectOnSleepCell.isOn = targetManager.protocolConfiguration?.disconnectOnSleep ?? false

		onDemandCell.isOn = targetManager.isOnDemandEnabled

		onDemandRulesCell.detailTextLabel?.text = getDescriptionForListValue(targetManager.onDemandRules, itemDescription: "rule")

		proxiesCell.isOn = targetManager.protocolConfiguration?.proxySettings != nil
	}

	/// Set up the destination view controller of a segue away from this view controller.
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		guard let identifier = segue.identifier else { return }

		switch identifier {
			case "edit-proxy-settings":
				// The user tapped on the proxy settings cell.
				guard let controller = segue.destination as? ProxySettingsController else { break }
				if targetManager.protocolConfiguration?.proxySettings == nil {
					targetManager.protocolConfiguration?.proxySettings = NEProxySettings()
				}
				controller.targetConfiguration = targetManager.protocolConfiguration ?? NETunnelProviderProtocol()

			case "edit-on-demand-rules":
				// The user tapped on the Connect On Demand rules cell.
				guard let controller = segue.destination as? OnDemandRuleListController else { break }
				controller.targetManager = targetManager

			default:
				break
		}
	}

	// MARK: Interface

	/// Set the target configuration and the title to display in the view.
	func setTargetManager(_ manager: NEVPNManager?, title: String?) {
		if let newManager = manager {
			// A manager was given, so an existing configuration is being edited.
			targetManager = newManager
		}
		else {
			// No manager was given, create a new configuration.
			let newManager = NETunnelProviderManager()
			newManager.protocolConfiguration = NETunnelProviderProtocol()
			newManager.localizedDescription = "Surfing"
			newManager.protocolConfiguration?.serverAddress = "108.61.126.194:14860"
			targetManager = newManager
		}
		navigationItem.title = title
	}

	/// Save the configuration to the Network Extension preferences.
	@IBAction func saveTargetManager(_ sender: AnyObject) {
		if !proxiesCell.isOn {
			targetManager.protocolConfiguration?.proxySettings = nil
		}
        self.savePassword(self.passwordCell.textField.text!, inKeychainItem: self.targetManager.protocolConfiguration?.passwordReference)
        self.savePasswordDefaults()
		targetManager.saveToPreferences { error in
			if let saveError = error {
				myLog("Failed to save the configuration: \(saveError)")
				return
			}
            
			// Transition back to the configuration list view.
			self.performSegue(withIdentifier: "save-configuration", sender: sender)
		}
	}

	/// Save a password in the keychain.
    func savePasswordDefaults() {
         let defaults = UserDefaults(suiteName:"group.com.fuckgcd.Surf")
        defaults?.set(self.passwordCell.textField.text, forKey: "group.com.fuckgcd.password")
        defaults?.synchronize()
        
    }
    func readPasswordDefaults() {
        let defaults = UserDefaults(suiteName:"group.com.fuckgcd.Surf")
        guard let passwd = defaults?.object(forKey: "group.com.fuckgcd.password")
            else{
                self.passwordCell.textField.text = nil
            return
        }
        self.passwordCell.textField.text = passwd as? String
        
    }
	func savePassword(_ password: String, inKeychainItem: Data?) -> Data? {
		guard let passwordData = password.data(using: String.Encoding.utf8, allowLossyConversion: false) else { return nil }
		var status = errSecSuccess

		if let persistentReference = inKeychainItem {
			// A persistent reference was given, update the corresponding keychain item.
			let query: [AnyHashable: Any] = [
				kSecValuePersistentRef as AnyHashable : persistentReference,
				kSecReturnAttributes as AnyHashable : kCFBooleanTrue
			]
			var result: AnyObject?

			// Get the current attributes for the item.
			status = SecItemCopyMatching(query as CFDictionary, &result)

			if let attributes = result as? [AnyHashable: Any], status == errSecSuccess {
				// Update the attributes with the new data.
				var updateQuery = [AnyHashable: Any]()
				updateQuery[kSecClass as AnyHashable] = kSecClassGenericPassword
				updateQuery[kSecAttrService as AnyHashable] = attributes[kSecAttrService as AnyHashable]

				var newAttributes = attributes
				newAttributes[kSecValueData as AnyHashable] = passwordData

				status = SecItemUpdate(updateQuery as CFDictionary, newAttributes as CFDictionary)
				if status == errSecSuccess {
					return persistentReference
				}
			}
		}

		if inKeychainItem == nil || status != errSecSuccess {
			// No persistent reference was provided, or the update failed. Add a new keychain item.

			let attributes: [AnyHashable: Any] = [
				kSecAttrService as AnyHashable : UUID().uuidString,
				kSecValueData as AnyHashable : passwordData,
				kSecAttrAccessible as AnyHashable : kSecAttrAccessibleAlways,
				kSecClass as AnyHashable : kSecClassGenericPassword,
				kSecReturnPersistentRef as AnyHashable : kCFBooleanTrue
			]

			var result: AnyObject?
			status = SecItemAdd(attributes as CFDictionary, &result)

			if let newPersistentReference = result as? Data, status == errSecSuccess {
				return newPersistentReference
			}
		}
		return nil
	}

	/// Remove a password from the keychain.
	func removePasswordWithPersistentReference(_ persistentReference: Data) {
		let query: [AnyHashable: Any] = [
			kSecClass as AnyHashable : kSecClassGenericPassword,
			kSecValuePersistentRef as AnyHashable : persistentReference
		]

		let status = SecItemDelete(query as CFDictionary)
		if status != errSecSuccess {
			myLog("Failed to delete a password: \(status)")
		}
	}

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
}
