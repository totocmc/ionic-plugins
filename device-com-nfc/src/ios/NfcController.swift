//
//  IOS15Reader.swift
//  NFC
//
//  Created by dev@iotize.com on 23/07/2019.
//  Copyright © 2019 dev@iotize.com. All rights reserved.
//

import UIKit
import CoreNFC
import SwiftUI
import Combine

public extension String {
    
     func dataFromHexString() -> Data {
        var bytes = [UInt8]()
        for i in 0..<(count/2) {
            let range = index(self.startIndex, offsetBy: 2*i)..<index(self.startIndex, offsetBy: 2*i+2)
            let stringBytes = self[range]
            let byte = strtol((stringBytes as NSString).utf8String, nil, 16)
            bytes.append(UInt8(byte))
        }
        return Data(bytes: UnsafePointer<UInt8>(bytes), count:bytes.count)
    }
    
}

extension Data {
    
    func hexEncodedString() -> String {
        let format = "%02hhX"
        return map { String(format: format, $0) }.joined()
    }
}

// MARK: - NFCController

@available(iOS 13.0, *)
final class NFCController: NSObject {
    
    // MARK: - Properties
    var readerSession: NFCControllerReader?
    var writerSession: NFCControllerWriter?
    
    func initReaderSession(completed: @escaping ([AnyHashable: Any]?, Error?) -> ()) {
        if self.readerSession == nil {
                self.readerSession = NFCControllerReader(completed: completed)
            }
    }

    func initWriterSession(completed: @escaping ([AnyHashable: Any]?, Error?) -> (), request: NFCNDEFMessage) {
        if self.writerSession == nil {
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { (timer) in
                print("1 \(DispatchTime.now()) try writing")
                
                self.writerSession = NFCControllerWriter(completed: {
                (response: [AnyHashable: Any]?, error: Error?) -> Void in
                    if(error != nil)
                    {
                        if let readerError = error as? NFCReaderError
                        {
                            if (readerError.code == .readerSessionInvalidationErrorSystemIsBusy)
                            {
                                print("system busy")
                            }
                            else
                            {
                                print(error)
                                timer.invalidate()
                                completed(nil, error)
                            }
                        }
                    }
                    else
                    {
                        timer.invalidate()
                        completed(response, nil)
                    }
                }, request: request)
            }
        }
    }
}
// MARK: - NFCController Reader

@available(iOS 13.0, *)
final class NFCControllerReader: UITableViewController, NFCNDEFReaderSessionDelegate {
    
    // MARK: - Properties
    var readerSession: NFCNDEFReaderSession?
    var detectedMessages = [NFCNDEFMessage]()
    var completed: ([AnyHashable : Any]?, Error?) -> ()
    
    init(completed: @escaping ([AnyHashable: Any]?, Error?) -> ()) {
        self.completed = completed
        super.init(nibName: nil, bundle: nil)
        
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "Scanning Not Supported",
                message: "This device doesn't support tag scanning.",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }

        readerSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        readerSession?.alertMessage = "Hold your iPhone near the item to learn more about it."
        readerSession?.begin()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            // Restart polling in 500ms
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "More than 1 tag is detected, please remove all tags and try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }
        
        // Connect to the found tag and perform NDEF message reading
        let tag = tags.first!
        print(tag)
        if tag.conforms(to: NFCISO15693Tag.self)
        {
            //let tg: NFCISO15693Tag = NFCISO15693Tag(coder: tag)
        }
        session.connect(to: tag, completionHandler: { (error: Error?) in
            if nil != error {
                session.alertMessage = "Unable to connect to tag."
                session.invalidate()
                self.completed(nil, error)
                return
            }
            
            tag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                if .notSupported == ndefStatus {
                    session.alertMessage = "Tag is not NDEF compliant"
                    session.invalidate()
                    return
                } else if nil != error {
                    session.alertMessage = "Unable to query NDEF status of tag"
                    session.invalidate()
                    return
                }
                
                tag.readNDEF(completionHandler: { (message: NFCNDEFMessage?, error: Error?) in
                    var statusMessage: String
                    if nil != error || nil == message {
                        statusMessage = "Fail to read NDEF from tag"
                        session.alertMessage = statusMessage
                        session.invalidate()
                        self.completed(nil, error)
                    } else {
                        statusMessage = "Found 1 NDEF message"
                        session.alertMessage = statusMessage
                        session.invalidate()
                        self.fireNdefEvent(message: message!)
                    }
                })
            })
        })
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // To read new tags, a new session instance is required.
        session.invalidate()
        self.completed(nil, error)
    }
    
    func fireNdefEvent(message: NFCNDEFMessage) {
        let response = message.ndefMessageToJSON()
        completed(response, nil)
    }

}

// MARK: - NFCController Writer

@available(iOS 13.0, *)
final class NFCControllerWriter: UITableViewController, UINavigationControllerDelegate, NFCNDEFReaderSessionDelegate {
    
    // MARK: - Properties
    var writerSession: NFCNDEFReaderSession?
    var ndefMessage: NFCNDEFMessage?
    var request: NFCNDEFMessage?
    var completed: ([AnyHashable : Any]?, Error?) -> ()
    
    init(completed: @escaping ([AnyHashable: Any]?, Error?) -> (), request: NFCNDEFMessage) {
        self.completed = completed
        super.init(nibName: nil, bundle: nil)
        
        self.request = request
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "Scanning Not Supported",
                message: "This device doesn't support tag scanning.",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }
        
        writerSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        writerSession?.alertMessage = "Hold your iPhone near a writable NFC tag to update."
        writerSession?.begin()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            // Restart polling in 500 milliseconds.
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "More than 1 tag is detected. Please remove all tags and try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }
        
        // Connect to the found tag and write an NDEF message to it.
        let tag = tags.first!
        session.connect(to: tag, completionHandler: { (error: Error?) in
            if nil != error {
                session.alertMessage = "Unable to connect to tag."
                session.invalidate()
                return
            }
            
            tag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                guard error == nil else {
                    session.alertMessage = "Unable to query the NDEF status of tag."
                    session.invalidate()
                    self.completed(nil, error)
                    return
                }

                switch ndefStatus {
                case .notSupported:
                    session.alertMessage = "Tag is not NDEF compliant."
                    session.invalidate()
                case .readOnly:
                    session.alertMessage = "Tag is read only."
                    session.invalidate()
                case .readWrite:
                    tag.writeNDEF(self.request!, completionHandler: { (error: Error?) in
                        if nil != error {
                            session.alertMessage = "Write NDEF message fail: \(error!)"
                            session.invalidate()
                            self.completed(nil, error)
                        } else {
                            session.alertMessage = "Write NDEF message successful."
                            session.invalidate()
                            let response = self.request!.ndefMessageToJSON()
                            self.completed(response, nil)
                        }
                    })
                @unknown default:
                    session.alertMessage = "Unknown NDEF tag status."
                    session.invalidate()
                    self.completed(nil, error)
                }
            })
        })
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // To read new tags, a new session instance is required.
        session.invalidate()
        self.completed(nil, error)
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        //
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        //
    }
}
