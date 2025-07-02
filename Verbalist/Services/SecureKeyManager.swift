//
//  SecureKeyManager.swift
//  Verbalist
//
//  Created by Matt Schad on 6/19/25.
//


import Foundation

/// Securely manages API keys using encrypted binary assets
class SecureKeyManager {
    static let shared = SecureKeyManager()
    
    private var cachedSecrets: [String: String] = [:]
    private let cryptoManager = CryptoManager.shared
    
    private init() { }
    
    /// Get the OpenAI API key from encrypted binary asset
    /// - Returns: The API key as a string
    func getOpenAIKey() -> String {
        // Check cache first for performance
        if let cachedKey = cachedSecrets["openai"] {
            return cachedKey
        }
        
        do {
            // Load encrypted data from bundle
            guard let encryptedData = loadEncryptedAPIKey() else {
                #if DEBUG
                return "sk-xxxx" // Development fallback
                #else
                return ""
                #endif
            }
            
            // Decrypt the API key
            let decryptedKey = try cryptoManager.decrypt(encryptedData)
            
            // Cache for future use
            cachedSecrets["openai"] = decryptedKey
            return decryptedKey
            
        } catch {
            #if DEBUG
            return "sk-xxxx" // Development fallback
            #else
            return ""
            #endif
        }
    }
    
    /// Get the Groq API key from encrypted binary asset
    /// - Returns: The API key as a string
    func getGroqKey() -> String {
        // Check cache first for performance
        if let cachedKey = cachedSecrets["groq"] {
            return cachedKey
        }
        
        do {
            // Load encrypted data from bundle
            guard let encryptedData = loadEncryptedAPIKey() else {
                #if DEBUG
                return "gsk-xxxx" // Development fallback
                #else
                return ""
                #endif
            }
            
            // Decrypt the API key
            let decryptedKey = try cryptoManager.decrypt(encryptedData)
            
            // Cache for future use
            cachedSecrets["groq"] = decryptedKey
            return decryptedKey
            
        } catch {
            #if DEBUG
            return "gsk-xxxx" // Development fallback
            #else
            return ""
            #endif
        }
    }
    
    /// Load encrypted API key data from app bundle
    /// - Returns: Encrypted data or nil if not found
    private func loadEncryptedAPIKey() -> Data? {
        // Try multiple methods to locate the encrypted file
        
        // Method 1: Try as resource in main bundle
        if let path = Bundle.main.path(forResource: "encrypted_api_key", ofType: "dat"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            return data
        }
        
        // Method 2: Try direct URL from bundle
        if let url = Bundle.main.url(forResource: "encrypted_api_key", withExtension: "dat"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        
        // Method 3: Search for file in bundle
        if let bundlePath = Bundle.main.resourcePath {
            let filePath = "\(bundlePath)/encrypted_api_key.dat"
            if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
                return data
            }
        }
        
        
        return nil
    }
}
