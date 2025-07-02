//
//  VerbalistApp.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import SwiftUI
import CloudKit

@main
struct VerbalistApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Check for environment variables
        let hasGroqKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"] != nil
        
        
        // Request CloudKit permissions
        let container = CKContainer.default()
        container.accountStatus { (accountStatus, error) in
            // CloudKit status check completed
        }
        
        return true
    }
}
