import SwiftUI
import Clerk

@main
struct MortgageAnalyzerApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var documentManager = DocumentManager()

    var body: some Scene {
        WindowGroup {
            if authManager.isSignedIn {
                MainTabView()
                    .environmentObject(authManager)
                    .environmentObject(documentManager)
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }

    private func setupCrashProtection() {
        // Pre-initialize critical services to catch crashes early
        Task {
            // Validate that required frameworks are available
            _ = plaidLinkService.accountCount
            // _ = userStore.hasConnectedAccounts // Commented out - not in project
        }
    }
}