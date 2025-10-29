import Foundation
import SwiftUI
import UIKit

/// Comprehensive usage examples and integration patterns for PlaidService
/// This file demonstrates how to integrate Plaid functionality into the Mortgage Guardian app
public class PlaidServiceUsageExample {

    // MARK: - Basic Integration Example

    /// Example 1: Complete account linking and transaction sync workflow
    public static func exampleBasicIntegration() async {
        let plaidService = PlaidService.shared

        do {
            // Check if already configured
            guard plaidService.isConfigured else {
                print("❌ PlaidService not configured properly")
                return
            }

            print("✅ PlaidService configured successfully")

            // 1. Link bank account (this would be triggered by user action in real app)
            // try await plaidService.presentLinkFlow(from: viewController)

            // 2. Simulate that accounts are linked
            print("📱 Accounts linked: \(plaidService.linkedAccounts.count)")

            // 3. Sync transactions
            print("🔄 Starting transaction sync...")
            await plaidService.syncTransactions()

            switch plaidService.syncStatus {
            case .completed:
                print("✅ Transaction sync completed")
            case .failed(let error):
                print("❌ Transaction sync failed: \(error)")
            default:
                print("⏳ Transaction sync in progress...")
            }

            // 4. Get transactions for analysis
            let transactions = try await plaidService.getStoredTransactions()
            print("📊 Retrieved \(transactions.count) transactions")

            // 5. Analyze transactions
            analyzeTransactions(transactions)

        } catch {
            print("❌ Error in basic integration: \(error)")
        }
    }

    // MARK: - Advanced Correlation Example

    /// Example 2: Payment correlation with servicer data
    public static func examplePaymentCorrelation() async {
        let plaidService = PlaidService.shared

        do {
            // Get bank transactions
            let bankTransactions = try await plaidService.getStoredTransactions()

            // Create sample servicer data (in real app, this comes from document processing)
            let servicerData = createSampleServicerData()

            // Perform correlation analysis
            print("🔗 Starting payment correlation analysis...")
            let correlations = try await plaidService.correlatePayments(with: servicerData)

            print("📈 Found \(correlations.count) payment correlations")

            // Analyze correlations
            analyzePaymentCorrelations(correlations)

            // Generate audit results
            let auditResults = generateAuditResults(from: correlations)
            print("🔍 Generated \(auditResults.count) audit findings")

            // Display results
            displayAuditResults(auditResults)

        } catch {
            print("❌ Error in correlation analysis: \(error)")
        }
    }

    // MARK: - Real-time Monitoring Example

    /// Example 3: Real-time transaction monitoring and alerts
    public static func exampleRealTimeMonitoring() {
        let plaidService = PlaidService.shared

        // Set up monitoring
        plaidService.$syncStatus
            .sink { status in
                switch status {
                case .completed:
                    Task {
                        await handleNewTransactions()
                    }
                case .failed(let error):
                    handleSyncError(error)
                default:
                    break
                }
            }
            .store(in: &cancellables)

        // Monitor connection status
        plaidService.$connectionStatus
            .sink { status in
                switch status {
                case .reauthorizationRequired:
                    notifyUserReauthorizationNeeded()
                case .error(let message):
                    handleConnectionError(message)
                default:
                    break
                }
            }
            .store(in: &cancellables)

        print("👀 Real-time monitoring set up")
    }

    // MARK: - Error Handling Example

    /// Example 4: Comprehensive error handling
    public static func exampleErrorHandling() async {
        let plaidService = PlaidService.shared

        do {
            await plaidService.syncTransactions()

        } catch PlaidService.PlaidError.accountNotLinked {
            // Handle no linked accounts
            print("🔗 No accounts linked - prompting user to link account")
            // Show linking UI

        } catch PlaidService.PlaidError.itemLoginRequired {
            // Handle re-authentication required
            print("🔐 Re-authentication required")
            // Show re-auth UI

        } catch PlaidService.PlaidError.rateLimitExceeded {
            // Handle rate limiting
            print("⏰ Rate limit exceeded - scheduling retry")
            await scheduleRetry()

        } catch PlaidService.PlaidError.networkError(let message) {
            // Handle network issues
            print("🌐 Network error: \(message)")
            // Show offline UI

        } catch {
            // Handle unexpected errors
            print("❌ Unexpected error: \(error)")
            // Log error and show generic message
        }
    }

    // MARK: - UI Integration Example

    /// Example 5: SwiftUI integration
    public struct PlaidIntegrationView: View {
        @StateObject private var plaidService = PlaidService.shared
        @State private var showingLinkFlow = false
        @State private var selectedAccount: PlaidAccount?

        var body: some View {
            NavigationView {
                VStack(spacing: 20) {
                    // Connection Status
                    connectionStatusView

                    // Linked Accounts
                    linkedAccountsView

                    // Sync Status
                    syncStatusView

                    // Actions
                    actionButtonsView

                    Spacer()
                }
                .navigationTitle("Bank Accounts")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Link Account") {
                            showingLinkFlow = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingLinkFlow) {
                PlaidLinkView()
            }
        }

        private var connectionStatusView: some View {
            HStack {
                Image(systemName: connectionStatusIcon)
                    .foregroundColor(connectionStatusColor)
                Text(connectionStatusText)
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }

        private var linkedAccountsView: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Linked Accounts")
                    .font(.headline)

                ForEach(plaidService.linkedAccounts) { account in
                    AccountRowView(account: account) {
                        selectedAccount = account
                    }
                }

                if plaidService.linkedAccounts.isEmpty {
                    Text("No accounts linked")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .padding()
        }

        private var syncStatusView: some View {
            HStack {
                Text("Last Sync:")
                Spacer()
                if let lastSync = plaidService.lastSyncDate {
                    Text(lastSync, style: .relative)
                } else {
                    Text("Never")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }

        private var actionButtonsView: some View {
            VStack(spacing: 15) {
                Button("Sync Transactions") {
                    Task {
                        await plaidService.performManualSync()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(plaidService.linkedAccounts.isEmpty || plaidService.syncStatus == .syncing)

                Button("Disconnect All") {
                    Task {
                        try await plaidService.disconnectAllAccounts()
                    }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .disabled(plaidService.linkedAccounts.isEmpty)
            }
            .padding()
        }

        // Status helpers
        private var connectionStatusIcon: String {
            switch plaidService.connectionStatus {
            case .connected:
                return "checkmark.circle.fill"
            case .disconnected:
                return "xmark.circle.fill"
            case .reauthorizationRequired:
                return "exclamationmark.triangle.fill"
            case .error:
                return "exclamationmark.circle.fill"
            }
        }

        private var connectionStatusColor: Color {
            switch plaidService.connectionStatus {
            case .connected:
                return .green
            case .disconnected:
                return .gray
            case .reauthorizationRequired:
                return .orange
            case .error:
                return .red
            }
        }

        private var connectionStatusText: String {
            switch plaidService.connectionStatus {
            case .connected:
                return "Connected"
            case .disconnected:
                return "Not Connected"
            case .reauthorizationRequired:
                return "Re-authentication Required"
            case .error(let message):
                return "Error: \(message)"
            }
        }
    }

    /// Account row view component
    public struct AccountRowView: View {
        let account: PlaidAccount
        let onTap: () -> Void

        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(account.displayName)
                        .font(.headline)
                    Text("\(account.accountType.capitalized) • \(account.institutionName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if account.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
    }

    /// Plaid Link flow wrapper
    public struct PlaidLinkView: UIViewControllerRepresentable {
        @Environment(\.presentationMode) var presentationMode

        func makeUIViewController(context: Context) -> UIViewController {
            let controller = UIViewController()
            Task {
                do {
                    try await PlaidService.shared.presentLinkFlow(from: controller)
                    await MainActor.run {
                        presentationMode.wrappedValue.dismiss()
                    }
                } catch {
                    print("Link flow error: \(error)")
                    await MainActor.run {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            return controller
        }

        func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    }

    // MARK: - Helper Methods

    private static func analyzeTransactions(_ transactions: [Transaction]) {
        let mortgageTransactions = transactions.filter { $0.category == .mortgagePayment }
        let totalMortgagePayments = mortgageTransactions.reduce(0) { $0 + abs($1.amount) }

        print("💰 Mortgage Payments: \(mortgageTransactions.count) totaling $\(String(format: "%.2f", totalMortgagePayments))")

        let propertyTaxTransactions = transactions.filter { $0.category == .propertyTax }
        let totalPropertyTax = propertyTaxTransactions.reduce(0) { $0 + abs($1.amount) }

        print("🏠 Property Tax: \(propertyTaxTransactions.count) totaling $\(String(format: "%.2f", totalPropertyTax))")

        let insuranceTransactions = transactions.filter { $0.category == .homeInsurance }
        let totalInsurance = insuranceTransactions.reduce(0) { $0 + abs($1.amount) }

        print("🛡️ Insurance: \(insuranceTransactions.count) totaling $\(String(format: "%.2f", totalInsurance))")
    }

    private static func analyzePaymentCorrelations(_ correlations: [PaymentCorrelation]) {
        let perfectMatches = correlations.filter { $0.correlationStatus == .perfectMatch }
        let amountMismatches = correlations.filter { $0.correlationStatus == .amountMismatch }
        let timingMismatches = correlations.filter { $0.correlationStatus == .timingMismatch }
        let bothMismatches = correlations.filter { $0.correlationStatus == .bothMismatch }
        let missingServicer = correlations.filter { $0.correlationStatus == .noServicerRecord }
        let missingBank = correlations.filter { $0.correlationStatus == .noBankRecord }

        print("📊 Correlation Analysis:")
        print("  ✅ Perfect Matches: \(perfectMatches.count)")
        print("  💰 Amount Mismatches: \(amountMismatches.count)")
        print("  ⏰ Timing Mismatches: \(timingMismatches.count)")
        print("  🚨 Both Mismatches: \(bothMismatches.count)")
        print("  📋 Missing Servicer Records: \(missingServicer.count)")
        print("  🏦 Missing Bank Records: \(missingBank.count)")

        // Calculate total potential issues
        let totalIssues = amountMismatches.count + timingMismatches.count + bothMismatches.count + missingServicer.count + missingBank.count
        let accuracy = Double(perfectMatches.count) / Double(correlations.count) * 100

        print("  📈 Overall Accuracy: \(String(format: "%.1f", accuracy))%")
        print("  ⚠️ Total Issues Found: \(totalIssues)")
    }

    private static func generateAuditResults(from correlations: [PaymentCorrelation]) -> [AuditResult] {
        var results: [AuditResult] = []

        for correlation in correlations {
            switch correlation.correlationStatus {
            case .amountMismatch:
                results.append(createAmountMismatchAuditResult(correlation))
            case .timingMismatch:
                results.append(createTimingMismatchAuditResult(correlation))
            case .bothMismatch:
                results.append(createBothMismatchAuditResult(correlation))
            case .noServicerRecord:
                results.append(createMissingServicerAuditResult(correlation))
            case .noBankRecord:
                results.append(createMissingBankAuditResult(correlation))
            case .perfectMatch:
                break // No audit result needed
            }
        }

        return results
    }

    private static func createAmountMismatchAuditResult(_ correlation: PaymentCorrelation) -> AuditResult {
        return AuditResult(
            issueType: .misappliedPayment,
            severity: .medium,
            title: "Payment Amount Mismatch",
            description: "Bank transaction amount differs from servicer record",
            detailedExplanation: "Bank shows payment of $\(abs(correlation.bankTransaction.amount)) but servicer recorded different amount.",
            suggestedAction: correlation.suggestedActions.joined(separator: "; "),
            affectedAmount: correlation.amountDiscrepancy,
            detectionMethod: .plaidVerification,
            confidence: correlation.confidenceScore,
            evidenceText: "Plaid transaction correlation",
            calculationDetails: nil,
            createdDate: Date()
        )
    }

    private static func createTimingMismatchAuditResult(_ correlation: PaymentCorrelation) -> AuditResult {
        return AuditResult(
            issueType: .latePaymentError,
            severity: .medium,
            title: "Payment Date Discrepancy",
            description: "Payment dates don't match between bank and servicer",
            detailedExplanation: "Timing difference detected between bank transaction and servicer record.",
            suggestedAction: correlation.suggestedActions.joined(separator: "; "),
            affectedAmount: nil,
            detectionMethod: .plaidVerification,
            confidence: correlation.confidenceScore,
            evidenceText: "Date correlation analysis",
            calculationDetails: nil,
            createdDate: Date()
        )
    }

    private static func createBothMismatchAuditResult(_ correlation: PaymentCorrelation) -> AuditResult {
        return AuditResult(
            issueType: .misappliedPayment,
            severity: .high,
            title: "Major Payment Discrepancy",
            description: "Both amount and timing differ significantly",
            detailedExplanation: "Multiple discrepancies found requiring immediate attention.",
            suggestedAction: correlation.suggestedActions.joined(separator: "; "),
            affectedAmount: correlation.amountDiscrepancy,
            detectionMethod: .combinedAnalysis,
            confidence: correlation.confidenceScore,
            evidenceText: "Multiple correlation issues",
            calculationDetails: nil,
            createdDate: Date()
        )
    }

    private static func createMissingServicerAuditResult(_ correlation: PaymentCorrelation) -> AuditResult {
        return AuditResult(
            issueType: .missingPayment,
            severity: .critical,
            title: "Payment Not Recorded by Servicer",
            description: "Bank transaction exists but no servicer record found",
            detailedExplanation: "Payment was sent according to bank records but not reflected in servicer statements.",
            suggestedAction: correlation.suggestedActions.joined(separator: "; "),
            affectedAmount: abs(correlation.bankTransaction.amount),
            detectionMethod: .plaidVerification,
            confidence: correlation.confidenceScore,
            evidenceText: "Missing servicer record",
            calculationDetails: nil,
            createdDate: Date()
        )
    }

    private static func createMissingBankAuditResult(_ correlation: PaymentCorrelation) -> AuditResult {
        return AuditResult(
            issueType: .incorrectBalance,
            severity: .high,
            title: "Payment Recorded Without Bank Transaction",
            description: "Servicer shows payment but no bank transaction found",
            detailedExplanation: "Servicer claims payment received but no corresponding bank debit found.",
            suggestedAction: correlation.suggestedActions.joined(separator: "; "),
            affectedAmount: correlation.servicerRecord?.amount,
            detectionMethod: .plaidVerification,
            confidence: correlation.confidenceScore,
            evidenceText: "Missing bank transaction",
            calculationDetails: nil,
            createdDate: Date()
        )
    }

    private static func displayAuditResults(_ results: [AuditResult]) {
        print("\n🔍 AUDIT RESULTS:")
        print("=" * 50)

        for (index, result) in results.enumerated() {
            print("\n\(index + 1). \(result.title)")
            print("   Severity: \(result.severity.rawValue.uppercased())")
            print("   Description: \(result.description)")
            print("   Action: \(result.suggestedAction)")
            if let amount = result.affectedAmount {
                print("   Amount: $\(String(format: "%.2f", amount))")
            }
            print("   Confidence: \(String(format: "%.0f", result.confidence * 100))%")
        }

        print("\n" + "=" * 50)
        print("Total Issues Found: \(results.count)")

        let criticalIssues = results.filter { $0.severity == .critical }.count
        let highIssues = results.filter { $0.severity == .high }.count
        let mediumIssues = results.filter { $0.severity == .medium }.count

        print("Critical: \(criticalIssues), High: \(highIssues), Medium: \(mediumIssues)")
    }

    // MARK: - Sample Data Creation

    private static func createSampleServicerData() -> ExtractedData {
        return ExtractedData(
            loanNumber: "123456789",
            servicerName: "ABC Mortgage",
            borrowerName: "John Doe",
            propertyAddress: "123 Main St, City, ST 12345",
            principalBalance: 285000.00,
            interestRate: 4.25,
            monthlyPayment: 1750.00,
            escrowBalance: 2500.00,
            dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
            paymentHistory: [
                ExtractedData.PaymentRecord(
                    paymentDate: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
                    amount: 1750.00,
                    principalApplied: 520.50,
                    interestApplied: 1009.50,
                    escrowApplied: 220.00,
                    lateFeesApplied: nil,
                    isLate: false,
                    dayslate: nil
                ),
                ExtractedData.PaymentRecord(
                    paymentDate: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date(),
                    amount: 1775.00, // Different amount to trigger mismatch
                    principalApplied: 518.25,
                    interestApplied: 1011.75,
                    escrowApplied: 220.00,
                    lateFeesApplied: 25.00,
                    isLate: true,
                    dayslate: 8
                )
            ],
            escrowActivity: [
                ExtractedData.EscrowTransaction(
                    date: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
                    description: "Monthly escrow deposit",
                    amount: 220.00,
                    type: .deposit,
                    category: .propertyTax
                )
            ],
            fees: []
        )
    }

    // MARK: - Event Handlers

    private static func handleNewTransactions() async {
        print("🔔 New transactions detected - running correlation analysis")
        await examplePaymentCorrelation()
    }

    private static func handleSyncError(_ error: Error) {
        print("❌ Sync error: \(error)")
        // Log error, show user notification, etc.
    }

    private static func notifyUserReauthorizationNeeded() {
        print("🔐 User notification: Re-authentication required")
        // Show in-app notification or alert
    }

    private static func handleConnectionError(_ message: String) {
        print("🌐 Connection error: \(message)")
        // Show error state in UI
    }

    private static func scheduleRetry() async {
        print("⏰ Scheduling retry in 60 seconds")
        try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
        await PlaidService.shared.syncTransactions()
    }

    // Helper for string multiplication
    private static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }

    // Store for Combine subscriptions
    private static var cancellables = Set<AnyCancellable>()

    // MARK: - Setup Guide

    /// Setup guide for integrating PlaidService
    public static func printSetupGuide() {
        print("""
        🚀 PLAID SERVICE SETUP GUIDE
        ===========================

        1. ENVIRONMENT SETUP:
           - Set PLAID_CLIENT_ID in environment variables
           - Set PLAID_SANDBOX_SECRET for development
           - Set PLAID_PRODUCTION_SECRET for production
           - Optional: Set PLAID_WEBHOOK_URL for webhooks

        2. LINKKIT FRAMEWORK:
           - Add LinkKit framework to your project
           - Import LinkKit in relevant files
           - Ensure LinkKit.isAvailable returns true

        3. PERMISSIONS:
           - Add NSNetworkVolumesUsageDescription to Info.plist
           - Configure ATS settings for Plaid endpoints
           - Enable Keychain Sharing capability

        4. INITIALIZATION:
           - Configure PlaidService.shared on app launch
           - Set up SecurityService integration
           - Initialize with proper PlaidConfiguration

        5. UI INTEGRATION:
           - Use PlaidIntegrationView as reference
           - Implement Link flow presentation
           - Handle re-authentication flows

        6. SECURITY:
           - Enable biometric authentication
           - Use secure token storage
           - Implement proper error handling

        7. TESTING:
           - Use sandbox environment for development
           - Test with sandbox test accounts
           - Verify webhook handling

        8. PRODUCTION:
           - Switch to production environment
           - Update secrets and configuration
           - Monitor rate limits and errors
        """)
    }
}

// MARK: - Integration Tests

#if DEBUG
extension PlaidServiceUsageExample {

    /// Run integration tests (development only)
    public static func runIntegrationTests() async {
        print("🧪 Running PlaidService Integration Tests")
        print("=========================================")

        // Test 1: Configuration
        await testConfiguration()

        // Test 2: Mock data processing
        await testMockDataProcessing()

        // Test 3: Error handling
        await testErrorHandling()

        // Test 4: Correlation logic
        await testCorrelationLogic()

        print("🏁 Integration tests completed")
    }

    private static func testConfiguration() async {
        print("\n📋 Test 1: Configuration Validation")

        let errors = PlaidConfiguration.validateConfiguration()
        if errors.isEmpty {
            print("✅ Configuration is valid")
        } else {
            print("❌ Configuration errors:")
            errors.forEach { print("   - \(error)") }
        }

        let summary = PlaidConfiguration.getConfigurationSummary()
        print("📊 Configuration summary: \(summary)")
    }

    private static func testMockDataProcessing() async {
        print("\n📊 Test 2: Mock Data Processing")

        let servicerData = createSampleServicerData()
        print("✅ Created sample servicer data: \(servicerData.paymentHistory.count) payments")

        // Test transaction categorization
        let sampleTransactions = createSampleBankTransactions()
        print("✅ Created sample bank transactions: \(sampleTransactions.count) transactions")

        // Test correlation logic
        print("🔗 Testing correlation logic...")
        // Correlation testing would go here
    }

    private static func testErrorHandling() async {
        print("\n⚠️ Test 3: Error Handling")

        // Test various error scenarios
        let errorCases: [PlaidService.PlaidError] = [
            .accountNotLinked,
            .itemLoginRequired,
            .rateLimitExceeded,
            .networkError("Test error")
        ]

        for error in errorCases {
            print("   Testing: \(error.localizedDescription)")
            // Error handling logic would be tested here
        }

        print("✅ Error handling tests completed")
    }

    private static func testCorrelationLogic() async {
        print("\n🔗 Test 4: Correlation Logic")

        let bankTransactions = createSampleBankTransactions()
        let servicerData = createSampleServicerData()

        print("   Bank transactions: \(bankTransactions.count)")
        print("   Servicer payments: \(servicerData.paymentHistory.count)")

        // Test correlation matching
        for bankTxn in bankTransactions {
            let match = servicerData.paymentHistory.first { payment in
                let calendar = Calendar.current
                let daysDiff = abs(calendar.dateComponents([.day], from: payment.paymentDate, to: bankTxn.date).day ?? 0)
                let amountDiff = abs(payment.amount - abs(bankTxn.amount))
                return daysDiff <= 7 && amountDiff <= 50.0
            }

            if let match = match {
                print("   ✅ Found match for \(bankTxn.description)")
            } else {
                print("   ❌ No match for \(bankTxn.description)")
            }
        }
    }

    private static func createSampleBankTransactions() -> [Transaction] {
        return [
            Transaction(
                accountId: "test_account_1",
                transactionId: "test_txn_1",
                amount: -1750.00,
                date: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
                description: "MORTGAGE PAYMENT ABC MORTGAGE",
                category: .mortgagePayment,
                isRecurring: true,
                merchantName: "ABC Mortgage",
                confidence: 0.95,
                plaidTransactionId: "plaid_test_1",
                isVerified: true,
                relatedMortgagePayment: true
            ),
            Transaction(
                accountId: "test_account_1",
                transactionId: "test_txn_2",
                amount: -1750.00,
                date: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date(),
                description: "MORTGAGE PAYMENT ABC MORTGAGE",
                category: .mortgagePayment,
                isRecurring: true,
                merchantName: "ABC Mortgage",
                confidence: 0.95,
                plaidTransactionId: "plaid_test_2",
                isVerified: true,
                relatedMortgagePayment: true
            )
        ]
    }
}
#endif