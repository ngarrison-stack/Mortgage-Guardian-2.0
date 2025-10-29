import Foundation
import LocalAuthentication
import CryptoKit
import Security
import UIKit
import Network

/// Comprehensive security service for Mortgage Guardian app
/// Handles biometric authentication, data encryption, key management, and network security
@MainActor
public final class SecurityService: ObservableObject {

    // MARK: - Types

    /// Security-related errors
    public enum SecurityError: LocalizedError {
        case biometricNotAvailable
        case biometricNotEnrolled
        case biometricAuthenticationFailed(Error)
        case encryptionFailed(String)
        case decryptionFailed(String)
        case keyGenerationFailed
        case keyNotFound
        case keychainError(OSStatus)
        case networkSecurityViolation(String)
        case sessionExpired
        case invalidCertificate
        case certificatePinningFailed
        case authenticationRequired
        case deviceCompromised

        public var errorDescription: String? {
            switch self {
            case .biometricNotAvailable:
                return "Biometric authentication is not available on this device"
            case .biometricNotEnrolled:
                return "No biometric credentials are enrolled on this device"
            case .biometricAuthenticationFailed(let error):
                return "Biometric authentication failed: \(error.localizedDescription)"
            case .encryptionFailed(let reason):
                return "Encryption failed: \(reason)"
            case .decryptionFailed(let reason):
                return "Decryption failed: \(reason)"
            case .keyGenerationFailed:
                return "Failed to generate encryption key"
            case .keyNotFound:
                return "Encryption key not found"
            case .keychainError(let status):
                return "Keychain error: \(status)"
            case .networkSecurityViolation(let reason):
                return "Network security violation: \(reason)"
            case .sessionExpired:
                return "Security session has expired"
            case .invalidCertificate:
                return "Invalid server certificate"
            case .certificatePinningFailed:
                return "Certificate pinning validation failed"
            case .authenticationRequired:
                return "Authentication is required to access this feature"
            case .deviceCompromised:
                return "Device security has been compromised"
            }
        }
    }

    /// Session state for authentication
    public enum SessionState {
        case unauthenticated
        case authenticated
        case locked
        case expired
    }

    /// Audit event types for security logging
    public enum AuditEvent {
        case biometricAuthSuccess
        case biometricAuthFailure
        case sessionStarted
        case sessionExpired
        case sessionLocked
        case dataEncrypted(String)
        case dataDecrypted(String)
        case keyGenerated
        case keyRotated
        case networkSecurityViolation(String)
        case certificatePinningFailure
        case suspiciousActivity(String)
    }

    // MARK: - Properties

    public static let shared = SecurityService()

    @Published public private(set) var sessionState: SessionState = .unauthenticated
    @Published public private(set) var isDeviceSecure: Bool = false
    @Published public private(set) var lastSecurityCheck: Date?

    private let keychain = SecurityKeychain()
    private let encryptionManager = EncryptionManager()
    private let certificatePinner = CertificatePinner()
    private let auditLogger = SecurityAuditLogger()
    private let sessionManager = SessionManager()

    private var securitySettings: User.SecuritySettings?
    private var autoLockTimer: Timer?
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")

    // MARK: - Initialization

    private init() {
        setupNetworkMonitoring()
        checkDeviceSecurityStatus()
    }

    // MARK: - Configuration

    /// Configure security service with user settings
    public func configure(with settings: User.SecuritySettings) {
        self.securitySettings = settings
        setupAutoLock()
        auditLogger.log(.sessionStarted)
    }

    // MARK: - Biometric Authentication

    /// Check if biometric authentication is available and configured
    public func isBiometricAuthenticationAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?

        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Get the type of biometric authentication available
    public func getBiometricType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    /// Authenticate user using biometric authentication
    public func authenticateWithBiometrics() async throws {
        guard let settings = securitySettings, settings.biometricAuthEnabled else {
            throw SecurityError.authenticationRequired
        }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                switch error.code {
                case LAError.biometryNotAvailable.rawValue:
                    throw SecurityError.biometricNotAvailable
                case LAError.biometryNotEnrolled.rawValue:
                    throw SecurityError.biometricNotEnrolled
                default:
                    throw SecurityError.biometricAuthenticationFailed(error)
                }
            }
            throw SecurityError.biometricNotAvailable
        }

        let reason = "Authenticate to access your mortgage documents and financial information"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                await handleAuthenticationSuccess()
                auditLogger.log(.biometricAuthSuccess)
            }
        } catch {
            auditLogger.log(.biometricAuthFailure)
            throw SecurityError.biometricAuthenticationFailed(error)
        }
    }

    /// Authenticate with device passcode fallback
    public func authenticateWithPasscode() async throws {
        let context = LAContext()
        let reason = "Authenticate to access your mortgage documents and financial information"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )

            if success {
                await handleAuthenticationSuccess()
                auditLogger.log(.biometricAuthSuccess)
            }
        } catch {
            auditLogger.log(.biometricAuthFailure)
            throw SecurityError.biometricAuthenticationFailed(error)
        }
    }

    // MARK: - Data Encryption

    /// Encrypt sensitive data using AES-GCM encryption
    public func encryptData(_ data: Data, context: String = "general") async throws -> Data {
        do {
            let encryptedData = try await encryptionManager.encrypt(data, context: context)
            auditLogger.log(.dataEncrypted(context))
            return encryptedData
        } catch {
            throw SecurityError.encryptionFailed(error.localizedDescription)
        }
    }

    /// Decrypt sensitive data
    public func decryptData(_ encryptedData: Data, context: String = "general") async throws -> Data {
        guard sessionState == .authenticated else {
            throw SecurityError.authenticationRequired
        }

        do {
            let decryptedData = try await encryptionManager.decrypt(encryptedData, context: context)
            auditLogger.log(.dataDecrypted(context))
            return decryptedData
        } catch {
            throw SecurityError.decryptionFailed(error.localizedDescription)
        }
    }

    /// Encrypt mortgage document data
    public func encryptDocument(_ documentData: Data, documentId: String) async throws -> Data {
        return try await encryptData(documentData, context: "document:\(documentId)")
    }

    /// Decrypt mortgage document data
    public func decryptDocument(_ encryptedData: Data, documentId: String) async throws -> Data {
        return try await decryptData(encryptedData, context: "document:\(documentId)")
    }

    // MARK: - Key Management

    /// Generate a new encryption key for the specified context
    public func generateKey(for context: String) async throws {
        do {
            try await encryptionManager.generateKey(for: context)
            auditLogger.log(.keyGenerated)
        } catch {
            throw SecurityError.keyGenerationFailed
        }
    }

    /// Rotate encryption keys for enhanced security
    public func rotateKeys() async throws {
        try await encryptionManager.rotateAllKeys()
        auditLogger.log(.keyRotated)
    }

    /// Securely delete all encryption keys
    public func deleteAllKeys() async throws {
        try await encryptionManager.deleteAllKeys()
        try keychain.deleteAllItems()
    }

    // MARK: - Keychain Operations

    /// Store sensitive data in the keychain
    public func storeInKeychain<T: Codable>(_ item: T, key: String, requireBiometric: Bool = true) throws {
        let data = try JSONEncoder().encode(item)
        try keychain.store(data, key: key, requireBiometric: requireBiometric)
    }

    /// Retrieve sensitive data from the keychain
    public func retrieveFromKeychain<T: Codable>(_ type: T.Type, key: String) throws -> T? {
        guard let data = try keychain.retrieve(key: key) else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    /// Delete item from keychain
    public func deleteFromKeychain(key: String) throws {
        try keychain.delete(key: key)
    }

    // MARK: - Session Management

    /// Start authenticated session
    private func handleAuthenticationSuccess() async {
        sessionState = .authenticated
        sessionManager.startSession()
        setupAutoLock()
    }

    /// Lock the application
    public func lockSession() {
        sessionState = .locked
        sessionManager.lockSession()
        auditLogger.log(.sessionLocked)
        invalidateAutoLockTimer()
    }

    /// End the current session
    public func endSession() {
        sessionState = .unauthenticated
        sessionManager.endSession()
        auditLogger.log(.sessionExpired)
        invalidateAutoLockTimer()
    }

    /// Check if session is still valid
    public func isSessionValid() -> Bool {
        guard let settings = securitySettings else { return false }
        return sessionManager.isSessionValid(timeout: settings.autoLockTimeout)
    }

    /// Extend current session
    public func extendSession() {
        guard sessionState == .authenticated else { return }
        sessionManager.extendSession()
        resetAutoLockTimer()
    }

    // MARK: - Auto-Lock Functionality

    private func setupAutoLock() {
        guard let settings = securitySettings, settings.autoLockEnabled else { return }
        resetAutoLockTimer()
    }

    private func resetAutoLockTimer() {
        invalidateAutoLockTimer()
        guard let settings = securitySettings, settings.autoLockEnabled else { return }

        autoLockTimer = Timer.scheduledTimer(withTimeInterval: settings.autoLockTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lockSession()
            }
        }
    }

    private func invalidateAutoLockTimer() {
        autoLockTimer?.invalidate()
        autoLockTimer = nil
    }

    // MARK: - Network Security

    /// Validate server certificate and perform certificate pinning
    public func validateServerCertificate(for host: String, certificate: SecCertificate) throws {
        do {
            try certificatePinner.validateCertificate(certificate, for: host)
        } catch {
            auditLogger.log(.certificatePinningFailure)
            throw SecurityError.certificatePinningFailed
        }
    }

    /// Sign a network request for authentication
    public func signRequest(_ request: URLRequest, with apiKey: String) async throws -> URLRequest {
        var signedRequest = request

        // Add timestamp
        let timestamp = String(Int(Date().timeIntervalSince1970))
        signedRequest.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")

        // Create signature
        let bodyData = request.httpBody ?? Data()
        let stringToSign = "\(request.httpMethod ?? "GET")\n\(request.url?.path ?? "")\n\(timestamp)\n\(bodyData.base64EncodedString())"

        let signature = try await createHMACSignature(stringToSign, key: apiKey)
        signedRequest.setValue(signature, forHTTPHeaderField: "X-Signature")

        return signedRequest
    }

    private func createHMACSignature(_ string: String, key: String) async throws -> String {
        let keyData = Data(key.utf8)
        let stringData = Data(string.utf8)

        let signature = HMAC<SHA256>.authenticationCode(for: stringData, using: SymmetricKey(data: keyData))
        return Data(signature).base64EncodedString()
    }

    // MARK: - Security Validation

    /// Check if the device is in a secure state
    private func checkDeviceSecurityStatus() {
        Task {
            let isJailbroken = await isDeviceJailbroken()
            let hasPasscode = await hasDevicePasscode()

            await MainActor.run {
                isDeviceSecure = !isJailbroken && hasPasscode
                lastSecurityCheck = Date()

                if isJailbroken {
                    auditLogger.log(.suspiciousActivity("Jailbroken device detected"))
                }
            }
        }
    }

    /// Detect if device is jailbroken
    private func isDeviceJailbroken() async -> Bool {
        // Check for common jailbreak indicators
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]

        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // Check if we can write to system directories
        do {
            let testString = "jailbreak_test"
            try testString.write(toFile: "/private/test_jailbreak.txt", atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: "/private/test_jailbreak.txt")
            return true
        } catch {
            // Expected behavior on non-jailbroken devices
        }

        return false
    }

    /// Check if device has a passcode set
    private func hasDevicePasscode() async -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkChange(path)
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    private func handleNetworkChange(_ path: NWPath) {
        // Monitor for suspicious network changes
        if path.status == .satisfied && path.isExpensive {
            auditLogger.log(.networkSecurityViolation("Connection switched to expensive network"))
        }

        // Check for VPN usage which might indicate security concerns
        if path.usesInterfaceType(.other) {
            auditLogger.log(.networkSecurityViolation("Potentially insecure network interface detected"))
        }
    }

    // MARK: - Cleanup

    deinit {
        invalidateAutoLockTimer()
        networkMonitor.cancel()
    }
}

// MARK: - Supporting Classes

/// Keychain wrapper for secure storage
private class SecurityKeychain {

    func store(_ data: Data, key: String, requireBiometric: Bool = true) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: requireBiometric ? kSecAttrAccessibleBiometryAny : kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecurityService.SecurityError.keychainError(status)
        }
    }

    func retrieve(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw SecurityService.SecurityError.keychainError(status)
        }

        return result as? Data
    }

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecurityService.SecurityError.keychainError(status)
        }
    }

    func deleteAllItems() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecurityService.SecurityError.keychainError(status)
        }
    }
}

/// Encryption manager using CryptoKit
private class EncryptionManager {
    private let keyPrefix = "mg_encryption_key_"
    private let keychain = SecurityKeychain()

    func encrypt(_ data: Data, context: String) async throws -> Data {
        let key = try await getOrCreateKey(for: context)
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }

    func decrypt(_ encryptedData: Data, context: String) async throws -> Data {
        let key = try await getOrCreateKey(for: context)
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }

    func generateKey(for context: String) async throws {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        try keychain.store(keyData, key: keyPrefix + context)
    }

    func rotateAllKeys() async throws {
        // This would involve re-encrypting all data with new keys
        // Implementation depends on specific data storage architecture
        throw SecurityService.SecurityError.keyGenerationFailed
    }

    func deleteAllKeys() async throws {
        // Delete all encryption keys from keychain
        try keychain.deleteAllItems()
    }

    private func getOrCreateKey(for context: String) async throws -> SymmetricKey {
        let keyName = keyPrefix + context

        if let keyData = try keychain.retrieve(key: keyName) {
            return SymmetricKey(data: keyData)
        } else {
            try await generateKey(for: context)
            guard let keyData = try keychain.retrieve(key: keyName) else {
                throw SecurityService.SecurityError.keyNotFound
            }
            return SymmetricKey(data: keyData)
        }
    }
}

/// Certificate pinning implementation
private class CertificatePinner {
    private let pinnedCertificates: [String: Data] = [:]

    func validateCertificate(_ certificate: SecCertificate, for host: String) throws {
        // In production, this would contain actual pinned certificate data
        // For now, we'll implement basic certificate validation

        let certificateData = SecCertificateCopyData(certificate)
        let data = Data(CFDataGetBytePtr(certificateData), count: CFDataGetLength(certificateData))

        // Validate certificate chain and check against pinned certificates
        if let pinnedData = pinnedCertificates[host] {
            if data != pinnedData {
                throw SecurityService.SecurityError.certificatePinningFailed
            }
        }

        // Additional certificate validation logic would go here
    }
}

/// Security audit logging
private class SecurityAuditLogger {
    private let logQueue = DispatchQueue(label: "SecurityAuditLogger", qos: .utility)

    func log(_ event: SecurityService.AuditEvent) {
        logQueue.async {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let eventDescription = self.eventDescription(for: event)

            // In production, this would send to a secure logging service
            print("[SECURITY AUDIT] \(timestamp): \(eventDescription)")

            // Store locally for security analysis
            self.storeAuditEvent(event, timestamp: timestamp)
        }
    }

    private func eventDescription(for event: SecurityService.AuditEvent) -> String {
        switch event {
        case .biometricAuthSuccess:
            return "Biometric authentication successful"
        case .biometricAuthFailure:
            return "Biometric authentication failed"
        case .sessionStarted:
            return "Security session started"
        case .sessionExpired:
            return "Security session expired"
        case .sessionLocked:
            return "Security session locked"
        case .dataEncrypted(let context):
            return "Data encrypted for context: \(context)"
        case .dataDecrypted(let context):
            return "Data decrypted for context: \(context)"
        case .keyGenerated:
            return "Encryption key generated"
        case .keyRotated:
            return "Encryption keys rotated"
        case .networkSecurityViolation(let reason):
            return "Network security violation: \(reason)"
        case .certificatePinningFailure:
            return "Certificate pinning validation failed"
        case .suspiciousActivity(let description):
            return "Suspicious activity detected: \(description)"
        }
    }

    private func storeAuditEvent(_ event: SecurityService.AuditEvent, timestamp: String) {
        // Store audit events locally for security analysis
        // In production, this would use Core Data or another persistent storage
    }
}

/// Session management
private class SessionManager {
    private var sessionStartTime: Date?
    private var lastActivityTime: Date?
    private var isLocked = false

    func startSession() {
        sessionStartTime = Date()
        lastActivityTime = Date()
        isLocked = false
    }

    func extendSession() {
        lastActivityTime = Date()
    }

    func lockSession() {
        isLocked = true
    }

    func endSession() {
        sessionStartTime = nil
        lastActivityTime = nil
        isLocked = false
    }

    func isSessionValid(timeout: TimeInterval) -> Bool {
        guard !isLocked,
              let lastActivity = lastActivityTime else {
            return false
        }

        return Date().timeIntervalSince(lastActivity) < timeout
    }
}