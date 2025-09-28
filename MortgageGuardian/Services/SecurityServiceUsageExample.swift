import SwiftUI
import Foundation

/*
 SECURITY SERVICE USAGE EXAMPLES

 This file demonstrates how to integrate the SecurityService throughout the Mortgage Guardian app.
 These examples show best practices for secure mobile development.
*/

// MARK: - App Initialization Example

@main
struct MortgageGuardianSecureApp: App {
    @StateObject private var securityService = SecurityService.shared
    @StateObject private var userManager = UserManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    setupSecurity()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    private func setupSecurity() {
        // Configure security service with user settings
        if let user = userManager.currentUser {
            securityService.configure(with: user.securitySettings)
        } else {
            // Use default security settings for unauthenticated users
            securityService.configure(with: User.SecuritySettings.default)
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App became active - extend session if authenticated
            if securityService.sessionState == .authenticated {
                securityService.extendSession()
            }
        case .inactive, .background:
            // App going to background - lock session if auto-lock is enabled
            if let user = userManager.currentUser,
               user.securitySettings.autoLockEnabled {
                securityService.lockSession()
            }
        @unknown default:
            break
        }
    }
}

// MARK: - Document Security Example

class SecureDocumentManager: ObservableObject {
    private let securityService = SecurityService.shared
    @Published var documents: [SecureDocument] = []

    struct SecureDocument {
        let id: String
        let title: String
        let createdAt: Date
        var isEncrypted: Bool
    }

    /// Store a mortgage document securely
    func storeDocument(_ data: Data, title: String, type: String) async throws {
        let documentId = UUID().uuidString

        let metadata = [
            "title": title,
            "type": type,
            "size": String(data.count)
        ]

        try await securityService.secureStoreDocument(
            data,
            documentId: documentId,
            metadata: metadata
        )

        await MainActor.run {
            documents.append(SecureDocument(
                id: documentId,
                title: title,
                createdAt: Date(),
                isEncrypted: true
            ))
        }
    }

    /// Retrieve a document securely
    func retrieveDocument(id: String) async throws -> Data {
        return try await securityService.secureRetrieveDocument(documentId: id)
    }

    /// Delete a document securely
    func deleteDocument(id: String) async throws {
        try await securityService.secureDeleteDocument(documentId: id)

        await MainActor.run {
            documents.removeAll { $0.id == id }
        }
    }
}

// MARK: - Authentication Flow Example

struct LoginView: View {
    @StateObject private var securityService = SecurityService.shared
    @State private var showingBiometricAuth = false
    @State private var authenticationError: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Mortgage Guardian")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Secure access to your financial documents")
                .font(.subtitle)
                .foregroundColor(.secondary)

            if securityService.isBiometricAuthenticationAvailable() {
                Button("Sign In with \(securityService.getBiometricDisplayName())") {
                    authenticateWithBiometrics()
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            Button("Sign In with Passcode") {
                authenticateWithPasscode()
            }
            .buttonStyle(SecondaryButtonStyle())

            if let error = authenticationError {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private func authenticateWithBiometrics() {
        Task {
            do {
                try await securityService.authenticateWithBiometrics()
                // Navigation to main app handled by session state change
            } catch let error as SecurityService.SecurityError {
                await MainActor.run {
                    authenticationError = error.localizedDescription
                }
            }
        }
    }

    private func authenticateWithPasscode() {
        Task {
            do {
                try await securityService.authenticateWithPasscode()
                // Navigation to main app handled by session state change
            } catch let error as SecurityService.SecurityError {
                await MainActor.run {
                    authenticationError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Secure Settings View Example

struct SecuritySettingsView: View {
    @StateObject private var securityService = SecurityService.shared
    @ObservedObject var userManager: UserManager
    @State private var showingKeyRotationAlert = false
    @State private var keyRotationInProgress = false

    var body: some View {
        NavigationView {
            List {
                Section("Biometric Authentication") {
                    Toggle("Enable Biometric Authentication",
                           isOn: Binding(
                               get: { userManager.currentUser?.securitySettings.biometricAuthEnabled ?? false },
                               set: { newValue in
                                   updateBiometricSetting(newValue)
                               }
                           ))

                    if securityService.isBiometricAuthenticationAvailable() {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("\(securityService.getBiometricDisplayName()) Available")
                        }
                    } else {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Biometric authentication not available")
                        }
                    }
                }

                Section("Auto-Lock") {
                    Toggle("Enable Auto-Lock",
                           isOn: Binding(
                               get: { userManager.currentUser?.securitySettings.autoLockEnabled ?? false },
                               set: { newValue in
                                   updateAutoLockSetting(newValue)
                               }
                           ))

                    if userManager.currentUser?.securitySettings.autoLockEnabled == true {
                        Picker("Auto-Lock Timeout", selection: Binding(
                            get: { userManager.currentUser?.securitySettings.autoLockTimeout ?? 300 },
                            set: { newValue in
                                updateAutoLockTimeout(newValue)
                            }
                        )) {
                            Text("1 minute").tag(60.0)
                            Text("5 minutes").tag(300.0)
                            Text("15 minutes").tag(900.0)
                            Text("30 minutes").tag(1800.0)
                        }
                    }
                }

                Section("Document Security") {
                    Toggle("Secure Document Storage",
                           isOn: Binding(
                               get: { userManager.currentUser?.securitySettings.secureDocumentStorage ?? false },
                               set: { newValue in
                                   updateSecureStorageSetting(newValue)
                               }
                           ))

                    Toggle("Require Authentication for Export",
                           isOn: Binding(
                               get: { userManager.currentUser?.securitySettings.requireAuthForExport ?? false },
                               set: { newValue in
                                   updateExportAuthSetting(newValue)
                               }
                           ))
                }

                Section("Security Maintenance") {
                    Button("Rotate Encryption Keys") {
                        showingKeyRotationAlert = true
                    }
                    .disabled(keyRotationInProgress)

                    if keyRotationInProgress {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Rotating keys...")
                        }
                    }
                }

                Section("Device Security") {
                    HStack {
                        Text("Device Security Status")
                        Spacer()
                        if securityService.isDeviceSecure {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundColor(.red)
                        }
                    }

                    if let lastCheck = securityService.lastSecurityCheck {
                        Text("Last security check: \(lastCheck, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Security Settings")
        }
        .alert("Rotate Encryption Keys", isPresented: $showingKeyRotationAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Rotate Keys", role: .destructive) {
                rotateEncryptionKeys()
            }
        } message: {
            Text("This will generate new encryption keys for enhanced security. This process may take a few moments.")
        }
    }

    private func updateBiometricSetting(_ enabled: Bool) {
        guard var user = userManager.currentUser else { return }
        user.securitySettings.biometricAuthEnabled = enabled
        userManager.updateUser(user)
        securityService.configure(with: user.securitySettings)
    }

    private func updateAutoLockSetting(_ enabled: Bool) {
        guard var user = userManager.currentUser else { return }
        user.securitySettings.autoLockEnabled = enabled
        userManager.updateUser(user)
        securityService.configure(with: user.securitySettings)
    }

    private func updateAutoLockTimeout(_ timeout: TimeInterval) {
        guard var user = userManager.currentUser else { return }
        user.securitySettings.autoLockTimeout = timeout
        userManager.updateUser(user)
        securityService.configure(with: user.securitySettings)
    }

    private func updateSecureStorageSetting(_ enabled: Bool) {
        guard var user = userManager.currentUser else { return }
        user.securitySettings.secureDocumentStorage = enabled
        userManager.updateUser(user)
    }

    private func updateExportAuthSetting(_ enabled: Bool) {
        guard var user = userManager.currentUser else { return }
        user.securitySettings.requireAuthForExport = enabled
        userManager.updateUser(user)
    }

    private func rotateEncryptionKeys() {
        keyRotationInProgress = true

        Task {
            do {
                try await securityService.rotateKeys()
                await MainActor.run {
                    keyRotationInProgress = false
                }
            } catch {
                await MainActor.run {
                    keyRotationInProgress = false
                    // Handle error
                }
            }
        }
    }
}

// MARK: - Secure API Client Example

class SecureAPIClient: ObservableObject {
    private let securityService = SecurityService.shared
    private let baseURL = "https://api.mortgageguardian.com"

    func uploadDocument(_ data: Data, documentType: String) async throws -> DocumentUploadResponse {
        // Ensure user is authenticated
        try await securityService.requireAuthentication()

        // Get API token
        guard let apiToken = try securityService.getAPIToken(for: "main_api") else {
            throw APIError.missingToken
        }

        // Create secure request
        var request = URLRequest(url: URL(string: "\(baseURL)/documents")!)
        request.httpMethod = "POST"
        request.httpBody = data

        // Perform secure network request
        let (responseData, _) = try await securityService.performSecureRequest(
            request,
            apiKey: apiToken
        )

        return try JSONDecoder().decode(DocumentUploadResponse.self, from: responseData)
    }

    func refreshAPIToken() async throws {
        // Implement token refresh logic
        let newToken = try await performTokenRefresh()
        try securityService.refreshAPIToken(
            for: "main_api",
            newToken: newToken.accessToken,
            expiresIn: newToken.expiresIn
        )
    }

    private func performTokenRefresh() async throws -> TokenResponse {
        // Token refresh implementation
        fatalError("Implement token refresh")
    }
}

// MARK: - Supporting Types

struct DocumentUploadResponse: Codable {
    let documentId: String
    let uploadedAt: Date
}

struct TokenResponse: Codable {
    let accessToken: String
    let expiresIn: TimeInterval
}

enum APIError: Error {
    case missingToken
    case invalidResponse
}

// MARK: - Custom Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// MARK: - UserManager Mock

class UserManager: ObservableObject {
    @Published var currentUser: User?

    func updateUser(_ user: User) {
        currentUser = user
        // Save to persistent storage
    }
}