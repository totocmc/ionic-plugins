//
//  NFCTAGDelegate.swift
//  NFC
//
//  Created by toto on 27/10/2019.
//

import Foundation
import CoreNFC

class NFCTAGDelegate: NSObject, NFCTagReaderSessionDelegate {
    
    var session: NFCTagReaderSession?
    var completed: ([AnyHashable : Any]?, Error?) -> ()
    
    init(completed: @escaping ([AnyHashable: Any]?, Error?) -> (), message: String?) {
        self.completed = completed
        super.init()
        self.session = NFCTagReaderSession.init(pollingOption: [.iso15693], delegate: self, queue: nil)
        if (self.session == nil) {
            self.completed(nil, "NFC is not available" as? Error);
            return
        }
        self.session!.alertMessage = message ?? ""
        self.session!.begin()
    }
    
    func invalidateSession( message :String) {
        session?.alertMessage = message
        session?.invalidate()
    }
    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
       // If necessary, you may perform additional operations on session start.
       // At this point RF polling is enabled.
       print( "tagReaderSessionDidBecomeActive" )
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error){
      completed(nil, "NFCNDEFReaderSession error" as? Error)
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print( "tagReaderSession:didDectectTag" )
        guard let session = self.session else {
           return;
        }
        if tags.count > 1 {
           // Restart polling in 500 milliseconds.
           let retryInterval = DispatchTimeInterval.milliseconds(500)
           session.alertMessage = "More than 1 Tap is detected. Please remove all tags and try again."
           DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
               session.restartPolling()
           })
           return
        }
        
        var tag: NFCTag? = nil
        
        for nfcTag in tags {
            if case .iso15693(_) = nfcTag {
                tag = nfcTag
                break
            }
            else
            {
                tag = nil
            }
        }
        
        if tag == nil {
            session.invalidate(errorMessage: "No valid tag found.")
            return
        }
        
        
        // Connect to tag
        session.connect(to: tag!) { [weak self] (error: Error?) in

            if error != nil {
                let error = NFCReaderError(NFCReaderError.readerTransceiveErrorTagNotConnected)
                self!.invalidateSession( message: error.localizedDescription  )
                self!.completed(nil, "tagReaderSession:connect to tag" as? Error)
                return
            }
            print( "connected to tag" )
            self!.fireTagEvent(tag: tag!)

        }
    }
    
    func fireTagEvent(tag: NFCTag) {
        let returnedJSON = NSMutableDictionary()
        
        if case let .iso15693(iso15Tag) = tag {
            let dict = NSMutableDictionary()
            dict.setObject([iso15Tag.identifier], forKey: "id" as NSString)
            
            returnedJSON.setValue("tag", forKey: "type")
            returnedJSON.setObject(dict, forKey: "tag" as NSString)
        }
        print(returnedJSON)
        
        let response = returnedJSON as! [AnyHashable : Any]
        completed(response, nil)
    }
}
