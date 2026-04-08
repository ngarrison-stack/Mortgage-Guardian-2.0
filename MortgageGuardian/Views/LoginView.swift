// LoginView.swift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var isSignUpMode = false
    @State private var showingVerification = false
    @State private var verificationCode = ""
    @State private var successMessage = ""
    @State private var showingSuccess = false

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                if showingVerification {
                    verificationView
                } else {
                    loginFormView
                }
            }
            .padding()
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") { }
            } message: {
                Text(successMessage)
            }
        }
    }

    // MARK: - Verification View

    private var verificationView: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            Text("Verify Your Email")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter the 6-digit code sent to \(email)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            TextField("Verification Code", text: $verificationCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title3)

            Button {
                verifyEmail()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text("Verify")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(isLoading || verificationCode.isEmpty)

            Button("Back to Sign In") {
                showingVerification = false
                verificationCode = ""
                isSignUpMode = false
            }
            .foregroundColor(.blue)

            Spacer()
        }
    }

    // MARK: - Login Form View

    private var loginFormView: some View {
        Group {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "house.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("Mortgage Guardian")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("AI-Powered Mortgage Document Analysis")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Login Form
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(isSignUpMode ? .newPassword : .password)
                        .submitLabel(.go)
                        .onSubmit {
                            if isSignUpMode {
                                signUp()
                            } else {
                                signIn()
                            }
                        }
                }

                Button {
                    if isSignUpMode {
                        signUp()
                    } else {
                        signIn()
                    }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isSignUpMode ? "Create Account" : "Sign In")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty)

                Button {
                    isSignUpMode.toggle()
                    errorMessage = ""
                } label: {
                    Text(isSignUpMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                }
            }
            .disabled(isLoading)

            Spacer()

            // Footer
            Text("Secure, private, and RESPA-compliant")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func signIn() {
        isLoading = true
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                await MainActor.run {
                    errorMessage = userFriendlyError(error)
                    showingError = true
                    isLoading = false
                }
            }
        }
    }

    private func signUp() {
        isLoading = true
        Task {
            do {
                try await authManager.signUp(email: email, password: password)
                await MainActor.run {
                    showingVerification = true
                    successMessage = "Account created! Enter the verification code sent to your email."
                    showingSuccess = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = userFriendlyError(error)
                    showingError = true
                    isLoading = false
                }
            }
        }
    }

    private func verifyEmail() {
        isLoading = true
        Task {
            do {
                try await authManager.verifyEmail(code: verificationCode)
            } catch {
                await MainActor.run {
                    errorMessage = "Invalid verification code. Please try again."
                    showingError = true
                    isLoading = false
                }
            }
        }
    }

    private func userFriendlyError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("identifier") || message.contains("no account") {
            return "No account found with this email. Check your email or create an account."
        } else if message.contains("password") && (message.contains("incorrect") || message.contains("wrong") || message.contains("invalid")) {
            return "Incorrect password. Please try again."
        } else if message.contains("password") && (message.contains("short") || message.contains("least") || message.contains("character")) {
            return "Password must be at least 8 characters."
        } else if message.contains("already") || message.contains("taken") {
            return "An account with this email already exists. Try signing in."
        } else if error is URLError {
            return "Unable to connect. Please check your internet connection."
        }
        return "Something went wrong. Please try again."
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
