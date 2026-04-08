import SwiftUI
import Clerk

@main
struct MortgageAnalyzerApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var documentManager = DocumentManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoading {
                    ProgressView("Loading...")
                } else if authManager.isSignedIn {
                    MainTabView()
                        .environmentObject(authManager)
                        .environmentObject(documentManager)
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
            .onAppear {
                APIClient.shared.onAuthenticationRequired = { [weak authManager] in
                    await authManager?.handleAuthenticationRequired()
                }
            }
        }
    }
}
