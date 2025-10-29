import Foundation

public struct PlaidAccount: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let type: String
    public let subtype: String
    public let mask: String
    public let institutionName: String
    public var balance: Double?
    public var isActive: Bool
    public let dateConnected: Date

    public init(
        id: String,
        name: String,
        type: String,
        subtype: String,
        mask: String,
        institutionName: String,
        balance: Double? = nil,
        isActive: Bool = true,
        dateConnected: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.subtype = subtype
        self.mask = mask
        self.institutionName = institutionName
        self.balance = balance
        self.isActive = isActive
        self.dateConnected = dateConnected
    }

    public var displayName: String {
        return "\(name) •••• \(mask)"
    }

    public var accountTypeDescription: String {
        switch (type, subtype) {
        case ("depository", "checking"):
            return "Checking Account"
        case ("depository", "savings"):
            return "Savings Account"
        case ("credit", "credit card"):
            return "Credit Card"
        case ("loan", "mortgage"):
            return "Mortgage"
        case ("loan", "home equity"):
            return "Home Equity Loan"
        default:
            return subtype.capitalized
        }
    }

    public var icon: String {
        switch type {
        case "depository":
            return "building.columns.fill"
        case "credit":
            return "creditcard.fill"
        case "loan":
            return "house.fill"
        default:
            return "banknote.fill"
        }
    }

    // MARK: - Hashable & Equatable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: PlaidAccount, rhs: PlaidAccount) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Sample Data
extension PlaidAccount {
    public static let sampleAccounts: [PlaidAccount] = [
        PlaidAccount(
            id: "sample_checking_001",
            name: "Primary Checking",
            type: "depository",
            subtype: "checking",
            mask: "1234",
            institutionName: "Chase Bank",
            balance: 4250.75
        ),
        PlaidAccount(
            id: "sample_savings_001",
            name: "Savings Account",
            type: "depository",
            subtype: "savings",
            mask: "5678",
            institutionName: "Chase Bank",
            balance: 18750.50
        ),
        PlaidAccount(
            id: "sample_mortgage_001",
            name: "Home Mortgage",
            type: "loan",
            subtype: "mortgage",
            mask: "9012",
            institutionName: "Wells Fargo",
            balance: 245000.00
        )
    ]

    public static var sampleChecking: PlaidAccount {
        return sampleAccounts[0]
    }

    public static var sampleSavings: PlaidAccount {
        return sampleAccounts[1]
    }

    public static var sampleMortgage: PlaidAccount {
        return sampleAccounts[2]
    }
}