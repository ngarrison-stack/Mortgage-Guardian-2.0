import SwiftUI

struct PlaidConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var plaidService = PlaidService.shared
    @State private var isConnecting = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("Connect Your Bank")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Securely connect your bank account to verify mortgage payments and detect discrepancies")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Benefits
                    VStack(spacing: 16) {
                        Text("Why Connect Your Bank?")
                            .font(.headline)
                            .fontWeight(.semibold)

                        VStack(spacing: 12) {
                            BenefitRow(
                                icon: "checkmark.shield.fill",
                                title: "Verify Payments",
                                description: "Cross-check your actual payments against servicer records"
                            )

                            BenefitRow(
                                icon: "magnifyingglass.circle.fill",
                                title: "Detect Errors",
                                description: "Automatically find payment allocation mistakes"
                            )

                            BenefitRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Track History",
                                description: "Monitor payment patterns and escrow changes"
                            )

                            BenefitRow(
                                icon: "doc.text.fill",
                                title: "Generate Reports",
                                description: "Create detailed payment history for disputes"
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )

                    // Security Information
                    VStack(spacing: 16) {
                        Text("Bank-Level Security")
                            .font(.headline)
                            .fontWeight(.semibold)

                        VStack(spacing: 8) {
                            SecurityFeature(
                                icon: "lock.shield.fill",
                                text: "256-bit encryption protects your data"
                            )

                            SecurityFeature(
                                icon: "eye.slash.fill",
                                text: "We never see your login credentials"
                            )

                            SecurityFeature(
                                icon: "hand.raised.fill",
                                text: "Read-only access - we cannot move money"
                            )

                            SecurityFeature(
                                icon: "building.2.fill",
                                text: "Trusted by 11,000+ financial apps"
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )

                    // Connection Button
                    Button {
                        connectToBank()
                    } label: {
                        HStack {
                            if isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Connecting...")
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Connect Bank Account")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .disabled(isConnecting)
                    .padding(.horizontal)

                    // Support Information
                    VStack(spacing: 8) {
                        Text("Supported Banks")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Chase, Bank of America, Wells Fargo, Citi, Capital One, US Bank, PNC, TD Bank, and 11,000+ others")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()

                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Bank Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Connection Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func connectToBank() {
        isConnecting = true

        Task {
            do {
                // This would normally launch Plaid Link
                // For now, we'll simulate the connection
                try await simulatePlaidConnection()

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isConnecting = false
                }
            }
        }
    }

    private func simulatePlaidConnection() async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // In real implementation, this would:
        // 1. Launch Plaid Link SDK
        // 2. User selects bank and logs in
        // 3. Plaid returns public_token
        // 4. Exchange public_token for access_token via your backend
        // 5. Store connection and fetch account data

        await MainActor.run {
            // Add mock account to PlaidService
            let mockAccount = PlaidAccount(
                id: "mock_account_\(Date().timeIntervalSince1970)",
                name: "Primary Checking",
                type: "depository",
                subtype: "checking",
                mask: "1234",
                institutionName: "Chase Bank"
            )

            plaidService.addAccount(mockAccount)
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct SecurityFeature: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.green)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

struct ConnectedAccountsView: View {
    @StateObject private var plaidService = PlaidService.shared
    @State private var showingPlaidConnection = false

    var body: some View {
        NavigationView {
            List {
                if plaidService.accounts.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "building.columns")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)

                            VStack(spacing: 8) {
                                Text("No Banks Connected")
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                Text("Connect your bank account to verify mortgage payments and enhance analysis accuracy")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }

                            Button("Connect Bank Account") {
                                showingPlaidConnection = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Section("Connected Accounts") {
                        ForEach(plaidService.accounts) { account in
                            AccountRow(account: account)
                        }
                        .onDelete(perform: deleteAccount)
                    }

                    Section {
                        Button {
                            showingPlaidConnection = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                Text("Add Another Bank")
                            }
                        }
                    }
                }

                Section("Information") {
                    InfoRow(
                        title: "Security",
                        value: "Bank-grade encryption"
                    )

                    InfoRow(
                        title: "Access",
                        value: "Read-only"
                    )

                    InfoRow(
                        title: "Data Usage",
                        value: "Mortgage payment verification only"
                    )
                }
            }
            .navigationTitle("Bank Accounts")
            .toolbar {
                if !plaidService.accounts.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingPlaidConnection = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPlaidConnection) {
                PlaidConnectionView()
            }
        }
    }

    private func deleteAccount(at offsets: IndexSet) {
        for index in offsets {
            let account = plaidService.accounts[index]
            plaidService.removeAccount(account)
        }
    }
}

struct AccountRow: View {
    let account: PlaidAccount

    var body: some View {
        HStack {
            Image(systemName: "building.columns.fill")
                .foregroundColor(.green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(account.institutionName) •••• \(account.mask)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Connected")
                    .font(.caption)
                    .foregroundColor(.green)

                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PlaidConnectionView()
}

#Preview {
    ConnectedAccountsView()
}