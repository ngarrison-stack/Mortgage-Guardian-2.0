import SwiftUI
import LocalAuthentication

struct APISettingsView: View {
    @StateObject private var keyManager = SecureKeyManager.shared
    @State private var apiKeys: [APIService: String] = [:]
    @State private var editingService: APIService?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showingInstructions: APIService?
    @State private var showingSecurityPrompt = false
    @State private var hasAuthenticated = false
    @State private var validationErrors: [APIService: String] = [:]
    @State private var savingKeys: Set<APIService> = []

    // Group services by requirement
    private var requiredServices: [APIService] {
        APIService.allCases.filter { $0.isRequired }
    }

    private var optionalServices: [APIService] {
        APIService.allCases.filter { !$0.isRequired }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if !hasAuthenticated {
                    AuthenticationOverlay(
                        hasAuthenticated: $hasAuthenticated,
                        onAuthenticate: authenticateUser
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header Card
                            headerCard

                            // Required Services Section
                            servicesSection(
                                title: "Required Services",
                                services: requiredServices,
                                systemImage: "exclamationmark.triangle.fill",
                                color: .orange
                            )

                            // Optional Services Section
                            servicesSection(
                                title: "Optional Services",
                                services: optionalServices,
                                systemImage: "star.fill",
                                color: .blue
                            )
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("API Configuration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    }
                }
            }
            .alert("Configuration Status", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .sheet(item: $showingInstructions) { service in
                InstructionsView(service: service)
            }
            .sheet(item: $editingService) { service in
                APIKeyEditView(
                    service: service,
                    currentKey: apiKeys[service] ?? "",
                    validationError: validationErrors[service],
                    isSaving: savingKeys.contains(service),
                    onSave: { newKey in
                        saveAPIKey(newKey, for: service)
                    },
                    onDelete: {
                        deleteAPIKey(for: service)
                    }
                )
            }
            .onAppear {
                if hasAuthenticated {
                    loadExistingKeys()
                }
            }
        }
    }

    // MARK: - View Components

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "key.fill")
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("API Configuration")
                        .font(.headline)

                    Text(keyManager.hasAllRequiredKeys() ?
                         "All required keys configured" :
                         "Configure API keys to enable features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status Indicator
                statusIndicator
            }

            // Progress Bar
            progressBar
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var statusIndicator: some View {
        Group {
            if keyManager.hasAllRequiredKeys() {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title)
            } else {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title)
            }
        }
    }

    private var progressBar: some View {
        let configuredCount = APIService.allCases.filter { isKeyConfigured($0) }.count
        let totalCount = APIService.allCases.count
        let progress = Double(configuredCount) / Double(totalCount)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(configuredCount) of \(totalCount) configured")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progress == 1.0 ? Color.green : Color.accentColor)
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 8)
        }
    }

    private func servicesSection(title: String, services: [APIService], systemImage: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
            }

            // Service Cards
            ForEach(services, id: \.self) { service in
                ServiceCard(
                    service: service,
                    isConfigured: isKeyConfigured(service),
                    isSaving: savingKeys.contains(service),
                    validationError: validationErrors[service],
                    onEdit: {
                        editingService = service
                    },
                    onInfo: {
                        showingInstructions = service
                    }
                )
            }
        }
    }

    // MARK: - Helper Methods

    private func isKeyConfigured(_ service: APIService) -> Bool {
        switch service {
        case .claude:
            return keyManager.hasClaudeKey
        case .plaidClientId:
            return (try? keyManager.getAPIKey(forService: .plaidClientId)) != nil
        case .plaidSecret:
            return (try? keyManager.getAPIKey(forService: .plaidSecret)) != nil
        case .marketData:
            return keyManager.hasMarketDataKey
        default:
            return (try? keyManager.getAPIKey(forService: service)) != nil
        }
    }

    private func loadExistingKeys() {
        isLoading = true

        Task {
            for service in APIService.allCases {
                if let key = try? keyManager.getAPIKey(forService: service) {
                    await MainActor.run {
                        // Store masked version for display
                        apiKeys[service] = maskAPIKey(key)
                    }
                }
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func maskAPIKey(_ key: String) -> String {
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        let masked = String(repeating: "•", count: key.count - 8)
        return "\(prefix)\(masked)\(suffix)"
    }

    private func saveAPIKey(_ key: String, for service: APIService) {
        savingKeys.insert(service)
        validationErrors[service] = nil

        // Validate key format
        if let error = validateAPIKey(key, for: service) {
            validationErrors[service] = error
            savingKeys.remove(service)
            return
        }

        Task {
            do {
                try await MainActor.run {
                    try keyManager.updateAPIKey(key, forService: service)
                }

                await MainActor.run {
                    apiKeys[service] = maskAPIKey(key)
                    savingKeys.remove(service)
                    editingService = nil

                    alertMessage = "\(service.displayName) saved successfully"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    validationErrors[service] = error.localizedDescription
                    savingKeys.remove(service)
                }
            }
        }
    }

    private func deleteAPIKey(for service: APIService) {
        keyManager.deleteAPIKey(forService: service)
        apiKeys[service] = nil
        editingService = nil

        alertMessage = "\(service.displayName) removed"
        showingAlert = true
    }

    private func validateAPIKey(_ key: String, for service: APIService) -> String? {
        // Basic validation
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "API key cannot be empty"
        }

        // Service-specific validation
        switch service {
        case .claude:
            if !key.starts(with: "sk-ant-") {
                return "Claude API key should start with 'sk-ant-'"
            }
        case .plaidClientId:
            if key.count < 20 {
                return "Plaid Client ID appears to be too short"
            }
        case .plaidSecret:
            if key.count < 20 {
                return "Plaid Secret appears to be too short"
            }
        default:
            break
        }

        return nil
    }

    private func authenticateUser() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                 localizedReason: "Authenticate to access API settings") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        hasAuthenticated = true
                        loadExistingKeys()
                    } else {
                        // Fall back to passcode
                        authenticateWithPasscode()
                    }
                }
            }
        } else {
            // Biometrics not available, use passcode
            authenticateWithPasscode()
        }
    }

    private func authenticateWithPasscode() {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication,
                              localizedReason: "Authenticate to access API settings") { success, _ in
            DispatchQueue.main.async {
                hasAuthenticated = success
                if success {
                    loadExistingKeys()
                }
            }
        }
    }
}

// MARK: - Service Card Component

struct ServiceCard: View {
    let service: APIService
    let isConfigured: Bool
    let isSaving: Bool
    let validationError: String?
    let onEdit: () -> Void
    let onInfo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Status Icon
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(service.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(service.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }

                    Button(action: onEdit) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.7)
                        } else {
                            Text(isConfigured ? "Edit" : "Add")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isConfigured ? Color.blue : Color.green)
                                .cornerRadius(6)
                        }
                    }
                }
            }

            if let error = validationError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private var statusIcon: String {
        isConfigured ? "checkmark.circle.fill" : "circle.dashed"
    }

    private var statusColor: Color {
        if validationError != nil {
            return .red
        } else if isConfigured {
            return .green
        } else if service.isRequired {
            return .orange
        } else {
            return .gray
        }
    }
}

// MARK: - API Key Edit View

struct APIKeyEditView: View {
    let service: APIService
    @State private var keyInput: String = ""
    let currentKey: String
    let validationError: String?
    let isSaving: Bool
    let onSave: (String) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var isSecureEntry = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(service.displayName)
                            .font(.headline)
                        Text(service.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("API Key") {
                    HStack {
                        if isSecureEntry {
                            SecureField("Enter API key", text: $keyInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            TextField("Enter API key", text: $keyInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        Button(action: { isSecureEntry.toggle() }) {
                            Image(systemName: isSecureEntry ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }

                    if let error = validationError {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                if !currentKey.isEmpty {
                    Section("Current Key") {
                        Text(currentKey)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button(action: {
                        onSave(keyInput)
                    }) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Save Key")
                                    .fontWeight(.medium)
                            }
                            Spacer()
                        }
                    }
                    .disabled(keyInput.isEmpty || isSaving)
                    .foregroundColor(.white)
                    .listRowBackground(Color.accentColor.opacity(keyInput.isEmpty ? 0.5 : 1.0))

                    if !currentKey.isEmpty {
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Remove Key")
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Configure API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Remove API Key?", isPresented: $showingDeleteConfirmation) {
                Button("Remove", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the stored API key for \(service.displayName).")
            }
        }
    }
}

// MARK: - Instructions View

struct InstructionsView: View {
    let service: APIService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Service Info
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(service.displayName)
                                    .font(.headline)
                                Text(service.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if service.isRequired {
                            Label("Required Service", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)

                    // Instructions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How to obtain your API key:")
                            .font(.headline)

                        ForEach(getInstructions(for: service), id: \.self) { instruction in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(instruction.index).")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)

                                Text(instruction.text)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)

                    // Additional Resources
                    if let url = getDocumentationURL(for: service) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Additional Resources")
                                .font(.headline)

                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "link.circle.fill")
                                    Text("View Documentation")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .foregroundColor(.blue)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Setup Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func getInstructions(for service: APIService) -> [(index: Int, text: String)] {
        switch service {
        case .claude:
            return [
                (1, "Visit console.anthropic.com and sign in to your account"),
                (2, "Navigate to API Keys in the left sidebar"),
                (3, "Click 'Create Key' button"),
                (4, "Give your key a descriptive name (e.g., 'Mortgage Guardian')"),
                (5, "Copy the generated API key immediately (it won't be shown again)"),
                (6, "Paste the key in this app's configuration")
            ]
        case .plaidClientId, .plaidSecret:
            return [
                (1, "Go to dashboard.plaid.com and log in"),
                (2, "Navigate to Team Settings > Keys"),
                (3, "Select your environment (Sandbox for testing, Development/Production for live)"),
                (4, "Copy your Client ID and Secret"),
                (5, "Store both values in the respective fields"),
                (6, "Ensure you're using matching environment keys")
            ]
        case .marketData:
            return [
                (1, "Visit your market data provider's dashboard"),
                (2, "Navigate to API credentials section"),
                (3, "Generate a new API key with market data permissions"),
                (4, "Copy and save the API key")
            ]
        case .realEstate:
            return [
                (1, "Register at your real estate data provider"),
                (2, "Subscribe to the appropriate API plan"),
                (3, "Generate API credentials from the dashboard"),
                (4, "Enable property valuation endpoints")
            ]
        case .federalReserve:
            return [
                (1, "Visit api.federalreserve.gov"),
                (2, "Register for a free API key"),
                (3, "Verify your email address"),
                (4, "Copy your API key from the dashboard")
            ]
        }
    }

    private func getDocumentationURL(for service: APIService) -> URL? {
        switch service {
        case .claude:
            return URL(string: "https://docs.anthropic.com/claude/reference/getting-started-with-the-api")
        case .plaidClientId, .plaidSecret:
            return URL(string: "https://plaid.com/docs/api/")
        case .marketData:
            return URL(string: "https://marketdata.com/docs")
        case .realEstate:
            return URL(string: "https://realestateapi.com/documentation")
        case .federalReserve:
            return URL(string: "https://api.federalreserve.gov/documentation")
        }
    }
}

// MARK: - Authentication Overlay

struct AuthenticationOverlay: View {
    @Binding var hasAuthenticated: Bool
    let onAuthenticate: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 12) {
                Text("Authentication Required")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("API keys are sensitive data. Please authenticate to access these settings.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: onAuthenticate) {
                HStack {
                    Image(systemName: "faceid")
                    Text("Authenticate")
                }
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    APISettingsView()
}