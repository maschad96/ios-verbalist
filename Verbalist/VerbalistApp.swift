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
        
        if !hasGroqKey {
            print("⚠️ Warning: GROQ_API_KEY environment variable not set - app will not function correctly")
        }
        
        // Request CloudKit permissions
        let container = CKContainer.default()
        container.accountStatus { (accountStatus, error) in
            if accountStatus == .available {
                print("CloudKit available")
            } else if let error = error {
                print("CloudKit error: \(error.localizedDescription)")
            }
        }
        
        return true
    }
}
