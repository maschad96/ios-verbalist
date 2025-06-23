//
//  KeyEncryptor.swift
//  Verbalist
//
//  Created by Matt Schad on 6/19/25.
//

import Foundation
import CryptoKit

// Copy of the CryptoManager logic for encryption
class KeyEncryptor {
    private var derivedKey: SymmetricKey {
        let bundleId = "DigitalDen.Verbalist"
        let appVersion = "1.0"
        let keyString = "\(bundleId)_\(appVersion)_secure_key_derivation"
        
        let keyData = Data(keyString.utf8)
        return SymmetricKey(data: SHA256.hash(data: keyData))
    }
    
    func encrypt(_ plaintext: String) throws -> Data {
        let data = Data(plaintext.utf8)
        let sealedBox = try AES.GCM.seal(data, using: derivedKey)
        return sealedBox.combined!
    }
}

// IMPORTANT: Never commit this file with a real API key!
let apiKey = "YOUR_API_KEY_HERE"

// Validate that placeholder hasn't been left
guard apiKey != "YOUR_API_KEY_HERE" else {
    print("❌ Error: Please replace YOUR_API_KEY_HERE with your actual API key")
    print("⚠️  Remember to never commit this file with a real API key!")
    exit(1)
}

do {
    let encryptor = KeyEncryptor()
    let encryptedData = try encryptor.encrypt(apiKey)
    
    // Save to a binary file in the app bundle
    let outputPath = "Verbalist/encrypted_api_key.dat"
    try encryptedData.write(to: URL(fileURLWithPath: outputPath))
    
    print("✅ API key encrypted and saved to \(outputPath)")
    print("📊 Encrypted data size: \(encryptedData.count) bytes")
    print("🔒 Key successfully encrypted with AES-GCM")
    print("")
    print("⚠️  SECURITY REMINDER:")
    print("   - Replace the API key in this script with YOUR_API_KEY_HERE before committing")
    print("   - This script is already in .gitignore for safety")
    
} catch {
    print("❌ Error encrypting API key: \(error)")
    exit(1)
}
