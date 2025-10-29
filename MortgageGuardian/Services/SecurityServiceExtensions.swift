import Foundation
import SwiftUI

// MARK: - SecurityService Extensions for SwiftUI Integration

extension SecurityService {

    /// Check authentication status and present authentication UI if needed
    @MainActor
    public func requireAuthentication() async throws {
        switch sessionState {
        case .authenticated:
            if !isSessionValid() {
                sessionState = .expired
                throw SecurityError.sessionExpired
            }
            extendSession()
            return

        case .unauthenticated, .expired, .locked:
            guard let settings = securitySettings else {
                throw SecurityError.authenticationRequired
            }

            if settings.biometricAuthEnabled && isBiometricAuthenticationAvailable() {
                try await authenticateWithBiometrics()
            } else {
                try await authenticateWithPasscode()
            }
        }
    }

    /// Wrapper for secure operations that require authentication
    public func performSecureOperation<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await requireAuthentication()
        return try await operation()
    }

    /// Get biometric authentication display name for UI
    public func getBiometricDisplayName() -> String {
        switch getBiometricType() {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Biometric Authentication"
        @unknown default:
            return "Biometric Authentication"
        }
    }
}

// MARK: - Document Security Extensions

extension SecurityService {

    /// Secure document storage with metadata
    public func secureStoreDocument(
        _ documentData: Data,
        documentId: String,
        metadata: [String: Any] = [:]
    ) async throws {
        try await requireAuthentication()

        let encryptedData = try await encryptDocument(documentData, documentId: documentId)

        // Store encrypted data and metadata
        let documentInfo = SecureDocumentInfo(
            id: documentId,
            encryptedData: encryptedData,
            metadata: metadata,
            createdAt: Date(),
            lastAccessedAt: Date()
        )

        try storeInKeychain(documentInfo, key: "document_\(documentId)")
    }

    /// Secure document retrieval
    public func secureRetrieveDocument(documentId: String) async throws -> Data {
        try await requireAuthentication()

        guard let documentInfo: SecureDocumentInfo = try retrieveFromKeychain(
            SecureDocumentInfo.self,
            key: "document_\(documentId)"
        ) else {
            throw SecurityError.keyNotFound
        }

        // Update last accessed time
        var updatedInfo = documentInfo
        updatedInfo.lastAccessedAt = Date()
        try storeInKeychain(updatedInfo, key: "document_\(documentId)")

        return try await decryptDocument(documentInfo.encryptedData, documentId: documentId)
    }

    /// Check if document exists and is accessible
    public func documentExists(documentId: String) -> Bool {
        do {
            let _: SecureDocumentInfo? = try retrieveFromKeychain(
                SecureDocumentInfo.self,
                key: "document_\(documentId)"
            )
            return true
        } catch {
            return false
        }
    }

    /// Securely delete document
    public func secureDeleteDocument(documentId: String) async throws {
        try await requireAuthentication()
        try deleteFromKeychain(key: "document_\(documentId)")
    }
}

// MARK: - API Token Management

extension SecurityService {

    /// Store API tokens securely
    public func storeAPIToken(_ token: String, for service: String) throws {
        let tokenInfo = APITokenInfo(
            token: token,
            service: service,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(3600) // 1 hour default
        )

        try storeInKeychain(tokenInfo, key: "api_token_\(service)", requireBiometric: true)
    }

    /// Retrieve API token
    public func getAPIToken(for service: String) throws -> String? {
        guard let tokenInfo: APITokenInfo = try retrieveFromKeychain(
            APITokenInfo.self,
            key: "api_token_\(service)"
        ) else {
            return nil
        }

        // Check if token is expired
        if tokenInfo.expiresAt < Date() {
            try deleteFromKeychain(key: "api_token_\(service)")
            return nil
        }

        return tokenInfo.token
    }

    /// Refresh API token
    public func refreshAPIToken(for service: String, newToken: String, expiresIn: TimeInterval) throws {
        try deleteFromKeychain(key: "api_token_\(service)")

        let tokenInfo = APITokenInfo(
            token: newToken,
            service: service,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(expiresIn)
        )

        try storeInKeychain(tokenInfo, key: "api_token_\(service)", requireBiometric: true)
    }
}

// MARK: - Supporting Data Structures

private struct SecureDocumentInfo: Codable {
    let id: String
    let encryptedData: Data
    let metadata: [String: String] // Simplified metadata for Codable compliance
    let createdAt: Date
    var lastAccessedAt: Date

    init(id: String, encryptedData: Data, metadata: [String: Any], createdAt: Date, lastAccessedAt: Date) {
        self.id = id
        self.encryptedData = encryptedData
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt

        // Convert metadata to string representation
        var stringMetadata: [String: String] = [:]
        for (key, value) in metadata {
            stringMetadata[key] = String(describing: value)
        }
        self.metadata = stringMetadata
    }
}

private struct APITokenInfo: Codable {
    let token: String
    let service: String
    let createdAt: Date
    let expiresAt: Date
}

// MARK: - SwiftUI Modifiers

/// View modifier for requiring authentication before content is displayed
public struct RequireAuthentication: ViewModifier {
    @StateObject private var securityService = SecurityService.shared
    @State private var isAuthenticated = false
    @State private var authenticationError: SecurityService.SecurityError?
    @State private var showingAuthError = false

    public func body(content: Content) -> some View {
        Group {
            if isAuthenticated {
                content
            } else {
                AuthenticationRequiredView(
                    onAuthenticate: authenticate,
                    error: authenticationError
                )
            }
        }
        .onAppear {
            checkAuthentication()
        }
        .onChange(of: securityService.sessionState) { _, newState in
            isAuthenticated = newState == .authenticated
        }
        .alert("Authentication Error", isPresented: $showingAuthError) {
            Button("OK") {
                authenticationError = nil
            }
        } message: {
            Text(authenticationError?.localizedDescription ?? "")
        }
    }

    private func checkAuthentication() {
        isAuthenticated = securityService.sessionState == .authenticated && securityService.isSessionValid()
    }

    private func authenticate() {
        Task {
            do {
                try await securityService.requireAuthentication()
                await MainActor.run {
                    isAuthenticated = true
                }
            } catch let error as SecurityService.SecurityError {
                await MainActor.run {
                    authenticationError = error
                    showingAuthError = true
                }
            } catch {
                await MainActor.run {
                    authenticationError = .authenticationRequired
                    showingAuthError = true
                }
            }
        }
    }
}

/// Authentication required view
private struct AuthenticationRequiredView: View {
    let onAuthenticate: () -> Void
    let error: SecurityService.SecurityError?

    @StateObject private var securityService = SecurityService.shared

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Authentication Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Please authenticate to access your financial documents and data.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            if let error = error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: onAuthenticate) {
                HStack {
                    Image(systemName: securityService.isBiometricAuthenticationAvailable() ? "faceid" : "lock")
                    Text(securityService.isBiometricAuthenticationAvailable() ?
                         "Authenticate with \(securityService.getBiometricDisplayName())" :
                         "Authenticate with Passcode")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - View Extension

extension View {
    /// Require authentication before displaying this view
    public func requireAuthentication() -> some View {
        modifier(RequireAuthentication())
    }
}

// MARK: - Network Security Extensions

extension SecurityService {

    /// Create a secure URLSession with certificate pinning
    public func createSecureURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        let session = URLSession(
            configuration: configuration,
            delegate: SecureURLSessionDelegate(securityService: self),
            delegateQueue: nil
        )

        return session
    }

    /// Perform secure network request
    public func performSecureRequest(
        _ request: URLRequest,
        apiKey: String? = nil
    ) async throws -> (Data, URLResponse) {
        var secureRequest = request

        // Add security headers
        secureRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        secureRequest.setValue("MortgageGuardian/1.0", forHTTPHeaderField: "User-Agent")

        // Sign request if API key is provided
        if let apiKey = apiKey {
            secureRequest = try await signRequest(secureRequest, with: apiKey)
        }

        let session = createSecureURLSession()
        return try await session.data(for: secureRequest)
    }
}

/// Secure URL session delegate for certificate pinning
private class SecureURLSessionDelegate: NSObject, URLSessionDelegate {
    private weak var securityService: SecurityService?

    init(securityService: SecurityService) {
        self.securityService = securityService
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let serverTrust = challenge.protectionSpace.serverTrust,
              let securityService = securityService else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Get server certificate
        guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        do {
            try securityService.validateServerCertificate(
                for: challenge.protectionSpace.host,
                certificate: serverCertificate
            )
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } catch {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}