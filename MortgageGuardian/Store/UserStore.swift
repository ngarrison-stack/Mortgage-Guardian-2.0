import Foundation
import SwiftUI
import Combine

/// ObservableObject that manages user state and provides data for the entire app
class UserStore: ObservableObject {
    @Published var user: User
    @Published var documents: [MortgageDocument] = []
    @Published var auditResults: [AuditResult] = []
    @Published var transactions: [Transaction] = []
    @Published var plaidAccounts: [PlaidAccount] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Initialize with sample user for demo purposes
        self.user = User.sampleUser
        loadSampleData()
    }

    // MARK: - Document Management
    func addDocument(_ document: MortgageDocument) {
        documents.append(document)
        objectWillChange.send()
    }

    func removeDocument(_ document: MortgageDocument) {
        documents.removeAll { $0.id == document.id }
        objectWillChange.send()
    }

    func documentsForType(_ type: MortgageDocument.DocumentType) -> [MortgageDocument] {
        return documents.filter { $0.documentType == type }
    }

    // MARK: - Analysis Management
    func addAuditResult(_ result: AuditResult) {
        auditResults.append(result)
        objectWillChange.send()
    }

    func auditResultsForSeverity(_ severity: AuditResult.Severity) -> [AuditResult] {
        return auditResults.filter { $0.severity == severity }
    }

    func criticalIssuesCount() -> Int {
        return auditResults.filter { $0.severity == .critical }.count
    }

    func highIssuesCount() -> Int {
        return auditResults.filter { $0.severity == .high }.count
    }

    func totalPotentialSavings() -> Double {
        return auditResults.compactMap { $0.affectedAmount }.reduce(0, +)
    }

    // MARK: - User Profile Management
    func updateUserProfile(firstName: String, lastName: String, email: String, phoneNumber: String?) {
        user.firstName = firstName
        user.lastName = lastName
        user.email = email
        user.phoneNumber = phoneNumber
        objectWillChange.send()
    }

    func updateSecuritySettings(_ settings: User.SecuritySettings) {
        user.securitySettings = settings
        objectWillChange.send()
    }

    func updatePreferences(_ preferences: User.UserPreferences) {
        user.preferences = preferences
        objectWillChange.send()
    }

    func addMortgageAccount(_ account: User.MortgageAccount) {
        user.mortgageAccounts.append(account)
        objectWillChange.send()
    }

    func removeMortgageAccount(_ account: User.MortgageAccount) {
        user.mortgageAccounts.removeAll { $0.id == account.id }
        objectWillChange.send()
    }

    // MARK: - Plaid Integration
    func connectPlaidAccount(_ account: PlaidAccount) {
        plaidAccounts.append(account)
        user.isPlaidConnected = true
        objectWillChange.send()
    }

    func disconnectPlaidAccount(_ account: PlaidAccount) {
        plaidAccounts.removeAll { $0.id == account.id }
        if plaidAccounts.isEmpty {
            user.isPlaidConnected = false
        }
        objectWillChange.send()
    }

    // MARK: - Data Refresh

    /// Fetches documents from the Express backend and merges with local-only documents.
    @MainActor
    func fetchDocumentsFromBackend() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIClient.shared.fetchDocuments()
            let backendDocuments = response.documents.compactMap { MortgageDocument(from: $0) }
            // Merge: backend is source of truth, keep local-only docs that haven't been uploaded yet
            let localOnlyDocs = documents.filter { $0.serverDocumentId == nil }
            documents = backendDocuments + localOnlyDocs
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Couldn't load documents from server"
            // Keep existing local documents as fallback
        }
    }

    func refreshData() {
        Task {
            await fetchDocumentsFromBackend()
        }
    }

    // MARK: - Sample Data
    private func loadSampleData() {
        // Sample documents
        documents = [
            MortgageDocument(
                fileName: "January_2025_Statement.pdf",
                documentType: .mortgageStatement,
                uploadDate: Date(),
                originalText: "Sample mortgage statement text...",
                extractedData: nil,
                analysisResults: [],
                isAnalyzed: true
            ),
            MortgageDocument(
                fileName: "Escrow_Statement_2024.pdf",
                documentType: .escrowStatement,
                uploadDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                originalText: "Sample escrow statement text...",
                extractedData: nil,
                analysisResults: [],
                isAnalyzed: false
            ),
            MortgageDocument(
                fileName: "Payment_History_2024.pdf",
                documentType: .paymentHistory,
                uploadDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
                originalText: "Sample payment history text...",
                extractedData: nil,
                analysisResults: [],
                isAnalyzed: true
            )
        ]

        // Sample audit results
        auditResults = [
            AuditResult.sampleResult(),
            AuditResult(
                issueType: .unauthorizedFee,
                severity: .critical,
                title: "Unauthorized Late Fee",
                description: "Late fee charged without proper notice",
                detailedExplanation: "A $35 late fee was charged on your account without the required 15-day grace period notice as mandated by your loan agreement.",
                suggestedAction: "File a formal complaint and request immediate reversal of the fee",
                affectedAmount: 35.00,
                detectionMethod: .aiAnalysis,
                confidence: 0.92,
                evidenceText: "Late fee charged 01/16/2025 for payment due 01/01/2025",
                calculationDetails: nil,
                createdDate: Date()
            ),
            AuditResult(
                issueType: .escrowError,
                severity: .medium,
                title: "Escrow Shortage Calculation Error",
                description: "Potential error in escrow shortage calculation",
                detailedExplanation: "The escrow analysis shows a shortage of $450, but based on actual tax and insurance payments, the shortage should be approximately $280.",
                suggestedAction: "Request detailed escrow analysis and recalculation",
                affectedAmount: 170.00,
                detectionMethod: .manualCalculation,
                confidence: 0.87,
                evidenceText: "Escrow shortage: $450 vs calculated $280",
                calculationDetails: nil,
                createdDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
            )
        ]

        // Sample transactions
        transactions = [
            Transaction.sampleMortgagePayment(),
            Transaction.samplePropertyTax(),
            Transaction(
                accountId: "account_123",
                transactionId: "txn_890",
                amount: -850.00,
                date: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
                description: "HOME INSURANCE ANNUAL PREMIUM",
                category: .homeInsurance,
                isRecurring: false,
                merchantName: "State Farm Insurance",
                confidence: 0.94,
                plaidTransactionId: "plaid_txn_112",
                isVerified: true,
                relatedMortgagePayment: false
            )
        ]

        // Sample Plaid account
        if user.isPlaidConnected {
            plaidAccounts = [
                PlaidAccount(
                    accountId: "account_123",
                    accountName: "Wells Fargo Checking",
                    accountType: "depository",
                    accountSubtype: "checking",
                    institutionName: "Wells Fargo",
                    mask: "1234",
                    isConnected: true,
                    lastSyncDate: Date(),
                    accessToken: "access_token_sample"
                )
            ]
        }
    }
}