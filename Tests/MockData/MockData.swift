import Foundation
import UIKit
import Combine
@testable import MortgageGuardian

/// Comprehensive mock data and objects for testing
/// Provides realistic test data for all model types and service interactions

// MARK: - Mock Users

public struct MockUsers {

    /// Standard test user with complete mortgage information
    public static let standardUser = User(
        id: UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!,
        email: "john.doe@example.com",
        fullName: "John Doe",
        phoneNumber: "+1-555-123-4567",
        address: Address(
            street: "123 Main Street",
            city: "Anytown",
            state: "CA",
            zipCode: "12345",
            country: "United States"
        ),
        mortgageAccounts: [MockMortgageAccounts.standardAccount],
        userProfile: User.UserProfile(
            preferredLanguage: "en",
            timezone: "America/Los_Angeles",
            notificationPreferences: User.NotificationPreferences(
                emailEnabled: true,
                pushEnabled: true,
                smsEnabled: false,
                analysisComplete: true,
                errorDetected: true,
                weeklyReports: true
            ),
            privacySettings: User.PrivacySettings(
                dataSharing: false,
                analytics: true,
                marketing: false
            )
        ),
        createdDate: Date.testDate(year: 2023, month: 1, day: 15),
        lastActiveDate: Date.testDate(year: 2024, month: 12, day: 1)
    )

    /// User with multiple mortgage accounts
    public static let multiAccountUser = User(
        id: UUID(uuidString: "87654321-4321-4321-4321-CBA987654321")!,
        email: "jane.smith@example.com",
        fullName: "Jane Smith",
        phoneNumber: "+1-555-987-6543",
        address: Address(
            street: "456 Oak Avenue",
            city: "Springfield",
            state: "IL",
            zipCode: "62701",
            country: "United States"
        ),
        mortgageAccounts: [
            MockMortgageAccounts.standardAccount,
            MockMortgageAccounts.highBalanceAccount,
            MockMortgageAccounts.newAccount
        ],
        userProfile: User.UserProfile(
            preferredLanguage: "en",
            timezone: "America/Chicago",
            notificationPreferences: User.NotificationPreferences(
                emailEnabled: true,
                pushEnabled: true,
                smsEnabled: true,
                analysisComplete: true,
                errorDetected: true,
                weeklyReports: false
            ),
            privacySettings: User.PrivacySettings(
                dataSharing: true,
                analytics: true,
                marketing: true
            )
        ),
        createdDate: Date.testDate(year: 2022, month: 6, day: 10),
        lastActiveDate: Date()
    )

    /// User with problematic account (for error testing)
    public static let problematicUser = User(
        id: UUID(uuidString: "PROBLEM1-PROB-PROB-PROB-PROBLEM12345")!,
        email: "problem.user@example.com",
        fullName: "Problem User",
        phoneNumber: "+1-555-000-0001",
        address: Address(
            street: "999 Error Lane",
            city: "Bugtown",
            state: "TX",
            zipCode: "00000",
            country: "United States"
        ),
        mortgageAccounts: [MockMortgageAccounts.problematicAccount],
        userProfile: User.UserProfile(
            preferredLanguage: "en",
            timezone: "America/Central",
            notificationPreferences: User.NotificationPreferences(
                emailEnabled: false,
                pushEnabled: false,
                smsEnabled: false,
                analysisComplete: false,
                errorDetected: true,
                weeklyReports: false
            ),
            privacySettings: User.PrivacySettings(
                dataSharing: false,
                analytics: false,
                marketing: false
            )
        ),
        createdDate: Date.testDate(year: 2024, month: 1, day: 1),
        lastActiveDate: Date.testDate(year: 2024, month: 1, day: 2)
    )
}

// MARK: - Mock Mortgage Accounts

public struct MockMortgageAccounts {

    /// Standard mortgage account with typical values
    public static let standardAccount = User.MortgageAccount(
        loanNumber: "LOAN123456789",
        servicerName: "Example Mortgage Corp",
        servicerAddress: "789 Financial Plaza, Suite 100, Money City, NY 10001",
        propertyAddress: "123 Main Street, Anytown, CA 12345",
        originalLoanAmount: 350000.00,
        currentBalance: 298750.50,
        interestRate: 0.0425, // 4.25%
        monthlyPayment: 1725.45,
        escrowAccount: true,
        escrowBalance: 2450.75,
        isActive: true,
        loanStartDate: Date.testDate(year: 2020, month: 3, day: 15),
        maturityDate: Date.testDate(year: 2050, month: 3, day: 15)
    )

    /// High balance mortgage account
    public static let highBalanceAccount = User.MortgageAccount(
        loanNumber: "LOAN987654321",
        servicerName: "Premium Lending Services",
        servicerAddress: "555 Executive Drive, Prestige City, CA 90210",
        propertyAddress: "789 Luxury Lane, Beverly Hills, CA 90210",
        originalLoanAmount: 850000.00,
        currentBalance: 745250.00,
        interestRate: 0.0375, // 3.75%
        monthlyPayment: 3925.80,
        escrowAccount: true,
        escrowBalance: 8750.00,
        isActive: true,
        loanStartDate: Date.testDate(year: 2021, month: 8, day: 1),
        maturityDate: Date.testDate(year: 2051, month: 8, day: 1)
    )

    /// Recently originated account
    public static let newAccount = User.MortgageAccount(
        loanNumber: "LOAN2024001",
        servicerName: "New Home Mortgage",
        servicerAddress: "123 Starter Street, New Town, FL 33101",
        propertyAddress: "456 First Home Drive, New Town, FL 33101",
        originalLoanAmount: 275000.00,
        currentBalance: 274125.50,
        interestRate: 0.0695, // 6.95%
        monthlyPayment: 1815.25,
        escrowAccount: true,
        escrowBalance: 1200.00,
        isActive: true,
        loanStartDate: Date.testDate(year: 2024, month: 10, day: 1),
        maturityDate: Date.testDate(year: 2054, month: 10, day: 1)
    )

    /// Account with issues (for error testing)
    public static let problematicAccount = User.MortgageAccount(
        loanNumber: "PROBLEM999",
        servicerName: "Problematic Servicing LLC",
        servicerAddress: "666 Error Street, Bug City, CA 90000",
        propertyAddress: "999 Error Lane, Bugtown, TX 00000",
        originalLoanAmount: 200000.00,
        currentBalance: 185000.00,
        interestRate: 0.1250, // Unusually high 12.5%
        monthlyPayment: 2250.00,
        escrowAccount: false,
        escrowBalance: nil,
        isActive: true,
        loanStartDate: Date.testDate(year: 2023, month: 12, month: 1),
        maturityDate: Date.testDate(year: 2053, month: 12, day: 1)
    )
}

// MARK: - Mock Documents

public struct MockDocuments {

    /// Standard mortgage statement
    public static let mortgageStatement = MortgageDocument(
        fileName: "mortgage_statement_202412.pdf",
        documentType: .mortgageStatement,
        uploadDate: Date.testDate(year: 2024, month: 12, day: 1),
        originalText: MockDocumentTexts.mortgageStatementText,
        extractedData: MockExtractedData.mortgageStatementData,
        analysisResults: [],
        isAnalyzed: false
    )

    /// Escrow statement with complex activity
    public static let escrowStatement = MortgageDocument(
        fileName: "escrow_analysis_2024.pdf",
        documentType: .escrowStatement,
        uploadDate: Date.testDate(year: 2024, month: 11, day: 15),
        originalText: MockDocumentTexts.escrowStatementText,
        extractedData: MockExtractedData.escrowStatementData,
        analysisResults: [],
        isAnalyzed: false
    )

    /// Payment history document
    public static let paymentHistory = MortgageDocument(
        fileName: "payment_history_2024.pdf",
        documentType: .paymentHistory,
        uploadDate: Date.testDate(year: 2024, month: 12, day: 5),
        originalText: MockDocumentTexts.paymentHistoryText,
        extractedData: MockExtractedData.paymentHistoryData,
        analysisResults: [],
        isAnalyzed: false
    )

    /// Document with processing errors
    public static let corruptedDocument = MortgageDocument(
        fileName: "corrupted_doc.pdf",
        documentType: .other,
        uploadDate: Date(),
        originalText: "����corrupted text���",
        extractedData: nil,
        analysisResults: [],
        isAnalyzed: false
    )

    /// Large document for performance testing
    public static let largeDocument = MortgageDocument(
        fileName: "large_statement.pdf",
        documentType: .mortgageStatement,
        uploadDate: Date(),
        originalText: String(repeating: MockDocumentTexts.mortgageStatementText, count: 100),
        extractedData: MockExtractedData.mortgageStatementData,
        analysisResults: [],
        isAnalyzed: false
    )
}

// MARK: - Mock Document Texts

public struct MockDocumentTexts {

    public static let mortgageStatementText = """
    MORTGAGE STATEMENT
    Statement Date: December 1, 2024

    Borrower: John Doe
    Property Address: 123 Main Street, Anytown, CA 12345
    Loan Number: LOAN123456789
    Servicer: Example Mortgage Corp

    PAYMENT INFORMATION
    Monthly Payment Due: $1,725.45
    Due Date: January 1, 2025
    Principal & Interest: $1,475.20
    Escrow: $250.25

    LOAN BALANCE INFORMATION
    Principal Balance: $298,750.50
    Interest Rate: 4.250%
    Original Loan Amount: $350,000.00

    ESCROW ACCOUNT
    Current Escrow Balance: $2,450.75
    Property Tax: $1,200.00 (paid 11/15/2024)
    Homeowner Insurance: $890.00 (paid 10/30/2024)

    PAYMENT ACTIVITY
    11/01/2024 - Payment Received: $1,725.45
    Principal Applied: $485.25
    Interest Applied: $989.95
    Escrow Applied: $250.25
    """

    public static let escrowStatementText = """
    ESCROW ANALYSIS STATEMENT
    Analysis Date: November 15, 2024
    Account Number: LOAN123456789

    ANNUAL ESCROW ANALYSIS
    Property Tax Annual: $4,800.00
    Homeowner Insurance Annual: $3,560.00
    Total Annual Escrow: $8,360.00
    Monthly Escrow Payment: $696.67

    ESCROW ACTIVITY - LAST 12 MONTHS
    12/15/2023 - Property Tax Payment: $1,200.00
    01/30/2024 - Insurance Payment: $890.00
    03/15/2024 - Property Tax Payment: $1,200.00
    04/30/2024 - Insurance Payment: $890.00
    06/15/2024 - Property Tax Payment: $1,200.00
    07/30/2024 - Insurance Payment: $890.00
    09/15/2024 - Property Tax Payment: $1,200.00
    10/30/2024 - Insurance Payment: $890.00

    PROJECTED ESCROW SHORTAGE: $125.50
    Required by: March 1, 2025
    """

    public static let paymentHistoryText = """
    PAYMENT HISTORY
    Account: LOAN123456789
    Period: January 2024 - December 2024

    DATE        AMOUNT      PRINCIPAL   INTEREST    ESCROW     LATE FEE    DAYS LATE
    01/01/2024  $1,725.45   $465.20     $1,010.00   $250.25    $0.00       0
    02/01/2024  $1,725.45   $467.85     $1,007.35   $250.25    $0.00       0
    03/01/2024  $1,725.45   $470.52     $1,004.68   $250.25    $0.00       0
    04/01/2024  $1,725.45   $473.21     $1,001.99   $250.25    $0.00       0
    05/05/2024  $1,750.45   $475.92     $999.28     $250.25    $25.00      4 days late
    06/01/2024  $1,725.45   $478.65     $996.55     $250.25    $0.00       0
    07/01/2024  $1,725.45   $481.40     $993.80     $250.25    $0.00       0
    08/01/2024  $1,725.45   $484.17     $991.03     $250.25    $0.00       0
    09/01/2024  $1,725.45   $486.96     $988.24     $250.25    $0.00       0
    10/01/2024  $1,725.45   $489.77     $985.43     $250.25    $0.00       0
    11/01/2024  $1,725.45   $492.60     $982.60     $250.25    $0.00       0
    12/01/2024  $1,725.45   $495.45     $979.75     $250.25    $0.00       0

    SUMMARY
    Total Payments: $20,730.40
    Total Principal: $5,756.70
    Total Interest: $11,923.45
    Total Escrow: $3,003.00
    Total Late Fees: $25.00
    """
}

// MARK: - Mock Extracted Data

public struct MockExtractedData {

    public static let mortgageStatementData = ExtractedData(
        loanNumber: "LOAN123456789",
        servicerName: "Example Mortgage Corp",
        borrowerName: "John Doe",
        propertyAddress: "123 Main Street, Anytown, CA 12345",
        principalBalance: 298750.50,
        interestRate: 0.0425,
        monthlyPayment: 1725.45,
        escrowBalance: 2450.75,
        dueDate: Date.testDate(year: 2025, month: 1, day: 1),
        paymentHistory: [
            ExtractedData.PaymentRecord(
                paymentDate: Date.testDate(year: 2024, month: 11, day: 1),
                amount: 1725.45,
                principalApplied: 485.25,
                interestApplied: 989.95,
                escrowApplied: 250.25,
                lateFeesApplied: nil,
                isLate: false,
                dayslate: nil
            )
        ],
        escrowActivity: [
            ExtractedData.EscrowTransaction(
                date: Date.testDate(year: 2024, month: 11, day: 15),
                description: "Property Tax Payment",
                amount: 1200.00,
                type: .withdrawal,
                category: .propertyTax
            ),
            ExtractedData.EscrowTransaction(
                date: Date.testDate(year: 2024, month: 10, day: 30),
                description: "Homeowner Insurance Payment",
                amount: 890.00,
                type: .withdrawal,
                category: .homeownerInsurance
            )
        ],
        fees: []
    )

    public static let escrowStatementData = ExtractedData(
        loanNumber: "LOAN123456789",
        servicerName: "Example Mortgage Corp",
        borrowerName: "John Doe",
        propertyAddress: "123 Main Street, Anytown, CA 12345",
        principalBalance: nil,
        interestRate: nil,
        monthlyPayment: nil,
        escrowBalance: 2450.75,
        dueDate: nil,
        paymentHistory: [],
        escrowActivity: [
            ExtractedData.EscrowTransaction(
                date: Date.testDate(year: 2023, month: 12, day: 15),
                description: "Property Tax Payment",
                amount: 1200.00,
                type: .withdrawal,
                category: .propertyTax
            ),
            ExtractedData.EscrowTransaction(
                date: Date.testDate(year: 2024, month: 1, day: 30),
                description: "Insurance Payment",
                amount: 890.00,
                type: .withdrawal,
                category: .homeownerInsurance
            )
        ],
        fees: []
    )

    public static let paymentHistoryData = ExtractedData(
        loanNumber: "LOAN123456789",
        servicerName: "Example Mortgage Corp",
        borrowerName: "John Doe",
        propertyAddress: "123 Main Street, Anytown, CA 12345",
        principalBalance: nil,
        interestRate: nil,
        monthlyPayment: nil,
        escrowBalance: nil,
        dueDate: nil,
        paymentHistory: [
            ExtractedData.PaymentRecord(
                paymentDate: Date.testDate(year: 2024, month: 5, day: 5),
                amount: 1750.45,
                principalApplied: 475.92,
                interestApplied: 999.28,
                escrowApplied: 250.25,
                lateFeesApplied: 25.00,
                isLate: true,
                dayslate: 4
            ),
            ExtractedData.PaymentRecord(
                paymentDate: Date.testDate(year: 2024, month: 6, day: 1),
                amount: 1725.45,
                principalApplied: 478.65,
                interestApplied: 996.55,
                escrowApplied: 250.25,
                lateFeesApplied: nil,
                isLate: false,
                dayslate: nil
            )
        ],
        escrowActivity: [],
        fees: [
            ExtractedData.Fee(
                date: Date.testDate(year: 2024, month: 5, day: 5),
                description: "Late Fee",
                amount: 25.00,
                category: .lateFee
            )
        ]
    )
}

// MARK: - Mock Audit Results

public struct MockAuditResults {

    public static let latePaymentError = AuditResult(
        issueType: .latePaymentError,
        severity: .high,
        title: "Incorrect Late Fee Charged",
        description: "A late fee was charged despite payment being received on time",
        detailedExplanation: "Payment due 01/01/2025 was received 01/05/2025, but your bank records show the payment was actually sent on 12/30/2024. The servicer incorrectly applied a $25 late fee.",
        suggestedAction: "Send a Notice of Error letter requesting removal of the late fee and correction of payment application date",
        affectedAmount: 25.00,
        detectionMethod: .plaidVerification,
        confidence: 0.95,
        evidenceText: "Payment due 01/01/2025 was received 01/05/2025, late fee charged",
        calculationDetails: AuditResult.CalculationDetails(
            expectedValue: 0.00,
            actualValue: 25.00,
            difference: 25.00,
            formula: "Late fee should be $0 when payment sent before due date",
            assumptions: ["Grace period of 15 days", "Payment sent 2 days before due date"],
            warningFlags: ["Payment application delay", "Potential RESPA violation"]
        ),
        createdDate: Date()
    )

    public static let misappliedPayment = AuditResult(
        issueType: .misappliedPayment,
        severity: .medium,
        title: "Payment Applied to Wrong Account",
        description: "Monthly payment was applied to principal instead of interest and escrow",
        detailedExplanation: "The October payment of $1,725.45 was entirely applied to principal, leaving interest and escrow unpaid. This resulted in additional interest charges and escrow shortage.",
        suggestedAction: "Contact servicer to correct payment application and reverse additional charges",
        affectedAmount: 275.50,
        detectionMethod: .manualCalculation,
        confidence: 0.88,
        evidenceText: "October payment: Principal $1,725.45, Interest $0.00, Escrow $0.00",
        calculationDetails: AuditResult.CalculationDetails(
            expectedValue: 1725.45,
            actualValue: 1725.45,
            difference: 0.00,
            formula: "Payment = Principal + Interest + Escrow",
            assumptions: ["Normal payment allocation", "No prepayment intention"],
            warningFlags: ["Unusual allocation pattern", "System error possible"]
        ),
        createdDate: Date()
    )

    public static let incorrectInterest = AuditResult(
        issueType: .incorrectInterest,
        severity: .critical,
        title: "Interest Rate Calculation Error",
        description: "Monthly interest charge exceeds the contracted rate",
        detailedExplanation: "Based on the current principal balance of $298,750.50 and contracted rate of 4.25%, the monthly interest should be $1,057.64. However, $1,089.95 was charged, representing an effective rate of 4.37%.",
        suggestedAction: "File a formal complaint for overcharge and demand refund of excess interest",
        affectedAmount: 32.31,
        detectionMethod: .aiAnalysis,
        confidence: 0.92,
        evidenceText: "Monthly interest charged: $1,089.95, Expected: $1,057.64",
        calculationDetails: AuditResult.CalculationDetails(
            expectedValue: 1057.64,
            actualValue: 1089.95,
            difference: 32.31,
            formula: "Monthly Interest = (Principal × Annual Rate) / 12",
            assumptions: ["Annual rate: 4.25%", "No rate changes", "Standard amortization"],
            warningFlags: ["Rate calculation error", "Potential systematic overcharge"]
        ),
        createdDate: Date()
    )

    public static let escrowError = AuditResult(
        issueType: .escrowError,
        severity: .medium,
        title: "Escrow Shortage Miscalculated",
        description: "Escrow analysis shows incorrect shortage amount",
        detailedExplanation: "The escrow analysis indicates a shortage of $125.50, but recalculation based on actual disbursements and deposits shows the account should have a surplus of $45.75.",
        suggestedAction: "Request corrected escrow analysis and refund of overpayment",
        affectedAmount: 171.25,
        detectionMethod: .combinedAnalysis,
        confidence: 0.84,
        evidenceText: "Projected shortage: $125.50, Calculated surplus: $45.75",
        calculationDetails: AuditResult.CalculationDetails(
            expectedValue: -45.75, // Negative indicates surplus
            actualValue: 125.50,
            difference: 171.25,
            formula: "Escrow Balance = Deposits - Disbursements - Required Reserve",
            assumptions: ["Required reserve: 2 months", "Accurate disbursement records"],
            warningFlags: ["Analysis methodology unclear", "Missing disbursement records"]
        ),
        createdDate: Date()
    )

    public static let unauthorizedFee = AuditResult(
        issueType: .unauthorizedFee,
        severity: .high,
        title: "Inspection Fee Not Authorized",
        description: "Property inspection fee charged without proper authorization",
        detailedExplanation: "A $150 property inspection fee was charged on 11/15/2024. However, there is no record of default, missed payments, or other conditions that would authorize such an inspection under the loan terms.",
        suggestedAction: "Dispute the fee and demand removal with refund",
        affectedAmount: 150.00,
        detectionMethod: .aiAnalysis,
        confidence: 0.91,
        evidenceText: "Inspection fee charged: $150.00 on 11/15/2024",
        calculationDetails: AuditResult.CalculationDetails(
            expectedValue: 0.00,
            actualValue: 150.00,
            difference: 150.00,
            formula: "Authorized fees only per loan agreement",
            assumptions: ["No default condition", "Current on payments", "No insurance issues"],
            warningFlags: ["Unauthorized fee", "Potential RESPA violation"]
        ),
        createdDate: Date()
    )

    /// Collection of typical audit results for testing
    public static let allResults = [
        latePaymentError,
        misappliedPayment,
        incorrectInterest,
        escrowError,
        unauthorizedFee
    ]

    /// High-severity results for critical testing
    public static let criticalResults = allResults.filter { $0.severity == .critical || $0.severity == .high }

    /// Results with financial impact
    public static let monetaryResults = allResults.filter { $0.affectedAmount != nil }
}

// MARK: - Mock Transactions

public struct MockTransactions {

    public static let mortgagePayments = [
        Transaction(
            id: "TXN001",
            accountId: "ACC123",
            amount: -1725.45,
            date: Date.testDate(year: 2024, month: 11, day: 1),
            description: "MORTGAGE PAYMENT - EXAMPLE MORTGAGE CORP",
            category: "Mortgage Payment",
            merchantName: "Example Mortgage Corp",
            relatedMortgagePayment: true
        ),
        Transaction(
            id: "TXN002",
            accountId: "ACC123",
            amount: -1725.45,
            date: Date.testDate(year: 2024, month: 10, day: 1),
            description: "AUTOMATIC PAYMENT - MORTGAGE",
            category: "Mortgage Payment",
            merchantName: "Example Mortgage Corp",
            relatedMortgagePayment: true
        ),
        Transaction(
            id: "TXN003",
            accountId: "ACC123",
            amount: -1725.45,
            date: Date.testDate(year: 2024, month: 9, day: 1),
            description: "ONLINE PAYMENT - MORTGAGE CORP",
            category: "Mortgage Payment",
            merchantName: "Example Mortgage Corp",
            relatedMortgagePayment: true
        )
    ]

    public static let mixedTransactions = [
        Transaction(
            id: "TXN004",
            accountId: "ACC123",
            amount: -1725.45,
            date: Date.testDate(year: 2024, month: 8, day: 1),
            description: "MORTGAGE PAYMENT",
            category: "Mortgage Payment",
            merchantName: "Example Mortgage Corp",
            relatedMortgagePayment: true
        ),
        Transaction(
            id: "TXN005",
            accountId: "ACC123",
            amount: -2500.00,
            date: Date.testDate(year: 2024, month: 8, day: 5),
            description: "RENT PAYMENT",
            category: "Rent",
            merchantName: "Property Management Co",
            relatedMortgagePayment: false
        ),
        Transaction(
            id: "TXN006",
            accountId: "ACC123",
            amount: 3500.00,
            date: Date.testDate(year: 2024, month: 8, day: 15),
            description: "PAYROLL DEPOSIT",
            category: "Income",
            merchantName: "Employer Corp",
            relatedMortgagePayment: false
        )
    ]
}

// MARK: - Mock Images

public struct MockImages {

    /// Generate a mock mortgage statement image
    public static func createMockStatementImage() -> UIImage {
        let size = CGSize(width: 612, height: 792) // Letter size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Black text
            UIColor.black.setFill()

            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24)
            ]
            let title = "MORTGAGE STATEMENT"
            title.draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)

            // Body text
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]
            let bodyText = MockDocumentTexts.mortgageStatementText
            let rect = CGRect(x: 50, y: 100, width: 512, height: 600)
            bodyText.draw(in: rect, withAttributes: bodyAttributes)
        }
    }

    /// Generate a corrupted/poor quality image
    public static func createPoorQualityImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Random noise pattern
            for x in 0..<Int(size.width) {
                for y in 0..<Int(size.height) {
                    let gray = CGFloat.random(in: 0...1)
                    UIColor(white: gray, alpha: 1.0).setFill()
                    context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }
}

// MARK: - Mock Service Responses

public struct MockServiceResponses {

    public static let claudeAnalysisResponse = """
    {
        "findings": [
            {
                "issueType": "late_payment_error",
                "severity": "high",
                "title": "Incorrect Late Fee Charged",
                "description": "A late fee was charged despite payment being received on time",
                "detailedExplanation": "Payment due 01/01/2025 was received 01/05/2025, but your bank records show the payment was actually sent on 12/30/2024.",
                "suggestedAction": "Send a Notice of Error letter requesting removal of the late fee",
                "affectedAmount": 25.00,
                "confidence": 0.95,
                "evidenceText": "Payment due 01/01/2025 was received 01/05/2025, late fee charged",
                "reasoning": "Bank records show payment was sent before due date"
            }
        ],
        "overallConfidence": 0.95,
        "summary": "Analysis found 1 high-severity issue with late fee application"
    }
    """

    public static let plaidAccountsResponse = """
    {
        "accounts": [
            {
                "account_id": "ACC123",
                "balances": {
                    "available": 5000.00,
                    "current": 5250.75,
                    "limit": null
                },
                "mask": "1234",
                "name": "Checking Account",
                "official_name": "Primary Checking Account",
                "subtype": "checking",
                "type": "depository"
            }
        ]
    }
    """

    public static let plaidTransactionsResponse = """
    {
        "transactions": [
            {
                "transaction_id": "TXN001",
                "account_id": "ACC123",
                "amount": 1725.45,
                "date": "2024-11-01",
                "name": "MORTGAGE PAYMENT - EXAMPLE MORTGAGE CORP",
                "category": ["Payment", "Mortgage"],
                "merchant_name": "Example Mortgage Corp"
            }
        ],
        "total_transactions": 1
    }
    """

    public static let errorResponse = """
    {
        "error": {
            "error_code": "INVALID_REQUEST",
            "error_message": "Invalid request parameters",
            "display_message": "Please check your request and try again"
        }
    }
    """
}

// MARK: - Mock File Data

public struct MockFileData {

    /// Create mock PDF data
    public static func createMockPDFData() -> Data {
        // This is a minimal PDF structure for testing
        let pdfContent = """
        %PDF-1.4
        1 0 obj
        <<
        /Type /Catalog
        /Pages 2 0 R
        >>
        endobj
        2 0 obj
        <<
        /Type /Pages
        /Kids [3 0 R]
        /Count 1
        >>
        endobj
        3 0 obj
        <<
        /Type /Page
        /Parent 2 0 R
        /MediaBox [0 0 612 792]
        >>
        endobj
        xref
        0 4
        0000000000 65535 f
        0000000009 00000 n
        0000000074 00000 n
        0000000120 00000 n
        trailer
        <<
        /Size 4
        /Root 1 0 R
        >>
        startxref
        190
        %%EOF
        """
        return pdfContent.data(using: .utf8) ?? Data()
    }

    /// Create mock image data (PNG)
    public static func createMockImageData() -> Data {
        return MockImages.createMockStatementImage().pngData() ?? Data()
    }

    /// Create corrupted file data
    public static func createCorruptedData() -> Data {
        return Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]) // Truncated JPEG header
    }
}

// MARK: - Test Data Factory

public struct TestDataFactory {

    /// Create a user with specific characteristics
    public static func createUser(
        withAccounts accountCount: Int = 1,
        hasProblems: Bool = false
    ) -> User {
        let user = hasProblems ? MockUsers.problematicUser : MockUsers.standardUser

        if accountCount > 1 {
            return MockUsers.multiAccountUser
        }

        return user
    }

    /// Create a document with specific type and content
    public static func createDocument(
        type: MortgageDocument.DocumentType,
        withIssues: Bool = false
    ) -> MortgageDocument {
        switch type {
        case .mortgageStatement:
            return withIssues ? MockDocuments.corruptedDocument : MockDocuments.mortgageStatement
        case .escrowStatement:
            return MockDocuments.escrowStatement
        case .paymentHistory:
            return MockDocuments.paymentHistory
        default:
            return MockDocuments.mortgageStatement
        }
    }

    /// Create audit results with specific characteristics
    public static func createAuditResults(
        count: Int = 3,
        severity: AuditResult.Severity? = nil,
        withMonetaryImpact: Bool = true
    ) -> [AuditResult] {
        var results = MockAuditResults.allResults

        if let severity = severity {
            results = results.filter { $0.severity == severity }
        }

        if withMonetaryImpact {
            results = results.filter { $0.affectedAmount != nil }
        }

        return Array(results.prefix(count))
    }

    /// Create bank transactions for testing
    public static func createTransactions(
        mortgageRelated: Bool = true,
        count: Int = 5
    ) -> [Transaction] {
        let source = mortgageRelated ? MockTransactions.mortgagePayments : MockTransactions.mixedTransactions
        return Array(source.prefix(count))
    }
}