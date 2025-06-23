//
//  CryptoManager.swift
//  Verbalist
//
//  Created by Matt Schad on 6/19/25.
//


import Foundation
import CryptoKit
import CommonCrypto

/// Handles encryption and decryption of sensitive data
class CryptoManager {
    static let shared = CryptoManager()
    
    private init() {}
    
    /// Derives a symmetric key from app-specific data
    private var derivedKey: SymmetricKey {
        // Use app bundle identifier and other app-specific data to derive key
        let bundleId = Bundle.main.bundleIdentifier ?? "DigitalDen.Verbalist"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let keyString = "\(bundleId)_\(appVersion)_secure_key_derivation"
        
        let keyData = Data(keyString.utf8)
        return SymmetricKey(data: SHA256.hash(data: keyData))
    }
    
    /// Encrypts a string and returns the encrypted data
    func encrypt(_ plaintext: String) throws -> Data {
        let data = Data(plaintext.utf8)
        let sealedBox = try AES.GCM.seal(data, using: derivedKey)
        return sealedBox.combined!
    }
    
    /// Decrypts data and returns the original string
    func decrypt(_ encryptedData: Data) throws -> String {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: derivedKey)
        
        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            throw CryptoError.invalidDecryptedData
        }
        
        return decryptedString
    }
}

enum CryptoError: Error {
    case encryptionFailed
    case decryptionFailed
    case invalidDecryptedData
    
    var localizedDescription: String {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidDecryptedData:
            return "Decrypted data is not valid UTF-8"
        }
    }
}
