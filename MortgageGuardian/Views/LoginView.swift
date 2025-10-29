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

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "house.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    Text("Mortgage Analyzer")
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
                    } label: {
                        Text(isSignUpMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .foregroundColor(.blue)
                    }
                }

                Spacer()

                // Footer
                Text("Secure, private, and RESPA-compliant")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func signIn() {
        isLoading = true
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
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
                    errorMessage = "Check your email for verification instructions"
                    showingError = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}