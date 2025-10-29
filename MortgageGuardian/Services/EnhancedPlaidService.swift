import Foundation
import Combine
import os.log

/// Enhanced Plaid Service with microservices integration
/// Provides end-to-end banking integration for mortgage auditing
@MainActor
public final class EnhancedPlaidService: ObservableObject {

    // MARK: - Types

    public enum PlaidServiceError: LocalizedError {
        case notLinked
        case syncInProgress
        case invalidAccount
        case networkError(Error)
        case crossReferenceFailure(String)
        case auditIntegrationFailure(String)

        public var errorDescription: String? {
            switch self {
            case .notLinked:
                return "Bank account not linked. Please connect your account first."
            case .syncInProgress:
                return "Sync already in progress. Please wait for completion."
            case .invalidAccount:
                return "Invalid or unsupported account type."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .crossReferenceFailure(let reason):
                return "Cross-reference failed: \(reason)"
            case .auditIntegrationFailure(let reason):
                return "Audit integration failed: \(reason)"
            }
        }
    }

    public struct EnhancedSyncResult {
        let syncedTransactions: Int
        let mortgagePayments: Int
        let auditMatches: Int
        let crossReferenceResults: CrossReferenceResults
        let timestamp: Date
    }

    public struct CrossReferenceResults {
        let matches: [PaymentAuditMatch]
        let discrepancies: [PaymentDiscrepancy]
        let matchRate: Double
    }

    public struct PaymentAuditMatch {
        let paymentId: String
        let auditId: String
        let matchConfidence: Double
        let matchDate: Date
    }

    public struct PaymentDiscrepancy {
        let paymentId: String
        let discrepancyType: String
        let description: String
        let suggestedAction: String
    }

    // MARK: - Published Properties

    @Published public var isLinked: Bool = false
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncDate: Date?
    @Published public var linkedAccountInfo: LinkedAccountInfo?
    @Published public var syncProgress: SyncProgress?
    @Published public var lastSyncResult: EnhancedSyncResult?

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "MortgageGuardian", category: "EnhancedPlaidService")
    private let apiClient = AWSBackendClient.shared
    private let securityService = SecurityService.shared
    private let notificationService = NotificationService.shared

    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?

    // MARK: - Initialization

    public init() {
        setupPeriodicSync()
        loadStoredLinkStatus()
    }

    // MARK: - Public Interface

    /// Enhanced account linking with validation
    public func linkAccountWithValidation(publicToken: String, metadata: [String: Any]) async throws -> LinkResult {
        logger.info("Starting enhanced account linking with validation")

        do {
            let requestBody: [String: Any] = [
                "public_token": publicToken,
                "metadata": metadata
            ]

            let response = try await apiClient.post(
                endpoint: "/v1/plaid/enhanced-link",
                body: requestBody
            )

            guard let data = response["data"] as? [String: Any],
                  let success = data["success"] as? Bool,
                  success else {
                throw PlaidServiceError.networkError(NSError(domain: "PlaidLinking", code: -1))
            }

            // Parse enhanced link result
            let linkResult = LinkResult(
                success: success,
                itemId: data["itemId"] as? String ?? "",
                institutionName: data["institutionName"] as? String ?? "",
                loanAccounts: parseLoanAccounts(data["loanAccounts"] as? [[String: Any]] ?? [])
            )

            // Update state
            self.isLinked = true
            self.linkedAccountInfo = LinkedAccountInfo(
                institutionName: linkResult.institutionName,
                itemId: linkResult.itemId,
                loanAccountCount: linkResult.loanAccounts.count,
                linkedDate: Date()
            )

            // Store encrypted link data
            try await securityService.storeSecurely(
                key: "plaid_link_data",
                data: linkResult
            )

            logger.info("Enhanced account linking completed successfully")
            return linkResult

        } catch {
            logger.error("Enhanced account linking failed: \(error.localizedDescription)")
            throw PlaidServiceError.networkError(error)
        }
    }

    /// Enhanced transaction sync with audit integration
    public func syncTransactionsWithAudit(accountId: String, dateRange: DateRange? = nil) async throws -> EnhancedSyncResult {
        guard isLinked else {
            throw PlaidServiceError.notLinked
        }

        guard !isSyncing else {
            throw PlaidServiceError.syncInProgress
        }

        logger.info("Starting enhanced transaction sync with audit integration")

        await MainActor.run {
            self.isSyncing = true
            self.syncProgress = SyncProgress(
                stage: .fetchingTransactions,
                progress: 0.0,
                message: "Fetching transactions from bank..."
            )
        }

        do {
            // Prepare sync request
            let range = dateRange ?? DateRange.last90Days()
            let requestBody: [String: Any] = [
                "account_id": accountId,
                "start_date": ISO8601DateFormatter().string(from: range.startDate),
                "end_date": ISO8601DateFormatter().string(from: range.endDate)
            ]

            // Update progress
            await updateSyncProgress(.processingTransactions, 0.3, "Processing transactions for audit...")

            // Execute enhanced sync
            let response = try await apiClient.post(
                endpoint: "/v1/plaid/enhanced-sync",
                body: requestBody
            )

            await updateSyncProgress(.crossReferencing, 0.6, "Cross-referencing with audit data...")

            // Parse enhanced sync result
            guard let data = response["data"] as? [String: Any] else {
                throw PlaidServiceError.networkError(NSError(domain: "SyncParsing", code: -1))
            }

            let enhancedResult = try parseEnhancedSyncResult(data)

            await updateSyncProgress(.integrating, 0.9, "Integrating with local audit data...")

            // Integrate with local audit engine and store locally
            try await integrateWithLocalAudit(enhancedResult)

            // Store sync result locally for offline access
            try await storeSyncResultLocally(enhancedResult)

            await updateSyncProgress(.completed, 1.0, "Sync completed successfully")

            // Update state
            await MainActor.run {
                self.lastSyncDate = Date()
                self.lastSyncResult = enhancedResult
                self.isSyncing = false
                self.syncProgress = nil
            }

            // Send comprehensive notification with discrepancy alerts
            await sendEnhancedNotification(for: enhancedResult)

            logger.info("Enhanced transaction sync completed successfully")
            return enhancedResult

        } catch {
            await MainActor.run {
                self.isSyncing = false
                self.syncProgress = nil
            }

            // Store error for retry mechanism
            await storeLastSyncError(error)

            logger.error("Enhanced transaction sync failed: \(error.localizedDescription)")
            throw PlaidServiceError.networkError(error)
        }
    }

    /// Get cross-reference analysis for existing audit
    public func getCrossReferenceAnalysis(auditId: String) async throws -> CrossReferenceResults {
        guard isLinked else {
            throw PlaidServiceError.notLinked
        }

        logger.info("Getting cross-reference analysis for audit: \(auditId)")

        do {
            let response = try await apiClient.get(
                endpoint: "/v1/plaid/cross-reference/\(auditId)"
            )

            guard let data = response["data"] as? [String: Any] else {
                throw PlaidServiceError.crossReferenceFailure("Invalid response format")
            }

            return try parseCrossReferenceResults(data)

        } catch {
            logger.error("Cross-reference analysis failed: \(error.localizedDescription)")
            throw PlaidServiceError.crossReferenceFailure(error.localizedDescription)
        }
    }

    /// Trigger audit workflow with banking integration
    public func triggerAuditWithBankingIntegration(documentId: String) async throws -> String {
        guard isLinked else {
            throw PlaidServiceError.notLinked
        }

        logger.info("Triggering audit workflow with banking integration")

        do {
            let requestBody: [String: Any] = [
                "documentId": documentId,
                "userId": getCurrentUserId(),
                "includeBankingCrossReference": true,
                "enhancedPlaidIntegration": true
            ]

            let response = try await apiClient.post(
                endpoint: "/v1/audit/start",
                body: requestBody
            )

            guard let executionId = response["executionId"] as? String else {
                throw PlaidServiceError.auditIntegrationFailure("No execution ID returned")
            }

            logger.info("Audit workflow started with execution ID: \(executionId)")
            return executionId

        } catch {
            logger.error("Audit workflow trigger failed: \(error.localizedDescription)")
            throw PlaidServiceError.auditIntegrationFailure(error.localizedDescription)
        }
    }

    /// Unlink account and cleanup
    public func unlinkAccount() async throws {
        logger.info("Unlinking Plaid account")

        do {
            // Call backend to unlink
            _ = try await apiClient.post(
                endpoint: "/v1/plaid/unlink",
                body: [:]
            )

            // Clear local state
            await MainActor.run {
                self.isLinked = false
                self.linkedAccountInfo = nil
                self.lastSyncDate = nil
                self.lastSyncResult = nil
            }

            // Clear stored data
            try await securityService.deleteSecurely(key: "plaid_link_data")

            logger.info("Account unlinked successfully")

        } catch {
            logger.error("Account unlinking failed: \(error.localizedDescription)")
            throw PlaidServiceError.networkError(error)
        }
    }

    // MARK: - Private Methods

    private func setupPeriodicSync() {
        // Setup automatic sync every 24 hours if linked
        syncTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self,
                      self.isLinked,
                      !self.isSyncing,
                      let accountInfo = self.linkedAccountInfo else {
                    return
                }

                // Auto-sync primary mortgage account
                do {
                    _ = try await self.syncTransactionsWithAudit(
                        accountId: accountInfo.primaryLoanAccountId ?? ""
                    )
                } catch {
                    self.logger.error("Automatic sync failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func loadStoredLinkStatus() {
        Task {
            do {
                let linkData: LinkResult? = try await securityService.retrieveSecurely(
                    key: "plaid_link_data",
                    type: LinkResult.self
                )

                if let linkData = linkData {
                    await MainActor.run {
                        self.isLinked = true
                        self.linkedAccountInfo = LinkedAccountInfo(
                            institutionName: linkData.institutionName,
                            itemId: linkData.itemId,
                            loanAccountCount: linkData.loanAccounts.count,
                            linkedDate: Date() // Would store actual date in production
                        )
                    }
                }
            } catch {
                logger.warning("Could not load stored link status: \(error.localizedDescription)")
            }
        }
    }

    private func updateSyncProgress(_ stage: SyncProgress.Stage, _ progress: Double, _ message: String) async {
        await MainActor.run {
            self.syncProgress = SyncProgress(
                stage: stage,
                progress: progress,
                message: message
            )
        }
    }

    private func parseEnhancedSyncResult(_ data: [String: Any]) throws -> EnhancedSyncResult {
        guard let syncedTransactions = data["syncedTransactions"] as? Int,
              let mortgagePayments = data["mortgagePayments"] as? Int,
              let crossRefData = data["auditCrossReference"] as? [String: Any] else {
            throw PlaidServiceError.networkError(NSError(domain: "ParseError", code: -1))
        }

        let crossReference = try parseCrossReferenceResults(crossRefData)

        return EnhancedSyncResult(
            syncedTransactions: syncedTransactions,
            mortgagePayments: mortgagePayments,
            auditMatches: crossReference.matches.count,
            crossReferenceResults: crossReference,
            timestamp: Date()
        )
    }

    private func parseCrossReferenceResults(_ data: [String: Any]) throws -> CrossReferenceResults {
        let matches = (data["matches"] as? [[String: Any]] ?? []).compactMap { matchData in
            guard let paymentId = matchData["paymentId"] as? String,
                  let auditId = matchData["auditId"] as? String else {
                return nil
            }

            return PaymentAuditMatch(
                paymentId: paymentId,
                auditId: auditId,
                matchConfidence: matchData["confidence"] as? Double ?? 0.0,
                matchDate: Date()
            )
        }

        let discrepancies = (data["discrepancies"] as? [[String: Any]] ?? []).compactMap { discData in
            guard let paymentId = discData["paymentId"] as? String,
                  let type = discData["type"] as? String,
                  let description = discData["description"] as? String else {
                return nil
            }

            return PaymentDiscrepancy(
                paymentId: paymentId,
                discrepancyType: type,
                description: description,
                suggestedAction: discData["suggestedAction"] as? String ?? ""
            )
        }

        let matchRate = data["matchRate"] as? Double ?? 0.0

        return CrossReferenceResults(
            matches: matches,
            discrepancies: discrepancies,
            matchRate: matchRate
        )
    }

    private func parseLoanAccounts(_ accountsData: [[String: Any]]) -> [LoanAccount] {
        return accountsData.compactMap { accountData in
            guard let accountId = accountData["accountId"] as? String,
                  let name = accountData["name"] as? String else {
                return nil
            }

            return LoanAccount(
                accountId: accountId,
                name: name,
                type: accountData["type"] as? String ?? "",
                subtype: accountData["subtype"] as? String ?? "",
                mask: accountData["mask"] as? String ?? ""
            )
        }
    }

    private func integrateWithLocalAudit(_ syncResult: EnhancedSyncResult) async throws {
        // Integration with local audit engine would go here
        // This would update local SwiftData with cross-reference results
        logger.info("Integrating sync results with local audit data")

        // Store mortgage payments locally for audit cross-reference
        let mortgageTransactions = syncResult.crossReferenceResults.matches
        for match in mortgageTransactions {
            // Would integrate with SwiftData here in production
            logger.debug("Processing audit match: \(match.paymentId)")
        }
    }

    private func storeSyncResultLocally(_ syncResult: EnhancedSyncResult) async throws {
        // Store sync result for offline access
        do {
            let data = try JSONEncoder().encode(syncResult)
            try await securityService.storeSecurely(
                key: "last_sync_result",
                data: data
            )
            logger.info("Stored sync result locally for offline access")
        } catch {
            logger.error("Failed to store sync result locally: \(error.localizedDescription)")
            throw error
        }
    }

    private func sendEnhancedNotification(for syncResult: EnhancedSyncResult) async {
        let discrepancyCount = syncResult.crossReferenceResults.discrepancies.count

        if discrepancyCount > 0 {
            // Alert user to discrepancies found
            await notificationService.sendLocalNotification(
                title: "Audit Discrepancies Found",
                body: "Found \(discrepancyCount) potential issues in your mortgage payments. Review required."
            )
        } else {
            // Normal sync completion
            await notificationService.sendLocalNotification(
                title: "Bank Sync Complete",
                body: "Synced \(syncResult.syncedTransactions) transactions with \(syncResult.auditMatches) audit matches"
            )
        }
    }

    private func storeLastSyncError(_ error: Error) async {
        let errorData = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "error": error.localizedDescription,
            "retryable": true
        ]

        UserDefaults.standard.set(errorData, forKey: "last_sync_error")
        logger.error("Stored sync error for retry: \(error.localizedDescription)")
    }

    private func getCurrentUserId() -> String {
        // Get current user ID from authentication service
        return UserDefaults.standard.string(forKey: "current_user_id") ?? ""
    }
}

// MARK: - Supporting Types

public struct LinkedAccountInfo {
    let institutionName: String
    let itemId: String
    let loanAccountCount: Int
    let linkedDate: Date
    let primaryLoanAccountId: String?

    init(institutionName: String, itemId: String, loanAccountCount: Int, linkedDate: Date, primaryLoanAccountId: String? = nil) {
        self.institutionName = institutionName
        self.itemId = itemId
        self.loanAccountCount = loanAccountCount
        self.linkedDate = linkedDate
        self.primaryLoanAccountId = primaryLoanAccountId
    }
}

public struct LinkResult: Codable {
    let success: Bool
    let itemId: String
    let institutionName: String
    let loanAccounts: [LoanAccount]
}

public struct LoanAccount: Codable {
    let accountId: String
    let name: String
    let type: String
    let subtype: String
    let mask: String
}

public struct SyncProgress {
    enum Stage {
        case fetchingTransactions
        case processingTransactions
        case crossReferencing
        case integrating
        case completed
    }

    let stage: Stage
    let progress: Double // 0.0 to 1.0
    let message: String
}

public struct DateRange {
    let startDate: Date
    let endDate: Date

    static func last90Days() -> DateRange {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate
        return DateRange(startDate: startDate, endDate: endDate)
    }
}

// MARK: - Notification Service Integration

private class NotificationService {
    static let shared = NotificationService()

    func sendLocalNotification(title: String, body: String) async {
        // Implementation would use UNUserNotificationCenter
        print("Notification: \(title) - \(body)")
    }
}