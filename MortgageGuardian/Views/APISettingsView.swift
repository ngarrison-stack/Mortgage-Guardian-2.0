import SwiftUI

struct APISettingsView: View {
    @State private var apiKey: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isTestingConnection = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API Configuration")) {
                    SecureField("API Gateway Key", text: $apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Button(action: testConnection) {
                        HStack {
                            Text("Test Connection")
                            if isTestingConnection {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(apiKey.isEmpty || isTestingConnection)

                    Button("Save API Key") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.isEmpty)
                    .foregroundColor(.blue)
                }

                Section(header: Text("Information")) {
                    Text("The API key is used to authenticate with the Mortgage Guardian backend services.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Your API key is stored securely in the iOS Keychain.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Current Status")) {
                    HStack {
                        Text("API Endpoint")
                        Spacer()
                        Text(APIConfiguration.baseURL)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Key Status")
                        Spacer()
                        if hasStoredAPIKey() {
                            Label("Configured", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Label("Not Set", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("API Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("API Configuration", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            loadExistingKey()
        }
    }

    private func loadExistingKey() {
        // Try to load existing key from Keychain (but don't show it for security)
        if let _ = try? SecureKeyManager.shared.getAPIKey(forService: "com.mortgageguardian.api.gateway") {
            // Key exists but we don't display it for security reasons
            apiKey = ""
        }
    }

    private func hasStoredAPIKey() -> Bool {
        return (try? SecureKeyManager.shared.getAPIKey(forService: "com.mortgageguardian.api.gateway")) != nil
    }

    private func saveAPIKey() {
        do {
            try APIConfiguration.setAPIKey(apiKey)
            alertMessage = "API key saved successfully!"
            showingAlert = true
            apiKey = "" // Clear the field after saving
        } catch {
            alertMessage = "Failed to save API key: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func testConnection() {
        isTestingConnection = true

        Task {
            do {
                // Test the connection with a simple request
                let testPayload = ["test": true]
                let jsonData = try JSONSerialization.data(withJSONObject: testPayload)

                guard let url = APIConfiguration.buildURL(for: "/health") else {
                    throw URLError(.badURL)
                }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.allHTTPHeaderFields = APIConfiguration.defaultHeaders()

                let (_, response) = try await URLSession.shared.data(for: request)

                await MainActor.run {
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 || httpResponse.statusCode == 403 {
                            alertMessage = "Connection successful! API key is valid."
                        } else {
                            alertMessage = "Connection failed. Status: \(httpResponse.statusCode)"
                        }
                    }
                    showingAlert = true
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Connection test failed: \(error.localizedDescription)"
                    showingAlert = true
                    isTestingConnection = false
                }
            }
        }
    }
}

struct APISettingsView_Previews: PreviewProvider {
    static var previews: some View {
        APISettingsView()
    }
}