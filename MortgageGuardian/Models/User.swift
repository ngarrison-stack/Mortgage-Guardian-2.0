import Foundation
import CryptoKit

struct User: Identifiable, Codable {
    let id = UUID()
    var firstName: String
    var lastName: String
    var email: String
    var address: UserAddress?
    var phoneNumber: String?
    var mortgageAccounts: [MortgageAccount]
    var plaidAccessToken: String?
    var isPlaidConnected: Bool
    var securitySettings: SecuritySettings
    var preferences: UserPreferences
    var createdDate: Date
    var lastLoginDate: Date?

    var fullName: String {
        "\(firstName) \(lastName)"
    }

    struct UserAddress: Codable {
        var street: String
        var city: String
        var state: String
        var zipCode: String

        var fullAddress: String {
            "\(street), \(city), \(state) \(zipCode)"
        }
    }

    struct MortgageAccount: Identifiable, Codable {
        let id = UUID()
        var loanNumber: String
        var servicerName: String
        var servicerAddress: String?
        var propertyAddress: String
        var originalLoanAmount: Double
        var currentBalance: Double?
        var interestRate: Double
        var loanTerm: Int
        var monthlyPayment: Double
        var escrowAccount: Bool
        var documents: [UUID]
        var isActive: Bool
        var addedDate: Date

        var displayName: String {
            "\(servicerName) - \(loanNumber)"
        }
    }

    struct SecuritySettings: Codable {
        var biometricAuthEnabled: Bool
        var autoLockEnabled: Bool
        var autoLockTimeout: TimeInterval
        var requireAuthForExport: Bool
        var secureDocumentStorage: Bool

        static var `default`: SecuritySettings {
            SecuritySettings(
                biometricAuthEnabled: true,
                autoLockEnabled: true,
                autoLockTimeout: 300,
                requireAuthForExport: true,
                secureDocumentStorage: true
            )
        }
    }

    struct UserPreferences: Codable {
        var notificationsEnabled: Bool
        var analysisNotifications: Bool
        var monthlyReports: Bool
        var theme: AppTheme
        var documentRetentionDays: Int

        enum AppTheme: String, CaseIterable, Codable {
            case light = "light"
            case dark = "dark"
            case system = "system"

            var displayName: String {
                switch self {
                case .light:
                    return "Light"
                case .dark:
                    return "Dark"
                case .system:
                    return "System"
                }
            }
        }

        static var `default`: UserPreferences {
            UserPreferences(
                notificationsEnabled: true,
                analysisNotifications: true,
                monthlyReports: false,
                theme: .system,
                documentRetentionDays: 365
            )
        }
    }

    static var sampleUser: User {
        User(
            firstName: "John",
            lastName: "Doe",
            email: "john.doe@example.com",
            address: UserAddress(
                street: "123 Main St",
                city: "Anytown",
                state: "CA",
                zipCode: "12345"
            ),
            phoneNumber: "+1-555-123-4567",
            mortgageAccounts: [
                MortgageAccount(
                    loanNumber: "1234567890",
                    servicerName: "ABC Mortgage",
                    servicerAddress: "456 Oak Ave, Servicer City, ST 67890",
                    propertyAddress: "123 Main St, Anytown, CA 12345",
                    originalLoanAmount: 350000.00,
                    currentBalance: 325000.00,
                    interestRate: 0.0375,
                    loanTerm: 30,
                    monthlyPayment: 1750.00,
                    escrowAccount: true,
                    documents: [],
                    isActive: true,
                    addedDate: Date()
                )
            ],
            plaidAccessToken: nil,
            isPlaidConnected: false,
            securitySettings: SecuritySettings.default,
            preferences: UserPreferences.default,
            createdDate: Date(),
            lastLoginDate: Date()
        )
    }
}