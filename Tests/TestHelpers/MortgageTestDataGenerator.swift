import Foundation
@testable import MortgageGuardian

/// Test data generator for creating known mortgage violation patterns
/// Used by the ZeroToleranceTestFramework to validate error detection
class MortgageTestDataGenerator {

    // MARK: - Payment Processing Violations

    func generatePaymentAllocationMismatchData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "123456789",
            balanceInformation: BalanceInformation(
                principalBalance: 250000.00,
                interestBalance: 1250.50,
                escrowBalance: 850.00,
                feesBalance: 75.00,
                totalBalance: 252175.50
            ),
            paymentHistory: [
                PaymentRecord(
                    date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                    amount: 2000.00,
                    principalPortion: 800.00, // Should be 750.00 based on calculation
                    interestPortion: 1100.00, // Should be 1150.00 based on calculation
                    escrowPortion: 100.00,
                    feesPortion: 0.00,
                    transactionType: "Payment"
                )
            ],
            transactionHistory: [],
            loanTerms: LoanTerms(
                originalAmount: 300000.00,
                interestRate: 4.5,
                termInMonths: 360,
                paymentAmount: 1520.06
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Mortgage Statement",
                pageCount: 3,
                confidence: 0.95
            )
        )
    }

    func generateDuplicatePaymentData() -> ExtractedMortgageData {
        let duplicatePayment = PaymentRecord(
            date: Date().addingTimeInterval(-15 * 24 * 60 * 60),
            amount: 1520.06,
            principalPortion: 750.00,
            interestPortion: 670.06,
            escrowPortion: 100.00,
            feesPortion: 0.00,
            transactionType: "Payment"
        )

        return ExtractedMortgageData(
            accountNumber: "123456789",
            balanceInformation: BalanceInformation(
                principalBalance: 250000.00,
                interestBalance: 0.00,
                escrowBalance: 850.00,
                feesBalance: 0.00,
                totalBalance: 250850.00
            ),
            paymentHistory: [
                duplicatePayment,
                duplicatePayment // Exact duplicate - should be flagged
            ],
            transactionHistory: [],
            loanTerms: LoanTerms(
                originalAmount: 300000.00,
                interestRate: 4.5,
                termInMonths: 360,
                paymentAmount: 1520.06
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Mortgage Statement",
                pageCount: 2,
                confidence: 0.92
            )
        )
    }

    func generatePaymentWithoutBankTransactionData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "123456789",
            balanceInformation: BalanceInformation(
                principalBalance: 248480.00,
                interestBalance: 0.00,
                escrowBalance: 850.00,
                feesBalance: 0.00,
                totalBalance: 249330.00
            ),
            paymentHistory: [
                PaymentRecord(
                    date: Date().addingTimeInterval(-5 * 24 * 60 * 60),
                    amount: 1520.06,
                    principalPortion: 750.00,
                    interestPortion: 670.06,
                    escrowPortion: 100.00,
                    feesPortion: 0.00,
                    transactionType: "Payment"
                )
            ],
            transactionHistory: [],
            loanTerms: LoanTerms(
                originalAmount: 300000.00,
                interestRate: 4.5,
                termInMonths: 360,
                paymentAmount: 1520.06
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Mortgage Statement",
                pageCount: 2,
                confidence: 0.88
            )
        )
    }

    func generateUnauthorizedPaymentReversalData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "123456789",
            balanceInformation: BalanceInformation(
                principalBalance: 251520.06, // Balance increased due to reversal
                interestBalance: 670.06,
                escrowBalance: 750.00,
                feesBalance: 35.00, // Reversal fee added
                totalBalance: 252975.12
            ),
            paymentHistory: [
                PaymentRecord(
                    date: Date().addingTimeInterval(-20 * 24 * 60 * 60),
                    amount: 1520.06,
                    principalPortion: 750.00,
                    interestPortion: 670.06,
                    escrowPortion: 100.00,
                    feesPortion: 0.00,
                    transactionType: "Payment"
                ),
                PaymentRecord(
                    date: Date().addingTimeInterval(-18 * 24 * 60 * 60),
                    amount: -1520.06, // Negative amount indicates reversal
                    principalPortion: -750.00,
                    interestPortion: -670.06,
                    escrowPortion: -100.00,
                    feesPortion: 35.00, // Fee added for reversal
                    transactionType: "Payment Reversal"
                )
            ],
            transactionHistory: [],
            loanTerms: LoanTerms(
                originalAmount: 300000.00,
                interestRate: 4.5,
                termInMonths: 360,
                paymentAmount: 1520.06
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Mortgage Statement",
                pageCount: 3,
                confidence: 0.91
            )
        )
    }

    func generatePaymentTimingViolationsData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "123456789",
            balanceInformation: BalanceInformation(
                principalBalance: 250000.00,
                interestBalance: 0.00,
                escrowBalance: 850.00,
                feesBalance: 25.00, // Late fee charged incorrectly
                totalBalance: 250875.00
            ),
            paymentHistory: [
                PaymentRecord(
                    date: Calendar.current.date(byAdding: .day, value: 3, to: Date())!, // Future-dated payment
                    amount: 1520.06,
                    principalPortion: 750.00,
                    interestPortion: 670.06,
                    escrowPortion: 100.00,
                    feesPortion: 0.00,
                    transactionType: "Payment"
                )
            ],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-2 * 24 * 60 * 60),
                    description: "Late Fee",
                    amount: 25.00,
                    transactionType: "Fee",
                    runningBalance: 250875.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 300000.00,
                interestRate: 4.5,
                termInMonths: 360,
                paymentAmount: 1520.06
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Mortgage Statement",
                pageCount: 2,
                confidence: 0.86
            )
        )
    }

    func generatePaymentApplicationOrderErrorsData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "123456789",
            balanceInformation: BalanceInformation(
                principalBalance: 250000.00,
                interestBalance: 0.00,
                escrowBalance: 850.00,
                feesBalance: 0.00,
                totalBalance: 250850.00
            ),
            paymentHistory: [
                PaymentRecord(
                    date: Date().addingTimeInterval(-10 * 24 * 60 * 60),
                    amount: 2000.00, // Overpayment
                    principalPortion: 1229.94, // Applied to principal before fees - incorrect order
                    interestPortion: 670.06,
                    escrowPortion: 100.00,
                    feesPortion: 0.00, // Outstanding fees exist but not paid first
                    transactionType: "Payment"
                )
            ],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-15 * 24 * 60 * 60),
                    description: "Late Fee",
                    amount: 25.00,
                    transactionType: "Fee",
                    runningBalance: 252400.06
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 300000.00,
                interestRate: 4.5,
                termInMonths: 360,
                paymentAmount: 1520.06
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Mortgage Statement",
                pageCount: 3,
                confidence: 0.93
            )
        )
    }

    // MARK: - Interest Calculation Violations

    func generateInterestRateMisapplicationData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "987654321",
            balanceInformation: BalanceInformation(
                principalBalance: 200000.00,
                interestBalance: 900.00, // Calculated at 5.4% instead of 4.5%
                escrowBalance: 1200.00,
                feesBalance: 0.00,
                totalBalance: 202100.00
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                    description: "Interest Accrual",
                    amount: 900.00, // Should be 750.00 at 4.5%
                    transactionType: "Interest",
                    runningBalance: 200900.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 250000.00,
                interestRate: 4.5, // Contract rate
                termInMonths: 360,
                paymentAmount: 1266.71
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Mortgage Statement",
                pageCount: 2,
                confidence: 0.89
            )
        )
    }

    func generateCompoundingFrequencyErrorsData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "987654321",
            balanceInformation: BalanceInformation(
                principalBalance: 180000.00,
                interestBalance: 675.62, // Daily compounding instead of monthly
                escrowBalance: 1100.00,
                feesBalance: 0.00,
                totalBalance: 181775.62
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                    description: "Interest Accrual - Daily Compound",
                    amount: 675.62, // Should be 675.00 with monthly compounding
                    transactionType: "Interest",
                    runningBalance: 180675.62
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 250000.00,
                interestRate: 4.5,
                termInMonths: 360,
                paymentAmount: 1266.71
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Mortgage Statement",
                pageCount: 2,
                confidence: 0.94
            )
        )
    }

    func generateInterestAccrualCalculationErrorsData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "987654321",
            balanceInformation: BalanceInformation(
                principalBalance: 195000.00,
                interestBalance: 825.00, // Wrong per diem calculation
                escrowBalance: 1050.00,
                feesBalance: 0.00,
                totalBalance: 196875.00
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-33 * 24 * 60 * 60),
                    description: "Interest Accrual - 33 days",
                    amount: 825.00, // Should be 792.74 (195000 * 0.045 / 365 * 33)
                    transactionType: "Interest",
                    runningBalance: 195825.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 250000.00,
                interestRate: 4.5,
                termInMonths: 360,
                paymentAmount: 1266.71
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Mortgage Statement",
                pageCount: 2,
                confidence: 0.91
            )
        )
    }

    func generateARMInterestCapViolationData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "ARM123456",
            balanceInformation: BalanceInformation(
                principalBalance: 175000.00,
                interestBalance: 1020.83, // Interest calculated at 7.0% exceeding cap
                escrowBalance: 950.00,
                feesBalance: 0.00,
                totalBalance: 176970.83
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                    description: "Interest Rate Adjustment to 7.0%",
                    amount: 1020.83, // Should be capped at 6.5% = 945.83
                    transactionType: "Interest",
                    runningBalance: 176020.83
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 250000.00,
                interestRate: 7.0, // Exceeds 6.5% lifetime cap
                termInMonths: 360,
                paymentAmount: 1663.26
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "ARM Statement",
                pageCount: 4,
                confidence: 0.87
            )
        )
    }

    func generateInterestOnlyPeriodViolationData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "IO123456",
            balanceInformation: BalanceInformation(
                principalBalance: 299250.00, // Principal should not decrease during I/O period
                interestBalance: 0.00,
                escrowBalance: 1200.00,
                feesBalance: 0.00,
                totalBalance: 300450.00
            ),
            paymentHistory: [
                PaymentRecord(
                    date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                    amount: 1125.00, // Interest-only payment
                    principalPortion: 750.00, // Should be 0.00 during I/O period
                    interestPortion: 1125.00,
                    escrowPortion: 200.00,
                    feesPortion: 0.00,
                    transactionType: "Interest Only Payment"
                )
            ],
            transactionHistory: [],
            loanTerms: LoanTerms(
                originalAmount: 300000.00,
                interestRate: 4.5,
                termInMonths: 360,
                paymentAmount: 1125.00 // Interest-only payment
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Interest Only Statement",
                pageCount: 3,
                confidence: 0.92
            )
        )
    }

    // MARK: - Regulatory Compliance Violations

    func generateRESPASection6ViolationData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "RESPA123456",
            balanceInformation: BalanceInformation(
                principalBalance: 185000.00,
                interestBalance: 0.00,
                escrowBalance: 1500.00,
                feesBalance: 0.00,
                totalBalance: 186500.00
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-10 * 24 * 60 * 60),
                    description: "Servicing Transfer - No 60-day notice provided",
                    amount: 0.00,
                    transactionType: "Servicing Transfer",
                    runningBalance: 186500.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 250000.00,
                interestRate: 4.25,
                termInMonths: 360,
                paymentAmount: 1229.85
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "New Servicer LLC", // Different from original
                servicerAddress: "456 New St, New City, NS 54321",
                customerServicePhone: "(555) 987-6543"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Transfer Notice",
                pageCount: 1,
                confidence: 0.78
            )
        )
    }

    func generateRESPASection8ViolationData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "KICKBACK123",
            balanceInformation: BalanceInformation(
                principalBalance: 200000.00,
                interestBalance: 0.00,
                escrowBalance: 2500.00, // Inflated escrow account
                feesBalance: 125.00, // Kickback-related fees
                totalBalance: 202625.00
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-20 * 24 * 60 * 60),
                    description: "Insurance Placement Fee - Preferred Provider",
                    amount: 125.00, // Kickback arrangement
                    transactionType: "Fee",
                    runningBalance: 202625.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 275000.00,
                interestRate: 4.75,
                termInMonths: 360,
                paymentAmount: 1439.10
            ),
            escrowAnalysis: EscrowAnalysis(
                propertyTaxes: 6000.00,
                homeownersInsurance: 2400.00, // Inflated premium from preferred provider
                pmiPayment: 0.00,
                floodInsurance: 0.00,
                totalEscrowPayment: 700.00,
                escrowShortage: 0.00,
                escrowSurplus: 0.00
            ),
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Escrow Statement",
                pageCount: 5,
                confidence: 0.85
            )
        )
    }

    func generateRESPASection10ViolationData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "ESCROW123",
            balanceInformation: BalanceInformation(
                principalBalance: 190000.00,
                interestBalance: 0.00,
                escrowBalance: 3500.00, // Excessive escrow balance
                feesBalance: 0.00,
                totalBalance: 193500.00
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-365 * 24 * 60 * 60),
                    description: "Last Escrow Analysis - Over 12 months ago",
                    amount: 0.00,
                    transactionType: "Escrow Analysis",
                    runningBalance: 190000.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 260000.00,
                interestRate: 4.625,
                termInMonths: 360,
                paymentAmount: 1336.89
            ),
            escrowAnalysis: EscrowAnalysis(
                propertyTaxes: 4800.00,
                homeownersInsurance: 1800.00,
                pmiPayment: 0.00,
                floodInsurance: 0.00,
                totalEscrowPayment: 550.00,
                escrowShortage: 0.00,
                escrowSurplus: 1200.00 // Should have been refunded
            ),
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Annual Escrow Statement",
                pageCount: 6,
                confidence: 0.82
            )
        )
    }

    func generateTILADisclosureViolationData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "TILA123456",
            balanceInformation: BalanceInformation(
                principalBalance: 245000.00,
                interestBalance: 950.00,
                escrowBalance: 1400.00,
                feesBalance: 0.00,
                totalBalance: 247350.00
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-90 * 24 * 60 * 60),
                    description: "ARM Rate Change - No advance notice provided",
                    amount: 0.00,
                    transactionType: "Rate Change",
                    runningBalance: 247350.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 300000.00,
                interestRate: 4.625, // Changed from 3.5% without proper notice
                termInMonths: 360,
                paymentAmount: 1542.92
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "ARM Adjustment Notice",
                pageCount: 2,
                confidence: 0.79
            )
        )
    }

    func generateDualTrackingViolationData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "DUAL123456",
            balanceInformation: BalanceInformation(
                principalBalance: 280000.00,
                interestBalance: 1250.00,
                escrowBalance: 1800.00,
                feesBalance: 1500.00, // Foreclosure fees while mod pending
                totalBalance: 284550.00
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                    description: "Loan Modification Application Received",
                    amount: 0.00,
                    transactionType: "Modification Application",
                    runningBalance: 283050.00
                ),
                TransactionRecord(
                    date: Date().addingTimeInterval(-15 * 24 * 60 * 60),
                    description: "Foreclosure Proceedings Initiated", // Dual tracking violation
                    amount: 1500.00,
                    transactionType: "Foreclosure Fee",
                    runningBalance: 284550.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 350000.00,
                interestRate: 5.25,
                termInMonths: 360,
                paymentAmount: 1932.66
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Foreclosure Notice",
                pageCount: 4,
                confidence: 0.91
            )
        )
    }

    func generateBankruptcyAutomaticStayViolationsData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "BKCY123456",
            balanceInformation: BalanceInformation(
                principalBalance: 195000.00,
                interestBalance: 875.00,
                escrowBalance: 1200.00,
                feesBalance: 750.00, // Collection activities post-bankruptcy filing
                totalBalance: 197825.00
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-45 * 24 * 60 * 60),
                    description: "Chapter 13 Bankruptcy Filed",
                    amount: 0.00,
                    transactionType: "Bankruptcy Filing",
                    runningBalance: 197075.00
                ),
                TransactionRecord(
                    date: Date().addingTimeInterval(-20 * 24 * 60 * 60),
                    description: "Collection Activity Fee", // Violation of automatic stay
                    amount: 750.00,
                    transactionType: "Fee",
                    runningBalance: 197825.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 285000.00,
                interestRate: 4.875,
                termInMonths: 360,
                paymentAmount: 1507.19
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Bankruptcy Account Statement",
                pageCount: 3,
                confidence: 0.86
            )
        )
    }

    func generateSCRAViolationsData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "SCRA123456",
            balanceInformation: BalanceInformation(
                principalBalance: 220000.00,
                interestBalance: 1100.00, // Interest above 6% cap for military
                escrowBalance: 1600.00,
                feesBalance: 0.00,
                totalBalance: 222700.00
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-60 * 24 * 60 * 60),
                    description: "Military Deployment Notice Received",
                    amount: 0.00,
                    transactionType: "SCRA Notice",
                    runningBalance: 221600.00
                ),
                TransactionRecord(
                    date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                    description: "Interest Charged at 7.5%", // Should be capped at 6%
                    amount: 1100.00,
                    transactionType: "Interest",
                    runningBalance: 222700.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 320000.00,
                interestRate: 7.5, // Should be reduced to 6% for active duty
                termInMonths: 360,
                paymentAmount: 2238.95
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Military Account Statement",
                pageCount: 2,
                confidence: 0.88
            )
        )
    }

    func generateForeclosureTimelineViolationsData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "FCL123456",
            balanceInformation: BalanceInformation(
                principalBalance: 265000.00,
                interestBalance: 1950.00,
                escrowBalance: 2200.00,
                feesBalance: 2500.00, // Excessive foreclosure fees
                totalBalance: 271650.00
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-120 * 24 * 60 * 60),
                    description: "First Missed Payment",
                    amount: 0.00,
                    transactionType: "Missed Payment",
                    runningBalance: 266500.00
                ),
                TransactionRecord(
                    date: Date().addingTimeInterval(-90 * 24 * 60 * 60),
                    description: "Foreclosure Notice Sent", // Too early - should wait 120+ days
                    amount: 500.00,
                    transactionType: "Foreclosure Notice Fee",
                    runningBalance: 267000.00
                ),
                TransactionRecord(
                    date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                    description: "Attorney Fees",
                    amount: 2000.00, // Excessive fees
                    transactionType: "Legal Fee",
                    runningBalance: 271650.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 380000.00,
                interestRate: 5.75,
                termInMonths: 360,
                paymentAmount: 2218.89
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Foreclosure Statement",
                pageCount: 5,
                confidence: 0.83
            )
        )
    }

    // MARK: - Bank Transaction Generation

    func generateMatchingBankTransactions(for extractedData: ExtractedMortgageData) -> [Transaction] {
        var transactions: [Transaction] = []

        // Generate transactions that should match payment history
        for (index, payment) in extractedData.paymentHistory.enumerated() {
            // Skip generating bank transaction for test cases where payment shouldn't exist
            if extractedData.accountNumber == "123456789" && payment.amount == 1520.06 &&
               extractedData.paymentHistory.count == 1 {
                // This is the "payment without bank transaction" test case
                continue
            }

            transactions.append(Transaction(
                account_id: "test_account_id",
                amount: payment.amount,
                authorized_date: payment.date,
                category: ["Transfer", "Deposit"],
                date: payment.date,
                name: "MORTGAGE PAYMENT - \(extractedData.contactInformation.servicerName)",
                account_owner: "Test Owner",
                transaction_id: "txn_\(index)_\(UUID().uuidString)"
            ))
        }

        return transactions
    }

    // MARK: - Loan Details Generation

    func generateARMLoanDetails() -> LoanDetails {
        return LoanDetails(
            loanNumber: "ARM123456",
            originalAmount: 250000.00,
            currentBalance: 175000.00,
            interestRate: 7.0, // Current rate exceeding cap
            originalInterestRate: 3.5,
            adjustmentDate: Date().addingTimeInterval(-30 * 24 * 60 * 60),
            nextAdjustmentDate: Date().addingTimeInterval(335 * 24 * 60 * 60),
            interestRateCap: InterestRateCap(
                initialCap: 2.0,
                periodicCap: 1.0,
                lifetimeCap: 6.5 // Current rate violates this
            ),
            loanType: .adjustableRate,
            termInMonths: 360,
            remainingTermInMonths: 312,
            maturityDate: Date().addingTimeInterval(312 * 30 * 24 * 60 * 60),
            propertyAddress: "123 ARM Lane, Test City, TS 12345"
        )
    }

    func generateInterestOnlyLoanDetails() -> LoanDetails {
        return LoanDetails(
            loanNumber: "IO123456",
            originalAmount: 300000.00,
            currentBalance: 299250.00, // Should be 300000 during I/O period
            interestRate: 4.5,
            originalInterestRate: 4.5,
            adjustmentDate: nil,
            nextAdjustmentDate: nil,
            interestRateCap: nil,
            loanType: .interestOnly,
            termInMonths: 360,
            remainingTermInMonths: 355,
            maturityDate: Date().addingTimeInterval(355 * 30 * 24 * 60 * 60),
            propertyAddress: "456 Interest Only Blvd, Test City, TS 12345",
            interestOnlyEndDate: Date().addingTimeInterval(60 * 30 * 24 * 60 * 60) // 5 years I/O period
        )
    }

    func generateStandardLoanDetails() -> LoanDetails {
        return LoanDetails(
            loanNumber: "STD123456",
            originalAmount: 275000.00,
            currentBalance: 200000.00,
            interestRate: 4.75,
            originalInterestRate: 4.75,
            adjustmentDate: nil,
            nextAdjustmentDate: nil,
            interestRateCap: nil,
            loanType: .fixedRate,
            termInMonths: 360,
            remainingTermInMonths: 285,
            maturityDate: Date().addingTimeInterval(285 * 30 * 24 * 60 * 60),
            propertyAddress: "789 Standard St, Test City, TS 12345"
        )
    }

    // MARK: - Escrow Violation Data Generation

    func generateEscrowShortageCalculationErrorData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "ESCROW001",
            balanceInformation: BalanceInformation(
                principalBalance: 210000.00,
                interestBalance: 0.00,
                escrowBalance: 800.00, // Incorrectly calculated shortage
                feesBalance: 0.00,
                totalBalance: 210800.00
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-365 * 24 * 60 * 60),
                    description: "Annual Escrow Analysis - Shortage miscalculated",
                    amount: 0.00,
                    transactionType: "Escrow Analysis",
                    runningBalance: 210800.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 280000.00,
                interestRate: 4.25,
                termInMonths: 360,
                paymentAmount: 1378.53
            ),
            escrowAnalysis: EscrowAnalysis(
                propertyTaxes: 7200.00, // Increased from 6000 but calculation error
                homeownersInsurance: 2400.00,
                pmiPayment: 0.00,
                floodInsurance: 0.00,
                totalEscrowPayment: 600.00, // Should be 800.00
                escrowShortage: 1200.00, // Incorrectly calculated
                escrowSurplus: 0.00
            ),
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Escrow Analysis",
                pageCount: 4,
                confidence: 0.87
            )
        )
    }

    func generateUnauthorizedEscrowDeductionData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "ESCROW002",
            balanceInformation: BalanceInformation(
                principalBalance: 195000.00,
                interestBalance: 0.00,
                escrowBalance: 600.00, // Reduced by unauthorized deduction
                feesBalance: 0.00,
                totalBalance: 195600.00
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-15 * 24 * 60 * 60),
                    description: "Unauthorized Insurance Deduction", // No notice provided
                    amount: 800.00,
                    transactionType: "Escrow Deduction",
                    runningBalance: 195600.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 275000.00,
                interestRate: 4.75,
                termInMonths: 360,
                paymentAmount: 1439.10
            ),
            escrowAnalysis: EscrowAnalysis(
                propertyTaxes: 5400.00,
                homeownersInsurance: 1800.00, // Policy lapsed but deduction made anyway
                pmiPayment: 0.00,
                floodInsurance: 0.00,
                totalEscrowPayment: 600.00,
                escrowShortage: 0.00,
                escrowSurplus: 0.00
            ),
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Escrow Statement",
                pageCount: 3,
                confidence: 0.84
            )
        )
    }

    func generateEscrowAnalysisTimingViolationData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "ESCROW003",
            balanceInformation: BalanceInformation(
                principalBalance: 185000.00,
                interestBalance: 0.00,
                escrowBalance: 2800.00, // No analysis for 18 months
                feesBalance: 0.00,
                totalBalance: 187800.00
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-545 * 24 * 60 * 60), // 18 months ago
                    description: "Last Escrow Analysis - RESPA violation",
                    amount: 0.00,
                    transactionType: "Escrow Analysis",
                    runningBalance: 185000.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 260000.00,
                interestRate: 4.5,
                termInMonths: 360,
                paymentAmount: 1317.39
            ),
            escrowAnalysis: EscrowAnalysis(
                propertyTaxes: 4800.00,
                homeownersInsurance: 1800.00,
                pmiPayment: 0.00,
                floodInsurance: 0.00,
                totalEscrowPayment: 550.00,
                escrowShortage: 0.00,
                escrowSurplus: 1500.00 // Should have been identified and refunded
            ),
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Mortgage Statement",
                pageCount: 2,
                confidence: 0.91
            )
        )
    }

    func generateForcePlacedInsuranceViolationData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "ESCROW004",
            balanceInformation: BalanceInformation(
                principalBalance: 225000.00,
                interestBalance: 0.00,
                escrowBalance: 1200.00,
                feesBalance: 150.00, // Force-placed insurance processing fee
                totalBalance: 226350.00
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                    description: "Force-Placed Insurance - No grace period",
                    amount: 3600.00, // Excessive premium for force-placed coverage
                    transactionType: "Insurance",
                    runningBalance: 226350.00
                ),
                TransactionRecord(
                    date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                    description: "Force-Placed Insurance Processing Fee",
                    amount: 150.00,
                    transactionType: "Fee",
                    runningBalance: 226350.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 300000.00,
                interestRate: 5.0,
                termInMonths: 360,
                paymentAmount: 1610.46
            ),
            escrowAnalysis: EscrowAnalysis(
                propertyTaxes: 6000.00,
                homeownersInsurance: 3600.00, // Force-placed at 3x normal rate
                pmiPayment: 0.00,
                floodInsurance: 0.00,
                totalEscrowPayment: 800.00,
                escrowShortage: 0.00,
                escrowSurplus: 0.00
            ),
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Force-Placed Insurance Notice",
                pageCount: 3,
                confidence: 0.89
            )
        )
    }

    func generateEscrowRefundViolationData() -> ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "ESCROW005",
            balanceInformation: BalanceInformation(
                principalBalance: 165000.00,
                interestBalance: 0.00,
                escrowBalance: 3200.00, // Excessive surplus not refunded
                feesBalance: 0.00,
                totalBalance: 168200.00
            ),
            paymentHistory: [],
            transactionHistory: [
                TransactionRecord(
                    date: Date().addingTimeInterval(-120 * 24 * 60 * 60),
                    description: "Escrow Analysis - Surplus not refunded",
                    amount: 0.00,
                    transactionType: "Escrow Analysis",
                    runningBalance: 168200.00
                )
            ],
            loanTerms: LoanTerms(
                originalAmount: 240000.00,
                interestRate: 4.125,
                termInMonths: 360,
                paymentAmount: 1165.11
            ),
            escrowAnalysis: EscrowAnalysis(
                propertyTaxes: 3600.00, // Decreased but surplus retained
                homeownersInsurance: 1200.00, // Decreased but surplus retained
                pmiPayment: 0.00,
                floodInsurance: 0.00,
                totalEscrowPayment: 400.00,
                escrowShortage: 0.00,
                escrowSurplus: 2400.00 // Should be refunded if > $50
            ),
            contactInformation: ContactInformation(
                servicerName: "Test Servicer",
                servicerAddress: "123 Test St, Test City, TS 12345",
                customerServicePhone: "(555) 123-4567"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Escrow Analysis",
                pageCount: 4,
                confidence: 0.86
            )
        )
    }

    // MARK: - Random Test Data Generation

    func generateRandomTestData() -> ExtractedMortgageData {
        let accountNumbers = ["RAND001", "RAND002", "RAND003", "RAND004", "RAND005"]
        let randomAccount = accountNumbers.randomElement()!

        return ExtractedMortgageData(
            accountNumber: randomAccount,
            balanceInformation: BalanceInformation(
                principalBalance: Double.random(in: 100000...500000),
                interestBalance: Double.random(in: 0...2000),
                escrowBalance: Double.random(in: 500...3000),
                feesBalance: Double.random(in: 0...500),
                totalBalance: Double.random(in: 102000...506000)
            ),
            paymentHistory: [
                PaymentRecord(
                    date: Date().addingTimeInterval(-Double.random(in: 1...60) * 24 * 60 * 60),
                    amount: Double.random(in: 1000...3000),
                    principalPortion: Double.random(in: 400...1500),
                    interestPortion: Double.random(in: 500...1200),
                    escrowPortion: Double.random(in: 100...300),
                    feesPortion: Double.random(in: 0...100),
                    transactionType: "Payment"
                )
            ],
            transactionHistory: [],
            loanTerms: LoanTerms(
                originalAmount: Double.random(in: 150000...600000),
                interestRate: Double.random(in: 3.0...8.0),
                termInMonths: [240, 300, 360].randomElement()!,
                paymentAmount: Double.random(in: 1000...4000)
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "Random Test Servicer",
                servicerAddress: "Random Address, Test City, TS 12345",
                customerServicePhone: "(555) 000-0000"
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "Random Test Statement",
                pageCount: Int.random(in: 1...5),
                confidence: Double.random(in: 0.7...0.98)
            )
        )
    }
}

// MARK: - Supporting Structures

extension MortgageTestDataGenerator {

    enum LoanType {
        case fixedRate
        case adjustableRate
        case interestOnly
        case balloon
    }

    struct LoanDetails {
        let loanNumber: String
        let originalAmount: Double
        let currentBalance: Double
        let interestRate: Double
        let originalInterestRate: Double
        let adjustmentDate: Date?
        let nextAdjustmentDate: Date?
        let interestRateCap: InterestRateCap?
        let loanType: LoanType
        let termInMonths: Int
        let remainingTermInMonths: Int
        let maturityDate: Date
        let propertyAddress: String
        let interestOnlyEndDate: Date?

        init(loanNumber: String, originalAmount: Double, currentBalance: Double,
             interestRate: Double, originalInterestRate: Double, adjustmentDate: Date?,
             nextAdjustmentDate: Date?, interestRateCap: InterestRateCap?,
             loanType: LoanType, termInMonths: Int, remainingTermInMonths: Int,
             maturityDate: Date, propertyAddress: String, interestOnlyEndDate: Date? = nil) {
            self.loanNumber = loanNumber
            self.originalAmount = originalAmount
            self.currentBalance = currentBalance
            self.interestRate = interestRate
            self.originalInterestRate = originalInterestRate
            self.adjustmentDate = adjustmentDate
            self.nextAdjustmentDate = nextAdjustmentDate
            self.interestRateCap = interestRateCap
            self.loanType = loanType
            self.termInMonths = termInMonths
            self.remainingTermInMonths = remainingTermInMonths
            self.maturityDate = maturityDate
            self.propertyAddress = propertyAddress
            self.interestOnlyEndDate = interestOnlyEndDate
        }
    }

    struct InterestRateCap {
        let initialCap: Double
        let periodicCap: Double
        let lifetimeCap: Double
    }
}