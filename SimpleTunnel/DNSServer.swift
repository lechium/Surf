//
//  DNSServer.swift
//  SimpleTunnel
//
//  Copyright © 2015年 Apple Inc. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import SimpleTunnelServices
@objc class DNSServer:NSObject, GCDAsyncUdpSocketDelegate{
    var domains:[String] = []
    var clientAddress:Data?
    var packet:DNSPacket?
    var socket:GCDAsyncUdpSocket?
    var waittingQueriesMap:[UInt16:AnyObject] = [:]
    var queries:[DNSPacket] = []
    var queryIDCounter:UInt16 = 0
    let dispatchQueue = DispatchQueue(label: "DNSServer", attributes: []);
    override init () {
        super.init()
        socket = GCDAsyncUdpSocket.init(delegate: self, delegateQueue: dispatchQueue)
        //socket = GCDAsyncUdpSocket.init(delegate: self, delegateQueue: dispatchQueue)
    }
    func addQuery(didReceiveData data:Data!) {
        let packet:DNSPacket = DNSPacket()//= DNSPacket.init(packetData: data)
        
        queries.append(packet)
        //processQuery()
        myLog(message: "receive udp packet \(data)")
    }
   
    func processQuery() {
        let data:Data = Data()//(queries.first?.rawData)! as! NSMutableData
        queries.removeFirst()
        if (queryIDCounter == UInt16(UINT16_MAX)) {
            queryIDCounter = 0
        }
        
        let  queryID:UInt16 = queryIDCounter + queryIDCounter + 1; //FIXME used to be queryIDCounter += 1, just trying to get this piece of garbage building
        //data.replaceBytesInRange(NSMakeRange(0, 2), withBytes: queryID)
        
        //[data replaceBytesInRange:NSMakeRange(0, 2) withBytes:&queryID];
        //how to send data
        waittingQueriesMap[queryID] = data as AnyObject?
        socket?.send(data, toHost: "192.168.0.254", port: 54, withTimeout: 10, tag: 0)
    }
    func processResponse(_ datagrams:[Data]) ->Void{
        dispatchQueue.async { () -> Void in
            
            for data in datagrams{
                let queryID:UInt16 = 0 //= data.bytes
                let query = self.waittingQueriesMap[queryID] as? DNSServerQuery
                //DNSServerQuery *query = _waittingQueriesMap[@(queryID)];
                guard let _ = query else{
                    myLog(message: "Local query not found!")
                    return
                }
                //NSMutableData *mdata = [data mutableCopy];
                //u_int16_t identifier = query.packet.identifier;
                //[mdata replaceBytesInRange:NSMakeRange(0, 2) withBytes:&identifier];
                
                //[_socket sendData:mdata toAddress:query.clientAddress withTimeout:10 tag:0];
                self.socket?.send(data, toAddress: query!.address as Data!, withTimeout: 10, tag: 0)
                

                
            }
            
        }
    }
}
