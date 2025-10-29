import SwiftUI

#if canImport(LinkKit)
import LinkKit
#endif

struct RealPlaidConnectionView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var plaidService = PlaidLinkService.shared
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

                        Text("Securely connect your bank account using Plaid's industry-leading technology to verify mortgage payments and detect discrepancies")
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

                    // Plaid Security Information
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "shield.checkerboard")
                                .foregroundColor(.blue)
                            Text("Powered by Plaid")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        VStack(spacing: 8) {
                            SecurityFeature(
                                icon: "lock.shield.fill",
                                text: "Bank-level 256-bit encryption"
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

                            SecurityFeature(
                                icon: "checkmark.seal.fill",
                                text: "SOC 2 Type II certified"
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
            .onChange(of: plaidService.errorMessage) { error in
                if let error = error {
                    errorMessage = error
                    showingError = true
                }
            }
        }
    }

    private func connectToBank() {
        #if canImport(LinkKit)
        // LinkKit is available, proceed with real Plaid connection
        isConnecting = true

        Task {
            do {
                // Start the real Plaid Link flow
                try await plaidService.startLinkFlow()

                // Success - dismiss the view
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
        #else
        // LinkKit not available, show error
        errorMessage = "Plaid LinkKit is not available. Please ensure the app is properly configured."
        showingError = true
        #endif
    }
}

struct ConnectedAccountsView: View {
    @StateObject private var plaidService = PlaidLinkService.shared
    @State private var showingPlaidConnection = false
    @State private var isRefreshing = false

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
                        value: "Bank-grade encryption via Plaid"
                    )

                    InfoRow(
                        title: "Access",
                        value: "Read-only"
                    )

                    InfoRow(
                        title: "Data Usage",
                        value: "Mortgage payment verification only"
                    )

                    InfoRow(
                        title: "Provider",
                        value: "Plaid (SOC 2 Type II certified)"
                    )
                }
            }
            .navigationTitle("Bank Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !plaidService.accounts.isEmpty {
                            Button {
                                refreshAccounts()
                            } label: {
                                Image(systemName: isRefreshing ? "arrow.clockwise" : "arrow.clockwise")
                                    .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                                    .animation(isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                            }
                            .disabled(isRefreshing)
                        }

                        Button {
                            showingPlaidConnection = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPlaidConnection) {
                RealPlaidConnectionView()
            }
            .refreshable {
                await refreshAccountsAsync()
            }
        }
    }

    private func deleteAccount(at offsets: IndexSet) {
        for index in offsets {
            let account = plaidService.accounts[index]
            Task {
                try? await plaidService.removeAccount(account)
            }
        }
    }

    private func refreshAccounts() {
        isRefreshing = true
        Task {
            try? await plaidService.refreshAccounts()
            await MainActor.run {
                isRefreshing = false
            }
        }
    }

    private func refreshAccountsAsync() async {
        try? await plaidService.refreshAccounts()
    }
}

struct AccountRow: View {
    let account: PlaidAccount

    var body: some View {
        HStack {
            Image(systemName: account.icon)
                .foregroundColor(.green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(account.accountTypeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(account.institutionName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let balance = account.balance {
                    Text(NumberFormatter.currency.string(from: NSNumber(value: balance)) ?? "$0.00")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)

                    Text("Connected")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
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
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.primary)

            Spacer()
        }
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

// Number formatter extension
extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()
}

#Preview {
    RealPlaidConnectionView()
}

#Preview {
    ConnectedAccountsView()
}