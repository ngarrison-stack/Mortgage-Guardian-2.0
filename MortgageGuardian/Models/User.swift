import Foundation
import SwiftUI
import CryptoKit

@MainActor
class User: Identifiable, Codable, ObservableObject {
    let id = UUID()
    @Published var firstName: String
    @Published var lastName: String
    @Published var email: String
    @Published var address: UserAddress?
    @Published var phoneNumber: String?
    @Published var mortgageAccounts: [MortgageAccount]
    @Published var plaidAccessToken: String?
    @Published var isPlaidConnected: Bool
    @Published var securitySettings: SecuritySettings
    @Published var preferences: UserPreferences
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
        var loanOriginationDate: Date
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

    init(
        firstName: String,
        lastName: String,
        email: String,
        address: UserAddress? = nil,
        phoneNumber: String? = nil,
        mortgageAccounts: [MortgageAccount] = [],
        plaidAccessToken: String? = nil,
        isPlaidConnected: Bool = false,
        securitySettings: SecuritySettings = .default,
        preferences: UserPreferences = .default,
        createdDate: Date = Date(),
        lastLoginDate: Date? = nil
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.address = address
        self.phoneNumber = phoneNumber
        self.mortgageAccounts = mortgageAccounts
        self.plaidAccessToken = plaidAccessToken
        self.isPlaidConnected = isPlaidConnected
        self.securitySettings = securitySettings
        self.preferences = preferences
        self.createdDate = createdDate
        self.lastLoginDate = lastLoginDate
    }

    // MARK: - Codable Implementation
    private enum CodingKeys: String, CodingKey {
        case id, firstName, lastName, email, address, phoneNumber
        case mortgageAccounts, plaidAccessToken, isPlaidConnected
        case securitySettings, preferences, createdDate, lastLoginDate
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.firstName = try container.decode(String.self, forKey: .firstName)
        self.lastName = try container.decode(String.self, forKey: .lastName)
        self.email = try container.decode(String.self, forKey: .email)
        self.address = try container.decodeIfPresent(UserAddress.self, forKey: .address)
        self.phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        self.mortgageAccounts = try container.decode([MortgageAccount].self, forKey: .mortgageAccounts)
        self.plaidAccessToken = try container.decodeIfPresent(String.self, forKey: .plaidAccessToken)
        self.isPlaidConnected = try container.decode(Bool.self, forKey: .isPlaidConnected)
        self.securitySettings = try container.decode(SecuritySettings.self, forKey: .securitySettings)
        self.preferences = try container.decode(UserPreferences.self, forKey: .preferences)
        self.createdDate = try container.decode(Date.self, forKey: .createdDate)
        self.lastLoginDate = try container.decodeIfPresent(Date.self, forKey: .lastLoginDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encode(mortgageAccounts, forKey: .mortgageAccounts)
        try container.encodeIfPresent(plaidAccessToken, forKey: .plaidAccessToken)
        try container.encode(isPlaidConnected, forKey: .isPlaidConnected)
        try container.encode(securitySettings, forKey: .securitySettings)
        try container.encode(preferences, forKey: .preferences)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encodeIfPresent(lastLoginDate, forKey: .lastLoginDate)
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
                    loanOriginationDate: Date(),
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