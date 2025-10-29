import Foundation
import SwiftUI

@Observable
class TextractConfigurationService {
    enum ConfigurationError: Error {
        case invalidCredentials
        case storageError
        case missingCredentials
    }

    private let credentialsService = "com.mortgageguardian.api.aws_textract"
    private let regionService = "com.mortgageguardian.api.aws_region"

    // Check if Textract is configured
    var isConfigured: Bool {
        do {
            let _ = try getCredentials()
            let _ = try getRegion()
            return true
        } catch {
            return false
        }
    }

    // Get current configuration status
    func getConfigurationStatus() -> (hasCredentials: Bool, hasRegion: Bool, region: String?) {
        let hasCredentials = (try? getCredentials()) != nil
        let region = try? getRegion()
        return (hasCredentials: hasCredentials, hasRegion: region != nil, region: region)
    }

    // Configure AWS Textract with credentials
    func configure(accessKeyId: String, secretAccessKey: String, region: String = "us-east-1") throws {
        // Validate inputs
        guard !accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConfigurationError.invalidCredentials
        }

        // Store credentials in keychain
        let credentialsString = "\(accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines)):\(secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines))"

        do {
            try SecureKeyManager.shared.storeAPIKey(credentialsString, forService: credentialsService)
            try SecureKeyManager.shared.storeAPIKey(region.trimmingCharacters(in: .whitespacesAndNewlines), forService: regionService)
        } catch {
            throw ConfigurationError.storageError
        }
    }

    // Remove Textract configuration
    func removeConfiguration() throws {
        do {
            try SecureKeyManager.shared.deleteAPIKey(forService: credentialsService)
            try SecureKeyManager.shared.deleteAPIKey(forService: regionService)
        } catch {
            throw ConfigurationError.storageError
        }
    }

    // Test the current configuration
    func testConfiguration() async -> (success: Bool, error: String?) {
        guard isConfigured else {
            return (false, "AWS Textract not configured. Please add your credentials.")
        }

        // Create a small test image (1x1 white pixel)
        let testImage = createTestImage()

        do {
            let textractService = AWSTextractService()
            let result = try await textractService.analyzeDocument(testImage)
            return (true, nil)
        } catch {
            return (false, "Configuration test failed: \(error.localizedDescription)")
        }
    }

    // Get available AWS regions for Textract
    func getSupportedRegions() -> [String] {
        return [
            "us-east-1",      // N. Virginia
            "us-east-2",      // Ohio
            "us-west-1",      // N. California
            "us-west-2",      // Oregon
            "eu-west-1",      // Ireland
            "eu-west-2",      // London
            "eu-west-3",      // Paris
            "eu-central-1",   // Frankfurt
            "ap-southeast-1", // Singapore
            "ap-southeast-2", // Sydney
            "ap-northeast-1", // Tokyo
            "ap-northeast-2", // Seoul
            "ca-central-1"    // Canada
        ]
    }

    // Helper methods
    private func getCredentials() throws -> (accessKeyId: String, secretAccessKey: String) {
        guard let credentialsString = try? SecureKeyManager.shared.getAPIKey(forService: credentialsService) else {
            throw ConfigurationError.missingCredentials
        }

        let components = credentialsString.components(separatedBy: ":")
        guard components.count == 2 else {
            throw ConfigurationError.invalidCredentials
        }

        return (accessKeyId: components[0], secretAccessKey: components[1])
    }

    private func getRegion() throws -> String {
        guard let region = try? SecureKeyManager.shared.getAPIKey(forService: regionService) else {
            throw ConfigurationError.missingCredentials
        }
        return region
    }

    private func createTestImage() -> CGImage {
        // Create a minimal 1x1 white pixel image for testing
        let width = 1
        let height = 1
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(data: nil,
                                    width: width,
                                    height: height,
                                    bitsPerComponent: 8,
                                    bytesPerRow: width * 4,
                                    space: colorSpace,
                                    bitmapInfo: bitmapInfo.rawValue) else {
            fatalError("Could not create CGContext")
        }

        // Fill with white
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let cgImage = context.makeImage() else {
            fatalError("Could not create CGImage")
        }

        return cgImage
    }
}

// SwiftUI view for configuring Textract
struct TextractConfigurationView: View {
    @State private var accessKeyId = ""
    @State private var secretAccessKey = ""
    @State private var selectedRegion = "us-east-1"
    @State private var isConfiguring = false
    @State private var isTesting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""

    private let configService = TextractConfigurationService()

    var body: some View {
        NavigationView {
            Form {
                Section("AWS Credentials") {
                    TextField("Access Key ID", text: $accessKeyId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    SecureField("Secret Access Key", text: $secretAccessKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section("Region") {
                    Picker("AWS Region", selection: $selectedRegion) {
                        ForEach(configService.getSupportedRegions(), id: \.self) { region in
                            Text(region).tag(region)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                Section("Actions") {
                    Button(action: configureTextract) {
                        if isConfiguring {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Configuring...")
                            }
                        } else {
                            Text("Save Configuration")
                        }
                    }
                    .disabled(isConfiguring || accessKeyId.isEmpty || secretAccessKey.isEmpty)

                    Button(action: testConfiguration) {
                        if isTesting {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Testing...")
                            }
                        } else {
                            Text("Test Configuration")
                        }
                    }
                    .disabled(isTesting || !configService.isConfigured)

                    Button("Remove Configuration", role: .destructive) {
                        removeConfiguration()
                    }
                    .disabled(!configService.isConfigured)
                }

                Section("Status") {
                    let status = configService.getConfigurationStatus()

                    HStack {
                        Text("Credentials")
                        Spacer()
                        Text(status.hasCredentials ? "✅ Configured" : "❌ Missing")
                            .foregroundColor(status.hasCredentials ? .green : .red)
                    }

                    HStack {
                        Text("Region")
                        Spacer()
                        Text(status.region ?? "❌ Not set")
                            .foregroundColor(status.hasRegion ? .green : .red)
                    }
                }

                Section("Instructions") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To configure AWS Textract:")
                            .font(.headline)

                        Text("1. Go to AWS IAM Console")
                        Text("2. Create a new IAM user for Textract")
                        Text("3. Attach the 'AmazonTextractReadOnlyAccess' policy")
                        Text("4. Generate access keys")
                        Text("5. Enter the credentials above")

                        Text("Required permissions:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.top)

                        Text("• textract:DetectDocumentText")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("AWS Textract Setup")
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            loadCurrentConfiguration()
        }
    }

    private func loadCurrentConfiguration() {
        let status = configService.getConfigurationStatus()
        if let region = status.region {
            selectedRegion = region
        }
    }

    private func configureTextract() {
        isConfiguring = true

        do {
            try configService.configure(
                accessKeyId: accessKeyId,
                secretAccessKey: secretAccessKey,
                region: selectedRegion
            )

            alertTitle = "Success"
            alertMessage = "AWS Textract has been configured successfully!"
            showingAlert = true

            // Clear the form
            accessKeyId = ""
            secretAccessKey = ""

        } catch {
            alertTitle = "Configuration Error"
            alertMessage = "Failed to configure AWS Textract: \(error.localizedDescription)"
            showingAlert = true
        }

        isConfiguring = false
    }

    private func testConfiguration() {
        isTesting = true

        Task {
            let result = await configService.testConfiguration()

            DispatchQueue.main.async {
                if result.success {
                    alertTitle = "Test Successful"
                    alertMessage = "AWS Textract is configured correctly and working!"
                } else {
                    alertTitle = "Test Failed"
                    alertMessage = result.error ?? "Unknown error occurred"
                }
                showingAlert = true
                isTesting = false
            }
        }
    }

    private func removeConfiguration() {
        do {
            try configService.removeConfiguration()
            alertTitle = "Configuration Removed"
            alertMessage = "AWS Textract configuration has been removed."
            showingAlert = true
        } catch {
            alertTitle = "Error"
            alertMessage = "Failed to remove configuration: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    TextractConfigurationView()
}