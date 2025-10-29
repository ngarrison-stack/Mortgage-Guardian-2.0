import Foundation
import Combine

/// Simplified Plaid service for demo purposes
/// This replaces the complex PlaidService when LinkKit is not available
@MainActor
public final class PlaidService: ObservableObject {

    // MARK: - Shared Instance
    public static let shared = PlaidService()

    // MARK: - Published Properties
    @Published public var accounts: [PlaidAccount] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.mortgageguardian", category: "PlaidService")

    private init() {
        // Initialize with empty state
        logger.info("SimplePlaidService initialized")
    }

    // MARK: - Public Methods

    /// Add an account to the connected accounts
    public func addAccount(_ account: PlaidAccount) {
        if !accounts.contains(where: { $0.id == account.id }) {
            accounts.append(account)
            logger.info("Added account: \(account.name)")
        }
    }

    /// Remove an account from connected accounts
    public func removeAccount(_ account: PlaidAccount) {
        accounts.removeAll { $0.id == account.id }
        logger.info("Removed account: \(account.name)")
    }

    /// Connect a new bank account (simulated)
    public func connectAccount() async throws {
        isLoading = true
        errorMessage = nil

        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            // Create a mock account
            let newAccount = PlaidAccount(
                id: "account_\(UUID().uuidString.prefix(8))",
                name: "Primary Checking",
                type: "depository",
                subtype: "checking",
                mask: String(Int.random(in: 1000...9999)),
                institutionName: ["Chase Bank", "Bank of America", "Wells Fargo", "Citi Bank"].randomElement()!,
                balance: Double.random(in: 1000...50000),
                isActive: true
            )

            addAccount(newAccount)

        } catch {
            errorMessage = error.localizedDescription
            throw error
        } finally {
            isLoading = false
        }
    }

    /// Disconnect an account
    public func disconnectAccount(_ account: PlaidAccount) async throws {
        isLoading = true

        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        removeAccount(account)
        isLoading = false
    }

    /// Refresh account data
    public func refreshAccounts() async throws {
        isLoading = true

        // Simulate refresh
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Update balances randomly
        for i in accounts.indices {
            accounts[i].balance = accounts[i].balance.map { $0 + Double.random(in: -100...100) }
        }

        isLoading = false
    }

    /// Check if any accounts are connected
    public var hasConnectedAccounts: Bool {
        return !accounts.isEmpty
    }

    /// Get account count for display
    public var accountCount: Int {
        return accounts.count
    }
}

// MARK: - Logger Import
import os.log

extension Logger {
    convenience init(subsystem: String, category: String) {
        self.init(OSLog(subsystem: subsystem, category: category))
    }
}