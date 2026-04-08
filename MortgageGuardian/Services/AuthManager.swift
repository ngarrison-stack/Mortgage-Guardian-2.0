// AuthManager.swift
import Clerk
import SwiftUI

@MainActor
class AuthManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var isLoading = true
    @Published var user: User?

    private var tokenRefreshTask: Task<Void, Never>?

    init() {
        setupClerk()
    }

    private func setupClerk() {
        Clerk.shared.configure(publishableKey: "pk_test_Zm9uZC1tYWtvLTcxLmNsZXJrLmFjY291bnRzLmRldiQ")

        Task {
            if let existingUser = Clerk.shared.user {
                self.user = existingUser
                self.isSignedIn = true
                await refreshToken()
                startPeriodicTokenRefresh()
            }
            self.isLoading = false
        }
    }

    // MARK: - Token Lifecycle

    func refreshToken() async {
        do {
            if let token = try await Clerk.shared.session?.getToken() {
                APIClient.shared.setAuthToken(token.jwt)
            } else {
                try await signOut()
            }
        } catch {
            try? await signOut()
        }
    }

    private func startPeriodicTokenRefresh() {
        tokenRefreshTask?.cancel()
        tokenRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(240))
                guard !Task.isCancelled else { break }
                await self?.refreshToken()
            }
        }
    }

    private func stopPeriodicTokenRefresh() {
        tokenRefreshTask?.cancel()
        tokenRefreshTask = nil
    }

    // MARK: - Authentication

    func signIn(email: String, password: String) async throws {
        let signIn = try await SignIn.create(
            strategy: .identifier(email, password: password)
        )

        if signIn.status == .complete {
            self.user = Clerk.shared.user
            self.isSignedIn = true
            await refreshToken()
            startPeriodicTokenRefresh()
        }
    }

    func signUp(email: String, password: String) async throws {
        _ = try await SignUp.create(
            strategy: .standard(emailAddress: email, password: password)
        )
        print("Sign up created, email verification required")
    }

    func verifyEmail(code: String) async throws {
        guard let signUp = Clerk.shared.client?.signUp else { return }

        if signUp.status == .complete {
            self.user = Clerk.shared.user
            self.isSignedIn = true
            await refreshToken()
            startPeriodicTokenRefresh()
        }
    }

    func signOut() async throws {
        stopPeriodicTokenRefresh()
        try await Clerk.shared.signOut()
        self.user = nil
        self.isSignedIn = false
        APIClient.shared.setAuthToken("")
    }

    // MARK: - 401 Handling

    func handleAuthenticationRequired() async {
        do {
            if let token = try await Clerk.shared.session?.getToken() {
                APIClient.shared.setAuthToken(token.jwt)
            } else {
                try await signOut()
            }
        } catch {
            try? await signOut()
        }
    }
}
