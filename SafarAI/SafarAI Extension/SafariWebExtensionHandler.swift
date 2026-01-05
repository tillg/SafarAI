//
//  SafariWebExtensionHandler.swift
//  SafarAI Extension
//
//  Created by Till Gartner on 04.01.26.
//

import SafariServices
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem

        let message: Any?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = request?.userInfo?[SFExtensionMessageKey]
        } else {
            message = request?.userInfo?["message"]
        }

        // Forward message to native app via App Groups
        if let messageDict = message as? [String: Any],
           let shared = UserDefaults(suiteName: "group.com.grtnr.SafarAI"),
           let messageData = try? JSONSerialization.data(withJSONObject: messageDict) {

            shared.set(messageData, forKey: "lastMessage")
            shared.set(Date().timeIntervalSince1970, forKey: "lastMessageTimestamp")
        }

        // Send acknowledgment
        let response = NSExtensionItem()
        if #available(iOS 15.0, macOS 11.0, *) {
            response.userInfo = [SFExtensionMessageKey: ["status": "received"]]
        } else {
            response.userInfo = ["message": ["status": "received"]]
        }

        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

}
