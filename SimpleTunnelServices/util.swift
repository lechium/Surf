/*
	Copyright (C) 2015 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	This file contains some utility classes and functions used by various parts of the SimpleTunnel project.
*/

import Foundation
import Darwin

/// SimpleTunnel errors
public enum SimpleTunnelError: Error {
    case BadConfiguration
    case BadConnection
	case InternalError
}

/// A queue of blobs of data
class SavedData {

	// MARK: Properties

	/// Each item in the list contains a data blob and an offset (in bytes) within the data blob of the data that is yet to be written.
	var chain = [(data: NSData, offset: Int)]()

	/// A convenience property to determine if the list is empty.
	var isEmpty: Bool {
		return chain.isEmpty
	}

	// MARK: Interface

	/// Add a data blob and offset to the end of the list.
	func append(data: NSData, offset: Int) {
		chain.append(data: data, offset: offset)
	}

	/// Write as much of the data in the list as possible to a stream
	func writeToStream(stream: OutputStream) -> Bool {
		var result = true
		var stopIndex: Int?

		for (chainIndex, record) in chain.enumerated() {
			let written = writeData(data: record.data, toStream: stream, startingAtOffset:record.offset)
			if written < 0 {
				result = false
				break
			}
			if written < (record.data.length - record.offset) {
				// Failed to write all of the remaining data in this blob, update the offset.
				chain[chainIndex] = (record.data, record.offset + written)
				stopIndex = chainIndex
				break
			}
		}

		if let removeEnd = stopIndex {
			// We did not write all of the data, remove what was written.
			if removeEnd > 0 {
				//chain.removeRange(Range(start: 0, end: removeEnd))
			}
		} else {
			// All of the data was written.
			chain.removeAll(keepingCapacity: false)
		}

		return result
	}

	/// Remove all data from the list.
	func clear() {
		chain.removeAll(keepingCapacity: false)
	}
}

/// A object containing a sockaddr_in6 structure.
class SocketAddress6 {

	// MARK: Properties

	/// The sockaddr_in6 structure.
	var sin6: sockaddr_in6

	/// The IPv6 address as a string.
	var stringValue: String? {
		//return withUnsafePointer(to: &sin6) { saToString(sa: UnsafePointer<sockaddr>($0)) }
        return nil //FIXME
    }

	// MARK: Initializers

	init() {
		sin6 = sockaddr_in6()
		sin6.sin6_len = __uint8_t(MemoryLayout<sockaddr_in6>.size)
		sin6.sin6_family = sa_family_t(AF_INET6)
		sin6.sin6_port = in_port_t(0)
		sin6.sin6_addr = in6addr_any
		sin6.sin6_scope_id = __uint32_t(0)
		sin6.sin6_flowinfo = __uint32_t(0)
	}

	convenience init(otherAddress: SocketAddress6) {
		self.init()
		sin6 = otherAddress.sin6
	}

	/// Set the IPv6 address from a string.
	func setFromString(str: String) -> Bool {
		return str.withCString({ cs in inet_pton(AF_INET6, cs, &sin6.sin6_addr) }) == 1
	}

	/// Set the port.
	func setPort(port: Int) {
		sin6.sin6_port = in_port_t(UInt16(port).bigEndian)
	}
}

/// An object containing a sockaddr_in structure.
class SocketAddress {

	// MARK: Properties

	/// The sockaddr_in structure.
	var sin: sockaddr_in

	/// The IPv4 address in string form.
	var stringValue: String? {
		//return withUnsafePointer(to: &sin) { saToString(sa: UnsafePointer<sockaddr>($0)) }
        return nil //FIXME
    }

	// MARK: Initializers

	init() {
		sin = sockaddr_in(sin_len:__uint8_t(MemoryLayout<sockaddr_in>.size), sin_family:sa_family_t(AF_INET), sin_port:in_port_t(0), sin_addr:in_addr(s_addr: 0), sin_zero:(Int8(0), Int8(0), Int8(0), Int8(0), Int8(0), Int8(0), Int8(0), Int8(0)))
	}

	convenience init(otherAddress: SocketAddress) {
		self.init()
		sin = otherAddress.sin
	}

	/// Set the IPv4 address from a string.
	func setFromString(str: String) -> Bool {
		return str.withCString({ cs in inet_pton(AF_INET, cs, &sin.sin_addr) }) == 1
	}

	/// Set the port.
	func setPort(port: Int) {
		sin.sin_port = in_port_t(UInt16(port).bigEndian)
	}

	/// Increment the address by a given amount.
	func increment(amount: UInt32) {
		let networkAddress = sin.sin_addr.s_addr.byteSwapped + amount
		sin.sin_addr.s_addr = networkAddress.byteSwapped
	}

	/// Get the difference between this address and another address.
	func difference(otherAddress: SocketAddress) -> Int64 {
		return Int64(sin.sin_addr.s_addr.byteSwapped - otherAddress.sin.sin_addr.s_addr.byteSwapped)
	}
}

// MARK: Utility Functions

/// Convert a sockaddr structure to a string.
func saToString(sa: UnsafePointer<sockaddr>) -> String? {
	var hostBuffer = [CChar](repeating:0, count: Int(NI_MAXHOST))
	var portBuffer = [CChar](repeating:0, count: Int(NI_MAXSERV))

	guard getnameinfo(sa, socklen_t(sa.pointee.sa_len), &hostBuffer, socklen_t(hostBuffer.count), &portBuffer, socklen_t(portBuffer.count), NI_NUMERICHOST | NI_NUMERICSERV) == 0
		else { return nil }

	//return String.fromCString(hostBuffer)
    return String.init(validatingUTF8: hostBuffer)
}

/// Write a blob of data to a stream starting from a particular offset.
func writeData(data: NSData, toStream stream: OutputStream, startingAtOffset offset: Int) -> Int {
	var written = 0
	var currentOffset = offset
	while stream.hasSpaceAvailable && currentOffset < data.length {
        
        let writeResult = 0 //FIXME
		//let writeResult = stream.write(UnsafePointer<UInt8>(data.bytes) + currentOffset, maxLength: data.length - currentOffset)
		guard writeResult >= 0 else { return writeResult }

		written += writeResult
		currentOffset += writeResult
	}
	
	return written
}

/// Create a SimpleTunnel protocol message dictionary.
public func createMessagePropertiesForConnection(connectionIdentifier: Int, commandType: TunnelCommand, extraProperties: [String: AnyObject] = [:]) -> [String: AnyObject] {
	// Start out with the "extra properties" that the caller specified.
	var properties = extraProperties

	// Add in the standard properties common to all messages.
	properties[TunnelMessageKey.Identifier.rawValue] = connectionIdentifier as AnyObject?
	properties[TunnelMessageKey.Command.rawValue] = commandType.rawValue as AnyObject?
	
	return properties
}

/// Keys in the tunnel server configuration plist.
public enum SettingsKey: String {
	case IPv4 = "IPv4"
	case DNS = "DNS"
	case Proxies = "Proxies"
	case Pool = "Pool"
	case StartAddress = "StartAddress"
	case EndAddress = "EndAddress"
	case Servers = "Servers"
	case SearchDomains = "SearchDomains"
	case Address = "Address"
	case Netmask = "Netmask"
	case Routes = "Routes"
}

/// Get a value from a plist given a list of keys.
public func getValueFromPlist(plist: [NSObject: AnyObject], keyArray: [SettingsKey]) -> AnyObject? {
	var subPlist = plist
	for (index, key) in keyArray.enumerated() {
		if index == keyArray.count - 1 {
			//return subPlist[key.rawValue]
            return nil //FIXME
        }
		//else if let subSubPlist = subPlist[key.rawValue] as? [NSObject: AnyObject] {
		//	subPlist = subSubPlist
		//}
		else {
			break
		}
	}

	return nil
}

/// Create a new range by incrementing the start of the given range by a given ammount.
func rangeByMovingStartOfRange(range: Range<Int>, byCount: Int) -> Range<Int> {
    
	//return Range(start: range.lowerBound + byCount, end: range.upperBound)
    return Range(uncheckedBounds: (range.lowerBound, range.upperBound)) //FIXME
    //return Range(uncheckedBounds: Bound(range.lowerBound)..<Bound(range.upperBound))
    //0.0..<5.0
}

public func myLog(message: String) {
	NSLog(message)
}
//extension String : CollectionType {}
public func myLog<T>(object: T, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
    //let fn = file.split { $0 == "/" }.last
    let fn = file.characters.split { $0 == "/" }.map(String.init).last
    if let f = fn {
        let info = "\(f).\(function)[\(line)]:\(object)"
        NSLog(info)
    }
}
public func datatoIP(data: NSData) -> String {
    var ip:String = ""
    //var p = data.bytes
    
    var a:UInt8 = 0
    data.getBytes(&a, range: NSRange.init(location: 0, length: 1))
    var  b:UInt8 = 0
    data.getBytes(&b,range: NSRange.init(location: 1, length: 1))
    
    var c:UInt8 = 0
    data.getBytes(&c, range:NSRange.init(location: 2, length: 1))
    var  d:UInt8 = 0
    data.getBytes(&d, range:NSRange.init(location: 3, length: 1))
    ip = "\(a).\(b).\(c).\(d)"
    return ip
}
