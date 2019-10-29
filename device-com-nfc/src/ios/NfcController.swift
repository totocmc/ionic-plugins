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
    
    func initReaderSession() {
        if self.readerSession == nil {
                self.readerSession = NFCControllerReader()
            }
        self.readerSession?.initSession()
    }

    func initWriterSession(request: NFCNDEFMessage) {
        if self.writerSession == nil {
                self.writerSession = NFCControllerWriter()
            }
        self.writerSession?.initSession(request: request)
    }
    
    func invalidateSession( message :String) {
        self.readerSession?.invalidateSession(message: message)
    }
}

// MARK: - NFCController Reader

@available(iOS 13.0, *)
final class NFCControllerReader: UITableViewController, UINavigationControllerDelegate, NFCNDEFReaderSessionDelegate {
    
    // MARK: - Properties
    var readerSession: NFCNDEFReaderSession?
    var ndefMessage: NFCNDEFMessage?

    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func initSession() {
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
        
        readerSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        readerSession?.alertMessage = "Hold your iPhone near a writable NFC tag to update."
        readerSession?.begin()
    }

    func invalidateSession( message :String) {
        readerSession?.alertMessage = message
        readerSession?.invalidate()
    }
    
    func tagRemovalDetect(_ tag: NFCNDEFTag) {
        // In the tag removal procedure, you connect to the tag and query for
        // its availability. You restart RF polling when the tag becomes
        // unavailable; otherwise, wait for certain period of time and repeat
        // availability checking.
        readerSession?.connect(to: tag) { (error: Error?) in
            if error != nil || !tag.isAvailable {
                
                print("Restart polling")
                
                self.readerSession?.restartPolling()
                return
            }
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .milliseconds(500), execute: {
                self.tagRemovalDetect(tag)
            })
        }
    }
    
    func updateWithNDEFMessage(_ message: NFCNDEFMessage) -> Bool {
        // UI elements are updated based on the received NDEF message.
        let urls: [URLComponents] = message.records.compactMap { (payload: NFCNDEFPayload) -> URLComponents? in
            // Search for URL record with matching domain host and scheme.
            if let url = payload.wellKnownTypeURIPayload() {
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                if components?.host == "fishtagcreator.example.com" && components?.scheme == "https" {
                    return components
                }
            }
            return nil
        }
        
        // Valid tag should only contain 1 URL and contain multiple query items.
        guard urls.count == 1,
            let items = urls.first?.queryItems else {
            return false
        }
        
        // Get the optional info text from the text payload.
        var additionInfo: String? = nil

        for payload in message.records {
            (additionInfo, _) = payload.wellKnownTypeTextPayload()
            
            if additionInfo != nil {
                break
            }
        }
        
        
        
        return true
    }
    
    // 2.
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            session.alertMessage = "More than 1 tags was found. Please present only 1 tag."
            self.tagRemovalDetect(tags.first!)
            return
        }
        
        let ndefTag = tags.first!
        
        session.connect(to: tags.first!) { (error: Error?) in
            if error != nil {
                session.invalidate(errorMessage: "Connection error. Please try again.")
                return
            }
            
            ndefTag.queryNDEFStatus() { (status: NFCNDEFStatus, _, error: Error?) in
                if status == .notSupported {
                    session.invalidate(errorMessage: "Tag not valid.")
                    return
                }
                ndefTag.readNDEF() { (message: NFCNDEFMessage?, error: Error?) in
                    if error != nil || message == nil {
                        session.invalidate(errorMessage: "Read error. Please try again.")
                        return
                    }
                    
                    if self.updateWithNDEFMessage(message!) {
                        session.alertMessage = "Tag read success."
                        session.invalidate()
                        return
                    }
                    
                    session.invalidate(errorMessage: "Tag not valid.")
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        //
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        //
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        //
    }
}

// MARK: - NFCController Writer

@available(iOS 13.0, *)
final class NFCControllerWriter: UITableViewController, UINavigationControllerDelegate, NFCNDEFReaderSessionDelegate {
    
    // MARK: - Properties
    var writerSession: NFCNDEFReaderSession?
    var ndefMessage: NFCNDEFMessage?
    var request: NFCNDEFMessage?
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func initSession(request: NFCNDEFMessage) {
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

    func invalidateSession( message :String) {
        writerSession?.alertMessage = message
        writerSession?.invalidate()
    }
    
    func tagRemovalDetect(_ tag: NFCNDEFTag) {
        // In the tag removal procedure, you connect to the tag and query for
        // its availability. You restart RF polling when the tag becomes
        // unavailable; otherwise, wait for certain period of time and repeat
        // availability checking.
        writerSession?.connect(to: tag) { (error: Error?) in
            if error != nil || !tag.isAvailable {
                
                print("Restart polling")
                
                self.writerSession?.restartPolling()
                return
            }
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .milliseconds(500), execute: {
                self.tagRemovalDetect(tag)
            })
        }
    }
    
    // 2.
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        
        let tag = tags.first!
        // 3
        session.connect(to: tag) { (error: Error?) in
            if error != nil {
                session.restartPolling()
            }
        }

        // 4
        tag.queryNDEFStatus() { (status: NFCNDEFStatus, capacity: Int, error: Error?) in
            
            if error != nil {
                session.invalidate(errorMessage: "Fail to determine NDEF status.  Please try again.")
                return
            }
        
            if status == .readOnly {
                session.invalidate(errorMessage: "Tag is not writable.")
            } else if status == .readWrite {
                // 5
                tag.writeNDEF(self.request!) { (error: Error?) in
                    if error != nil {
                        session.invalidate(errorMessage: "Update tag failed. Please try again.")
                    } else {
                        session.alertMessage = "Update success!"
                        // 6
                        session.invalidate()
                    }
                }
            } else {
                session.invalidate(errorMessage: "Tag is not NDEF formatted.")
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        //
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        //
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        //
    }
}
