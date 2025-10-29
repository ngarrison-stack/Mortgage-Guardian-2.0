// SignInView.swift
import SwiftUI

struct SignInView: View {
    @StateObject private var authManager = AuthManager()
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Mortgage Guardian")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Secure Mortgage Analysis Platform")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Sign In Form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.password)

                    Button {
                        signIn()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Signing In...")
                            } else {
                                Image(systemName: "person.fill")
                                Text("Sign In")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)

                    Button("Create Account") {
                        signUp()
                    }
                    .foregroundColor(.blue)
                }
                .padding()

                Spacer()
            }
            .padding()
            .navigationTitle("Sign In")
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
                    errorMessage = "Check your email for verification code"
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
    SignInView()
}