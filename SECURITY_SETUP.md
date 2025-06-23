# Secure API Key Management

This project implements enterprise-grade security for API key management using encrypted binary assets, ensuring sensitive credentials are never exposed in plain text anywhere in the codebase or version control system.

## Architecture Overview

### Components

1. **CryptoManager.swift** - Handles encryption/decryption using AES-GCM
2. **SecureKeyManager.swift** - Manages secure access to API keys
3. **Configuration Files** - .xcconfig files for build settings (no sensitive data)
4. **Encrypted Binary Asset** - `encrypted_api_key.dat` containing encrypted API key

### Security Features

- **AES-GCM Encryption**: Industry-standard encryption with authenticated encryption
- **Key Derivation**: Uses app bundle identifier and version for key derivation
- **Runtime Decryption**: Keys are only decrypted in memory at runtime
- **No Plain Text Storage**: API keys are never stored in plain text in the codebase

## Setup Process

### Initial Setup (Already Done)

1. The API key was encrypted using `encrypt_api_key.swift`
2. Encrypted binary saved to `GoldenAge/encrypted_api_key.dat`
3. Original plain text key removed from Xcode scheme
4. Configuration files created for build management

### Key Management

```swift
// Usage in code:
let apiKey = SecureKeyManager.shared.getOpenAIKey()
```

### Security Benefits

- ✅ API keys are encrypted at rest
- ✅ No plain text keys in source code or configuration
- ✅ Keys are derived from app-specific data
- ✅ Memory-only decryption
- ✅ Safe for version control

## Configuration Files

### Debug.xcconfig
- Development-specific build settings
- References encrypted key approach
- No sensitive data stored

### Release.xcconfig  
- Production-specific build settings
- Optimized for distribution
- No sensitive data stored

## Important Notes

1. **The encrypted binary asset (`encrypted_api_key.dat`) should be included in version control** - it's encrypted and safe to commit
2. **Never commit the `encrypt_api_key.swift` script** - it contains the plain text key
3. **The encryption key is derived from app metadata** - uses "DigitalDen.GoldenAge" bundle ID and version "1.0"
4. **For new API keys**: Run the encryption script and replace the .dat file

## Regenerating Keys

If you need to update the API key:

1. Replace `YOUR_API_KEY_HERE` with your actual API key in `encrypt_api_key.swift`
2. Run: `swift encrypt_api_key.swift`
3. The new encrypted binary will overwrite the existing one
4. **Important**: Replace the real API key with `YOUR_API_KEY_HERE` before committing

The encryption script includes safety checks to prevent accidental commits with real API keys.

## Security Implementation Details

### Encryption Methodology

**AES-GCM with App-Specific Key Derivation:**
```swift
// Key derivation uses app-specific metadata
let bundleId = "DigitalDen.Verbalist"
let appVersion = "1.0"
let keyString = "\(bundleId)_\(appVersion)_secure_key_derivation"
let derivedKey = SymmetricKey(data: SHA256.hash(data: Data(keyString.utf8)))
```

**Security Layers:**
1. **Bundle ID Binding**: Keys are tied to specific app bundle identifier
2. **Version Binding**: Encryption tied to app version preventing cross-version attacks
3. **Authenticated Encryption**: AES-GCM provides both confidentiality and integrity
4. **Runtime-Only Decryption**: Keys never exist in plain text in memory longer than necessary

### Production Security Benefits

- **Zero Plain Text Exposure**: No API keys in source code, configs, or version control
- **Cross-App Protection**: Bundle-specific derivation prevents key reuse across applications
- **Git History Safety**: Encrypted assets safe to commit; no credential leakage possible
- **Development Security**: Safety mechanisms prevent accidental real key commits
- **Runtime Security**: Memory-only decryption with immediate cleanup

## Troubleshooting

- If key decryption fails, check that bundle ID and app version match the values used during encryption
- In Debug mode, a fallback key "sk-xxxx" is used if decryption fails
- In Release mode, empty string is returned if decryption fails
- For "authenticationFailure" errors, verify the correct bundle identifier is being used
- Ensure the encrypted binary file is included in the app bundle during build
