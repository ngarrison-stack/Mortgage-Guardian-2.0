import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var userStore: UserStore
    @State private var showingProfileEditor = false
    @State private var showingSecuritySettings = false
    @State private var showingAccountManagement = false
    @State private var showingAppInfo = false

    var body: some View {
        NavigationView {
            List {
                // User Profile Section
                Section {
                    Button(action: { showingProfileEditor = true }) {
                        HStack(spacing: 12) {
                            // Avatar
                            Circle()
                                .fill(Color.blue.gradient)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text(userStore.user.firstName.prefix(1) + userStore.user.lastName.prefix(1))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(userStore.user.fullName)
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Text(userStore.user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Profile")
                }

                // Account & Security Section
                Section("Account & Security") {
                    SettingsRow(
                        icon: "shield.fill",
                        title: "Security Settings",
                        subtitle: "Biometrics, auto-lock, privacy",
                        color: .green
                    ) {
                        showingSecuritySettings = true
                    }

                    SettingsRow(
                        icon: "link",
                        title: "Connected Accounts",
                        subtitle: userStore.user.isPlaidConnected ? "Bank account connected" : "No accounts connected",
                        color: .blue
                    ) {
                        showingAccountManagement = true
                    }

                    SettingsRow(
                        icon: "house.fill",
                        title: "Mortgage Accounts",
                        subtitle: "\(userStore.user.mortgageAccounts.count) account(s)",
                        color: .orange
                    ) {
                        // TODO: Navigate to mortgage account management
                    }
                }

                // Preferences Section
                Section("Preferences") {
                    // Theme Selection
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundColor(.indigo)
                            .frame(width: 24, height: 24)

                        Text("Theme")

                        Spacer()

                        Picker("Theme", selection: Binding(
                            get: { userStore.user.preferences.theme },
                            set: { newTheme in
                                var updatedPreferences = userStore.user.preferences
                                updatedPreferences.theme = newTheme
                                userStore.updatePreferences(updatedPreferences)
                            }
                        )) {
                            ForEach(User.UserPreferences.AppTheme.allCases, id: \.self) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 180)
                    }

                    // Notifications Toggle
                    SettingsToggle(
                        icon: "bell.fill",
                        title: "Notifications",
                        subtitle: "App notifications and alerts",
                        color: .red,
                        isOn: Binding(
                            get: { userStore.user.preferences.notificationsEnabled },
                            set: { newValue in
                                var updatedPreferences = userStore.user.preferences
                                updatedPreferences.notificationsEnabled = newValue
                                userStore.updatePreferences(updatedPreferences)
                            }
                        )
                    )

                    // Analysis Notifications Toggle
                    SettingsToggle(
                        icon: "magnifyingglass",
                        title: "Analysis Notifications",
                        subtitle: "Notify when issues are found",
                        color: .purple,
                        isOn: Binding(
                            get: { userStore.user.preferences.analysisNotifications },
                            set: { newValue in
                                var updatedPreferences = userStore.user.preferences
                                updatedPreferences.analysisNotifications = newValue
                                userStore.updatePreferences(updatedPreferences)
                            }
                        )
                    )

                    // Monthly Reports Toggle
                    SettingsToggle(
                        icon: "chart.bar.fill",
                        title: "Monthly Reports",
                        subtitle: "Receive monthly summary reports",
                        color: .teal,
                        isOn: Binding(
                            get: { userStore.user.preferences.monthlyReports },
                            set: { newValue in
                                var updatedPreferences = userStore.user.preferences
                                updatedPreferences.monthlyReports = newValue
                                userStore.updatePreferences(updatedPreferences)
                            }
                        )
                    )
                }

                // Data & Privacy Section
                Section("Data & Privacy") {
                    SettingsRow(
                        icon: "doc.fill",
                        title: "Document Retention",
                        subtitle: "\(userStore.user.preferences.documentRetentionDays) days",
                        color: .brown
                    ) {
                        // TODO: Navigate to document retention settings
                    }

                    SettingsRow(
                        icon: "square.and.arrow.up.fill",
                        title: "Export Data",
                        subtitle: "Download your data",
                        color: .blue
                    ) {
                        exportUserData()
                    }

                    SettingsRow(
                        icon: "trash.fill",
                        title: "Delete Account",
                        subtitle: "Permanently delete your account",
                        color: .red
                    ) {
                        // TODO: Show delete account confirmation
                    }
                }

                // Support Section
                Section("Support") {
                    SettingsRow(
                        icon: "questionmark.circle.fill",
                        title: "Help & FAQ",
                        subtitle: "Get help using the app",
                        color: .blue
                    ) {
                        // TODO: Navigate to help
                    }

                    SettingsRow(
                        icon: "envelope.fill",
                        title: "Contact Support",
                        subtitle: "Get in touch with our team",
                        color: .green
                    ) {
                        contactSupport()
                    }

                    SettingsRow(
                        icon: "star.fill",
                        title: "Rate App",
                        subtitle: "Rate us on the App Store",
                        color: .yellow
                    ) {
                        rateApp()
                    }
                }

                // About Section
                Section("About") {
                    SettingsRow(
                        icon: "info.circle.fill",
                        title: "App Information",
                        subtitle: "Version, terms, privacy policy",
                        color: .gray
                    ) {
                        showingAppInfo = true
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingProfileEditor) {
                ProfileEditorView()
            }
            .sheet(isPresented: $showingSecuritySettings) {
                SecuritySettingsView()
            }
            .sheet(isPresented: $showingAccountManagement) {
                AccountManagementView()
            }
            .sheet(isPresented: $showingAppInfo) {
                AppInfoView()
            }
        }
    }

    // MARK: - Actions
    private func exportUserData() {
        // TODO: Implement data export
        print("Exporting user data")
    }

    private func contactSupport() {
        // TODO: Implement support contact
        print("Contacting support")
    }

    private func rateApp() {
        // TODO: Implement app rating
        print("Rating app")
    }
}

// MARK: - Settings Row Component
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Toggle Component
struct SettingsToggle: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Profile Editor View
struct ProfileEditorView: View {
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) private var dismiss

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phoneNumber: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }

                if let address = userStore.user.address {
                    Section("Address") {
                        Text("Street: \(address.street)")
                        Text("City: \(address.city)")
                        Text("State: \(address.state)")
                        Text("ZIP: \(address.zipCode)")
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentProfile()
            }
        }
    }

    private func loadCurrentProfile() {
        firstName = userStore.user.firstName
        lastName = userStore.user.lastName
        email = userStore.user.email
        phoneNumber = userStore.user.phoneNumber ?? ""
    }

    private func saveProfile() {
        userStore.updateUserProfile(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber
        )
    }
}

// MARK: - Security Settings View
struct SecuritySettingsView: View {
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Authentication") {
                    SettingsToggle(
                        icon: "touchid",
                        title: "Biometric Authentication",
                        subtitle: "Use Face ID or Touch ID to unlock",
                        color: .blue,
                        isOn: Binding(
                            get: { userStore.user.securitySettings.biometricAuthEnabled },
                            set: { newValue in
                                var settings = userStore.user.securitySettings
                                settings.biometricAuthEnabled = newValue
                                userStore.updateSecuritySettings(settings)
                            }
                        )
                    )

                    SettingsToggle(
                        icon: "lock.fill",
                        title: "Auto Lock",
                        subtitle: "Automatically lock the app when inactive",
                        color: .orange,
                        isOn: Binding(
                            get: { userStore.user.securitySettings.autoLockEnabled },
                            set: { newValue in
                                var settings = userStore.user.securitySettings
                                settings.autoLockEnabled = newValue
                                userStore.updateSecuritySettings(settings)
                            }
                        )
                    )

                    if userStore.user.securitySettings.autoLockEnabled {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(.gray)
                                .frame(width: 24, height: 24)

                            Text("Auto Lock Timeout")

                            Spacer()

                            Text("\(Int(userStore.user.securitySettings.autoLockTimeout))s")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Data Protection") {
                    SettingsToggle(
                        icon: "shield.fill",
                        title: "Secure Document Storage",
                        subtitle: "Encrypt documents on device",
                        color: .green,
                        isOn: Binding(
                            get: { userStore.user.securitySettings.secureDocumentStorage },
                            set: { newValue in
                                var settings = userStore.user.securitySettings
                                settings.secureDocumentStorage = newValue
                                userStore.updateSecuritySettings(settings)
                            }
                        )
                    )

                    SettingsToggle(
                        icon: "square.and.arrow.up.trianglebadge.exclamationmark",
                        title: "Require Auth for Export",
                        subtitle: "Authenticate before exporting data",
                        color: .red,
                        isOn: Binding(
                            get: { userStore.user.securitySettings.requireAuthForExport },
                            set: { newValue in
                                var settings = userStore.user.securitySettings
                                settings.requireAuthForExport = newValue
                                userStore.updateSecuritySettings(settings)
                            }
                        )
                    )
                }

                Section("Advanced") {
                    SettingsRow(
                        icon: "key.fill",
                        title: "Change Passcode",
                        subtitle: "Update your app passcode",
                        color: .purple
                    ) {
                        // TODO: Implement passcode change
                    }

                    SettingsRow(
                        icon: "arrow.clockwise",
                        title: "Reset Security Settings",
                        subtitle: "Reset all security settings to default",
                        color: .red
                    ) {
                        resetSecuritySettings()
                    }
                }
            }
            .navigationTitle("Security")
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

    private func resetSecuritySettings() {
        userStore.updateSecuritySettings(User.SecuritySettings.default)
    }
}

// MARK: - Account Management View
struct AccountManagementView: View {
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Bank Accounts") {
                    if userStore.user.isPlaidConnected {
                        ForEach(userStore.plaidAccounts) { account in
                            HStack {
                                Image(systemName: "building.columns.fill")
                                    .foregroundColor(.blue)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.displayName)
                                        .font(.body)
                                        .fontWeight(.medium)

                                    Text(account.institutionName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button("Disconnect") {
                                    userStore.disconnectPlaidAccount(account)
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "link.badge.plus")
                                .font(.title)
                                .foregroundColor(.blue)

                            Text("No Connected Accounts")
                                .font(.headline)

                            Text("Connect your bank account to automatically verify mortgage payments and detect discrepancies.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Connect Bank Account") {
                                connectPlaidAccount()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding()
                    }
                }

                Section("Data Sync") {
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        Text(formatDate(userStore.user.lastLoginDate))
                            .foregroundColor(.secondary)
                    }

                    Button("Sync Now") {
                        userStore.refreshData()
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Connected Accounts")
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

    private func connectPlaidAccount() {
        // TODO: Implement Plaid connection flow
        // For demo purposes, add a sample account
        let sampleAccount = PlaidAccount(
            accountId: "account_sample",
            accountName: "Sample Checking",
            accountType: "depository",
            accountSubtype: "checking",
            institutionName: "Sample Bank",
            mask: "0000",
            isConnected: true,
            lastSyncDate: Date(),
            accessToken: "sample_token"
        )
        userStore.connectPlaidAccount(sampleAccount)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - App Info View
struct AppInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1001")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Legal") {
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                    Link("Open Source Licenses", destination: URL(string: "https://example.com/licenses")!)
                }

                Section("Company") {
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("Mortgage Guardian LLC")
                            .foregroundColor(.secondary)
                    }

                    Link("Website", destination: URL(string: "https://mortgageguardian.com")!)
                    Link("Support", destination: URL(string: "mailto:support@mortgageguardian.com")!)
                }
            }
            .navigationTitle("About")
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
}

#Preview {
    SettingsView()
        .environmentObject(UserStore())
}