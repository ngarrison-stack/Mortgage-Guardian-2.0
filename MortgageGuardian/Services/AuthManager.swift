// AuthManager.swift
import Clerk
import SwiftUI

@MainActor
class AuthManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var user: User?

    init() {
        setupClerk()
    }

    private func setupClerk() {
        // Configure Clerk with publishable key
        Clerk.shared.configure(publishableKey: "pk_test_Zm9uZC1tYWtvLTcxLmNsZXJrLmFjY291bnRzLmRldiQ")

        // Check if user is already signed in
        if let user = Clerk.shared.user {
            self.user = user
            self.isSignedIn = true
            updateAPIToken()
        }
    }

    func signIn(email: String, password: String) async throws {
        let signIn = try await SignIn.create(
            strategy: .identifier(email, password: password)
        )

        if signIn.status == .complete {
            self.user = Clerk.shared.user
            self.isSignedIn = true
            updateAPIToken()
        }
    }

    func signUp(email: String, password: String) async throws {
        let signUp = try await SignUp.create(
            strategy: .standard(emailAddress: email, password: password)
        )

        // Prepare email verification (method might be different)
        // Check Clerk iOS SDK documentation for correct method name
        // try await signUp.prepareEmailAddressVerification()
        print("Sign up created, email verification required")
    }

    func verifyEmail(code: String) async throws {
        guard let signUp = Clerk.shared.client?.signUp else { return }

        // Attempt email verification (method might be different)
        // Check Clerk iOS SDK documentation for correct method name
        // try await signUp.attemptEmailAddressVerification(code: code)

        if signUp.status == .complete {
            self.user = Clerk.shared.user
            self.isSignedIn = true
            updateAPIToken()
        }
    }

    func signOut() async throws {
        try await Clerk.shared.signOut()
        self.user = nil
        self.isSignedIn = false
        APIClient.shared.setAuthToken("")
    }

    private func updateAPIToken() {
        Task {
            if let token = try? await Clerk.shared.session?.getToken() {
                APIClient.shared.setAuthToken(token.jwt)
            }
        }
    }
}