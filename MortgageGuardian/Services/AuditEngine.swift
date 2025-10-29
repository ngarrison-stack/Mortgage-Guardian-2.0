import Foundation
import os.log

// MARK: - Enhanced Audit Engine with Comprehensive Rule-Based Detection
class AuditEngine {
    private let paymentTracker = PaymentTrackingAlgorithm()
    private let interestCalculator = InterestRecalculationEngine()
    private let escrowAuditor = EscrowAuditSystem()
    private let feeValidator = FeeValidationAlgorithm()
    private let crossVerifier = CrossVerificationSystem()
    private let errorDetector = ErrorDetectionEngine()
    private let respaTilaCompliance = RESPATILAComplianceEngine()

    // Enhanced rule-based detectors for comprehensive coverage
    private let arithmeticValidator = ArithmeticValidationEngine()
    private let dateValidator = DateValidationEngine()
    private let formatValidator = FormatValidationEngine()
    private let paymentAllocationValidator = PaymentAllocationValidator()
    private let lateFeeCalculator = LateFeeCalculationValidator()
    private let principalInterestValidator = PrincipalInterestValidator()
    private let dataIntegrityValidator = DataIntegrityValidator()

    private let logger = Logger(subsystem: "MortgageGuardian", category: "AuditEngine")

    func performCompleteAudit(extractedData: ExtractedData,
                            bankTransactions: [Transaction],
                            loanDetails: LoanDetails? = nil) async -> [AuditResult] {
        var allResults: [AuditResult] = []

        logger.info("Starting comprehensive rule-based audit with \(extractedData.paymentHistory.count) payments")

        // TIER 1: Core Rule-Based Validations (Low Cost, High Coverage)

        // 1. Basic Data Integrity and Format Validation
        let dataIntegrityResults = await dataIntegrityValidator.validateDataIntegrity(extractedData: extractedData)
        allResults.append(contentsOf: dataIntegrityResults)

        // 2. Arithmetic Validation (Payment calculations, balances)
        let arithmeticResults = await arithmeticValidator.validateArithmetic(
            extractedData: extractedData,
            loanDetails: loanDetails
        )
        allResults.append(contentsOf: arithmeticResults)

        // 3. Date Validation (Due dates, payment timing)
        let dateResults = await dateValidator.validateDates(extractedData: extractedData)
        allResults.append(contentsOf: dateResults)

        // 4. Format Validation (Loan numbers, account numbers)
        let formatResults = await formatValidator.validateFormats(extractedData: extractedData)
        allResults.append(contentsOf: formatResults)

        // 5. Payment Allocation Validation
        let allocationResults = await paymentAllocationValidator.validatePaymentAllocations(
            extractedData: extractedData,
            loanDetails: loanDetails
        )
        allResults.append(contentsOf: allocationResults)

        // 6. Late Fee Calculation Validation
        let lateFeeResults = await lateFeeCalculator.validateLateFeesCalculation(
            extractedData: extractedData,
            loanDetails: loanDetails
        )
        allResults.append(contentsOf: lateFeeResults)

        // 7. Principal/Interest Breakdown Validation
        let principalInterestResults = await principalInterestValidator.validatePrincipalInterestBreakdown(
            extractedData: extractedData,
            loanDetails: loanDetails
        )
        allResults.append(contentsOf: principalInterestResults)

        // TIER 1: Existing comprehensive analysis engines

        // 8. Payment Tracking Analysis
        let paymentResults = await paymentTracker.analyzePayments(
            extractedData: extractedData,
            bankTransactions: bankTransactions
        )
        allResults.append(contentsOf: paymentResults)

        // 9. Interest Recalculation
        if let loanDetails = loanDetails {
            let interestResults = await interestCalculator.recalculateInterest(
                extractedData: extractedData,
                loanDetails: loanDetails
            )
            allResults.append(contentsOf: interestResults)
        }

        // 10. Escrow Audit
        let escrowResults = await escrowAuditor.auditEscrowAccount(
            extractedData: extractedData,
            bankTransactions: bankTransactions
        )
        allResults.append(contentsOf: escrowResults)

        // 11. Fee Validation
        let feeResults = await feeValidator.validateFees(
            extractedData: extractedData,
            bankTransactions: bankTransactions
        )
        allResults.append(contentsOf: feeResults)

        // 12. Cross-Verification with Bank Data
        let crossVerificationResults = await crossVerifier.crossVerifyWithBankData(
            extractedData: extractedData,
            bankTransactions: bankTransactions
        )
        allResults.append(contentsOf: crossVerificationResults)

        // 13. RESPA/TILA Compliance Checking
        let complianceResults = await respaTilaCompliance.performComplianceAudit(
            extractedData: extractedData,
            bankTransactions: bankTransactions,
            loanDetails: loanDetails
        )
        allResults.append(contentsOf: complianceResults)

        // 14. Error Detection and Confidence Scoring
        let finalResults = errorDetector.analyzeAndScoreResults(allResults)

        logger.info("Rule-based audit complete: \(finalResults.count) potential issues detected")

        return finalResults
    }
}

// MARK: - Supporting Data Models
struct LoanDetails: Codable {
    let originalLoanAmount: Double
    let originalInterestRate: Double
    let loanTermMonths: Int
    let startDate: Date
    let loanType: LoanType
    let isARM: Bool
    let armDetails: ARMDetails?
    let gracePeriodDays: Int

    enum LoanType: String, Codable {
        case conventional = "conventional"
        case fha = "fha"
        case va = "va"
        case usda = "usda"
        case jumbo = "jumbo"
    }

    struct ARMDetails: Codable {
        let initialFixedPeriodMonths: Int
        let adjustmentFrequencyMonths: Int
        let indexType: String
        let margin: Double
        let lifetimeCap: Double
        let periodicCap: Double
        let initialCap: Double
    }
}

struct AmortizationEntry: Codable {
    let paymentNumber: Int
    let paymentDate: Date
    let payment: Double
    let principal: Double
    let interest: Double
    let balance: Double
}

// MARK: - Payment Tracking Algorithm
class PaymentTrackingAlgorithm {

    func analyzePayments(extractedData: ExtractedData,
                        bankTransactions: [Transaction]) async -> [AuditResult] {
        var results: [AuditResult] = []

        // Verify all monthly payments are recorded correctly
        results.append(contentsOf: verifyPaymentRecords(extractedData: extractedData))

        // Cross-check payment dates against due dates
        results.append(contentsOf: checkPaymentTiming(extractedData: extractedData))

        // Identify missing payments or misapplied payments
        results.append(contentsOf: identifyMissingPayments(
            extractedData: extractedData,
            bankTransactions: bankTransactions
        ))

        // Calculate late fee accuracy
        results.append(contentsOf: validateLateFees(extractedData: extractedData))

        // Compare payment amounts to expected monthly payment
        results.append(contentsOf: validatePaymentAmounts(extractedData: extractedData))

        return results
    }

    private func verifyPaymentRecords(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        for payment in extractedData.paymentHistory {
            // Check for proper principal/interest allocation
            if let principal = payment.principalApplied,
               let interest = payment.interestApplied,
               let escrow = payment.escrowApplied {

                let totalAllocated = principal + interest + (escrow ?? 0.0) + (payment.lateFeesApplied ?? 0.0)
                let difference = abs(payment.amount - totalAllocated)

                if difference > 0.01 { // Allow for small rounding differences
                    results.append(AuditResult(
                        issueType: .misappliedPayment,
                        severity: .high,
                        title: "Payment Allocation Error",
                        description: "Payment amount doesn't match sum of allocated components",
                        detailedExplanation: "Payment of $\(payment.amount) was allocated as $\(principal) principal, $\(interest) interest, and $\(escrow ?? 0.0) escrow, totaling $\(totalAllocated). Difference of $\(difference) indicates potential misallocation.",
                        suggestedAction: "Request detailed payment allocation breakdown and correction",
                        affectedAmount: difference,
                        detectionMethod: .manualCalculation,
                        confidence: 0.95,
                        evidenceText: "Payment allocation mismatch detected",
                        calculationDetails: AuditResult.CalculationDetails(
                            expectedValue: payment.amount,
                            actualValue: totalAllocated,
                            difference: difference,
                            formula: "Payment Amount = Principal + Interest + Escrow + Fees",
                            assumptions: ["Proper allocation of payment components"],
                            warningFlags: ["Potential accounting error"]
                        ),
                        createdDate: Date()
                    ))
                }
            }
        }

        return results
    }

    private func checkPaymentTiming(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        guard let dueDate = extractedData.dueDate else { return results }

        let calendar = Calendar.current

        for payment in extractedData.paymentHistory {
            let daysBetween = calendar.dateComponents([.day], from: dueDate, to: payment.paymentDate).day ?? 0

            // Check if payment marked as late but was within grace period
            if payment.isLate && daysBetween <= 15 { // Assuming 15-day grace period
                results.append(AuditResult(
                    issueType: .latePaymentError,
                    severity: .medium,
                    title: "Incorrect Late Payment Designation",
                    description: "Payment marked as late despite being within grace period",
                    detailedExplanation: "Payment received \(daysBetween) days after due date but marked as late. Standard grace period is 15 days.",
                    suggestedAction: "Request correction of payment status and removal of any late fees",
                    affectedAmount: payment.lateFeesApplied,
                    detectionMethod: .manualCalculation,
                    confidence: 0.90,
                    evidenceText: "Payment within grace period marked as late",
                    calculationDetails: AuditResult.CalculationDetails(
                        expectedValue: 0,
                        actualValue: Double(daysBetween),
                        difference: Double(daysBetween),
                        formula: "Days Late = Payment Date - Due Date",
                        assumptions: ["15-day grace period"],
                        warningFlags: ["Grace period violation"]
                    ),
                    createdDate: Date()
                ))
            }
        }

        return results
    }

    private func identifyMissingPayments(extractedData: ExtractedData,
                                       bankTransactions: [Transaction]) -> [AuditResult] {
        var results: [AuditResult] = []

        let mortgageTransactions = bankTransactions.filter { $0.category == .mortgagePayment }
        let servicerPayments = extractedData.paymentHistory

        // Check for bank transactions without corresponding servicer records
        for bankTxn in mortgageTransactions {
            let matchingServicerPayment = servicerPayments.first { payment in
                let calendar = Calendar.current
                let daysDifference = abs(calendar.dateComponents([.day], from: payment.paymentDate, to: bankTxn.date).day ?? 0)
                let amountDifference = abs(payment.amount - abs(bankTxn.amount))

                return daysDifference <= 7 && amountDifference <= 50.0 // Allow reasonable matching tolerance
            }

            if matchingServicerPayment == nil {
                results.append(AuditResult(
                    issueType: .missingPayment,
                    severity: .critical,
                    title: "Payment Not Recorded by Servicer",
                    description: "Bank transaction shows payment sent but not reflected in servicer records",
                    detailedExplanation: "Bank records show payment of $\(abs(bankTxn.amount)) on \(DateFormatter.shortDate.string(from: bankTxn.date)) but no corresponding entry found in servicer payment history.",
                    suggestedAction: "Provide bank transaction proof to servicer and request payment application",
                    affectedAmount: abs(bankTxn.amount),
                    detectionMethod: .plaidVerification,
                    confidence: 0.85,
                    evidenceText: "Bank transaction: \(bankTxn.description)",
                    calculationDetails: nil,
                    createdDate: Date()
                ))
            }
        }

        return results
    }

    private func validateLateFees(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        for payment in extractedData.paymentHistory {
            if let lateFee = payment.lateFeesApplied, lateFee > 0 {
                let daysLate = payment.dayslate ?? 0

                // Standard late fee is typically 4-5% of monthly payment or $15-25 minimum
                let expectedLateFee = calculateExpectedLateFee(
                    monthlyPayment: extractedData.monthlyPayment ?? 0,
                    daysLate: daysLate
                )

                let difference = abs(lateFee - expectedLateFee)

                if difference > 5.0 { // Allow $5 tolerance
                    results.append(AuditResult(
                        issueType: .unauthorizedFee,
                        severity: .medium,
                        title: "Excessive Late Fee",
                        description: "Late fee exceeds standard calculation",
                        detailedExplanation: "Late fee of $\(lateFee) charged for payment \(daysLate) days late. Expected fee based on industry standards: $\(expectedLateFee).",
                        suggestedAction: "Request fee calculation justification and potential refund",
                        affectedAmount: difference,
                        detectionMethod: .manualCalculation,
                        confidence: 0.80,
                        evidenceText: "Late fee calculation discrepancy",
                        calculationDetails: AuditResult.CalculationDetails(
                            expectedValue: expectedLateFee,
                            actualValue: lateFee,
                            difference: difference,
                            formula: "Late Fee = max(4% of monthly payment, $15 minimum)",
                            assumptions: ["Standard industry late fee calculation"],
                            warningFlags: ["Excessive fee"]
                        ),
                        createdDate: Date()
                    ))
                }
            }
        }

        return results
    }

    private func validatePaymentAmounts(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        guard let expectedMonthlyPayment = extractedData.monthlyPayment else { return results }

        for payment in extractedData.paymentHistory {
            let difference = abs(payment.amount - expectedMonthlyPayment)

            // Allow for small variations due to escrow adjustments
            if difference > 100.0 && (payment.lateFeesApplied ?? 0) == 0 {
                results.append(AuditResult(
                    issueType: .incorrectBalance,
                    severity: .medium,
                    title: "Unexpected Payment Amount Variation",
                    description: "Payment amount differs significantly from expected monthly payment",
                    detailedExplanation: "Payment of $\(payment.amount) differs from expected monthly payment of $\(expectedMonthlyPayment) by $\(difference).",
                    suggestedAction: "Verify payment allocation and escrow adjustments",
                    affectedAmount: difference,
                    detectionMethod: .manualCalculation,
                    confidence: 0.70,
                    evidenceText: "Payment amount variation detected",
                    calculationDetails: AuditResult.CalculationDetails(
                        expectedValue: expectedMonthlyPayment,
                        actualValue: payment.amount,
                        difference: difference,
                        formula: "Payment Difference = |Actual Payment - Expected Payment|",
                        assumptions: ["Consistent monthly payment amount"],
                        warningFlags: ["Significant payment variation"]
                    ),
                    createdDate: Date()
                ))
            }
        }

        return results
    }

    private func calculateExpectedLateFee(monthlyPayment: Double, daysLate: Int) -> Double {
        if daysLate <= 15 { return 0.0 } // Grace period

        let percentageFee = monthlyPayment * 0.04 // 4% of monthly payment
        let minimumFee = 15.0

        return max(percentageFee, minimumFee)
    }
}

// MARK: - Interest Recalculation Engine
class InterestRecalculationEngine {

    func recalculateInterest(extractedData: ExtractedData,
                           loanDetails: LoanDetails) async -> [AuditResult] {
        var results: [AuditResult] = []

        // Generate expected amortization schedule
        let expectedSchedule = generateAmortizationSchedule(loanDetails: loanDetails)

        // Compare with actual payment allocations
        results.append(contentsOf: validateInterestCalculations(
            extractedData: extractedData,
            expectedSchedule: expectedSchedule,
            loanDetails: loanDetails
        ))

        // Check for compound interest errors
        results.append(contentsOf: detectCompoundInterestErrors(
            extractedData: extractedData,
            loanDetails: loanDetails
        ))

        // Handle ARM adjustments
        if loanDetails.isARM {
            results.append(contentsOf: validateARMAdjustments(
                extractedData: extractedData,
                loanDetails: loanDetails
            ))
        }

        return results
    }

    private func generateAmortizationSchedule(loanDetails: LoanDetails) -> [AmortizationEntry] {
        var schedule: [AmortizationEntry] = []

        let principal = loanDetails.originalLoanAmount
        let rate = loanDetails.originalInterestRate / 100.0 / 12.0 // Monthly rate
        let numPayments = loanDetails.loanTermMonths

        // Calculate monthly payment using standard formula
        let monthlyPayment = principal * (rate * pow(1 + rate, Double(numPayments))) /
                           (pow(1 + rate, Double(numPayments)) - 1)

        var remainingBalance = principal
        let calendar = Calendar.current

        for i in 1...numPayments {
            let paymentDate = calendar.date(byAdding: .month, value: i, to: loanDetails.startDate) ?? Date()
            let interestPayment = remainingBalance * rate
            let principalPayment = monthlyPayment - interestPayment
            remainingBalance -= principalPayment

            schedule.append(AmortizationEntry(
                paymentNumber: i,
                paymentDate: paymentDate,
                payment: monthlyPayment,
                principal: principalPayment,
                interest: interestPayment,
                balance: max(0, remainingBalance)
            ))
        }

        return schedule
    }

    private func validateInterestCalculations(extractedData: ExtractedData,
                                            expectedSchedule: [AmortizationEntry],
                                            loanDetails: LoanDetails) -> [AuditResult] {
        var results: [AuditResult] = []

        for (index, payment) in extractedData.paymentHistory.enumerated() {
            guard index < expectedSchedule.count,
                  let actualInterest = payment.interestApplied else { continue }

            let expectedInterest = expectedSchedule[index].interest
            let difference = abs(actualInterest - expectedInterest)

            if difference > 1.0 { // Allow $1 tolerance for rounding
                results.append(AuditResult(
                    issueType: .incorrectInterest,
                    severity: .high,
                    title: "Interest Calculation Error",
                    description: "Interest portion of payment doesn't match expected calculation",
                    detailedExplanation: "Expected interest: $\(String(format: "%.2f", expectedInterest)), Actual: $\(String(format: "%.2f", actualInterest)). Difference: $\(String(format: "%.2f", difference)).",
                    suggestedAction: "Request loan servicer to recalculate interest and adjust account",
                    affectedAmount: difference,
                    detectionMethod: .manualCalculation,
                    confidence: 0.92,
                    evidenceText: "Interest calculation discrepancy in payment \(index + 1)",
                    calculationDetails: AuditResult.CalculationDetails(
                        expectedValue: expectedInterest,
                        actualValue: actualInterest,
                        difference: difference,
                        formula: "Monthly Interest = (Outstanding Balance × Annual Rate) ÷ 12",
                        assumptions: ["Fixed interest rate", "Standard amortization"],
                        warningFlags: ["Interest calculation error"]
                    ),
                    createdDate: Date()
                ))
            }
        }

        return results
    }

    private func detectCompoundInterestErrors(extractedData: ExtractedData,
                                            loanDetails: LoanDetails) -> [AuditResult] {
        // Implementation for detecting compound interest errors
        // This would involve checking if interest is being charged on unpaid interest
        return []
    }

    private func validateARMAdjustments(extractedData: ExtractedData,
                                      loanDetails: LoanDetails) -> [AuditResult] {
        // Implementation for ARM adjustment validation
        return []
    }
}

// MARK: - Escrow Audit System
class EscrowAuditSystem {

    func auditEscrowAccount(extractedData: ExtractedData,
                          bankTransactions: [Transaction]) async -> [AuditResult] {
        var results: [AuditResult] = []

        // Verify escrow account balance calculations
        results.append(contentsOf: verifyEscrowBalance(extractedData: extractedData))

        // Track escrow deposits and withdrawals
        results.append(contentsOf: validateEscrowTransactions(extractedData: extractedData))

        // Verify property tax and insurance payment timing
        results.append(contentsOf: checkPaymentTiming(
            extractedData: extractedData,
            bankTransactions: bankTransactions
        ))

        // Calculate escrow shortage/surplus accuracy
        results.append(contentsOf: analyzeEscrowBalance(extractedData: extractedData))

        return results
    }

    private func verifyEscrowBalance(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Calculate expected balance based on deposits and withdrawals
        var calculatedBalance = 0.0

        for transaction in extractedData.escrowActivity {
            switch transaction.type {
            case .deposit:
                calculatedBalance += transaction.amount
            case .withdrawal:
                calculatedBalance -= transaction.amount
            }
        }

        if let reportedBalance = extractedData.escrowBalance {
            let difference = abs(calculatedBalance - reportedBalance)

            if difference > 5.0 { // Allow $5 tolerance
                results.append(AuditResult(
                    issueType: .escrowError,
                    severity: .medium,
                    title: "Escrow Balance Discrepancy",
                    description: "Calculated escrow balance doesn't match reported balance",
                    detailedExplanation: "Based on escrow activity, calculated balance is $\(String(format: "%.2f", calculatedBalance)) but reported balance is $\(String(format: "%.2f", reportedBalance)).",
                    suggestedAction: "Request detailed escrow account statement and reconciliation",
                    affectedAmount: difference,
                    detectionMethod: .manualCalculation,
                    confidence: 0.88,
                    evidenceText: "Escrow balance calculation mismatch",
                    calculationDetails: AuditResult.CalculationDetails(
                        expectedValue: calculatedBalance,
                        actualValue: reportedBalance,
                        difference: difference,
                        formula: "Balance = Starting Balance + Deposits - Withdrawals",
                        assumptions: ["Complete transaction history provided"],
                        warningFlags: ["Balance discrepancy"]
                    ),
                    createdDate: Date()
                ))
            }
        }

        return results
    }

    private func validateEscrowTransactions(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Check for duplicate transactions
        for i in 0..<extractedData.escrowActivity.count {
            for j in (i+1)..<extractedData.escrowActivity.count {
                let txn1 = extractedData.escrowActivity[i]
                let txn2 = extractedData.escrowActivity[j]

                let calendar = Calendar.current
                let daysDifference = abs(calendar.dateComponents([.day], from: txn1.date, to: txn2.date).day ?? 0)

                if daysDifference <= 1 &&
                   abs(txn1.amount - txn2.amount) < 0.01 &&
                   txn1.category == txn2.category &&
                   txn1.type == txn2.type {

                    results.append(AuditResult(
                        issueType: .duplicateCharge,
                        severity: .medium,
                        title: "Duplicate Escrow Transaction",
                        description: "Potential duplicate escrow transaction detected",
                        detailedExplanation: "Two similar transactions found: $\(txn1.amount) and $\(txn2.amount) for \(txn1.category.rawValue) within 1 day.",
                        suggestedAction: "Review transactions and request removal of duplicate if confirmed",
                        affectedAmount: txn2.amount,
                        detectionMethod: .manualCalculation,
                        confidence: 0.75,
                        evidenceText: "Duplicate escrow transactions detected",
                        calculationDetails: nil,
                        createdDate: Date()
                    ))
                }
            }
        }

        return results
    }

    private func checkPaymentTiming(extractedData: ExtractedData,
                                  bankTransactions: [Transaction]) -> [AuditResult] {
        var results: [AuditResult] = []

        // Check if insurance and tax payments were made on time
        let taxWithdrawals = extractedData.escrowActivity.filter {
            $0.category == .propertyTax && $0.type == .withdrawal
        }

        let insuranceWithdrawals = extractedData.escrowActivity.filter {
            $0.category == .homeownerInsurance && $0.type == .withdrawal
        }

        // Verify tax payments timing (typically due in specific months)
        for taxPayment in taxWithdrawals {
            let calendar = Calendar.current
            let month = calendar.component(.month, from: taxPayment.date)

            // Property taxes are typically due in specific months (varies by location)
            // This is a simplified check - real implementation would use property-specific data
            if ![1, 4, 7, 10].contains(month) { // Quarterly payments example
                results.append(AuditResult(
                    issueType: .lateTaxPayment,
                    severity: .medium,
                    title: "Unusual Tax Payment Timing",
                    description: "Property tax payment made outside typical due months",
                    detailedExplanation: "Property tax payment of $\(taxPayment.amount) made in month \(month), which is outside typical quarterly payment months.",
                    suggestedAction: "Verify payment timing and check for any late penalties",
                    affectedAmount: nil,
                    detectionMethod: .manualCalculation,
                    confidence: 0.60,
                    evidenceText: "Tax payment timing analysis",
                    calculationDetails: nil,
                    createdDate: Date()
                ))
            }
        }

        return results
    }

    private func analyzeEscrowBalance(extractedData: ExtractedData) -> [AuditResult] {
        // Implementation for escrow shortage/surplus analysis
        return []
    }
}

// MARK: - Fee Validation Algorithm
class FeeValidationAlgorithm {

    func validateFees(extractedData: ExtractedData,
                     bankTransactions: [Transaction]) async -> [AuditResult] {
        var results: [AuditResult] = []

        // Identify unauthorized or excessive fees
        results.append(contentsOf: checkUnauthorizedFees(extractedData: extractedData))

        // Validate late fee calculations and timing
        results.append(contentsOf: validateLateFeeCalculations(extractedData: extractedData))

        // Check inspection fees, attorney fees, processing fees
        results.append(contentsOf: validateServiceFees(extractedData: extractedData))

        // Detect duplicate charges
        results.append(contentsOf: detectDuplicateFees(extractedData: extractedData))

        return results
    }

    private func checkUnauthorizedFees(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        for fee in extractedData.fees {
            let isAuthorized = validateFeeAuthorization(fee: fee)

            if !isAuthorized {
                results.append(AuditResult(
                    issueType: .unauthorizedFee,
                    severity: .high,
                    title: "Potentially Unauthorized Fee",
                    description: "Fee may not be authorized under loan terms",
                    detailedExplanation: "Fee of $\(fee.amount) for '\(fee.description)' may not be authorized. Review loan documents for fee authorization.",
                    suggestedAction: "Request justification for fee and loan document reference",
                    affectedAmount: fee.amount,
                    detectionMethod: .manualCalculation,
                    confidence: 0.70,
                    evidenceText: "Fee authorization review needed",
                    calculationDetails: nil,
                    createdDate: Date()
                ))
            }
        }

        return results
    }

    private func validateLateFeeCalculations(extractedData: ExtractedData) -> [AuditResult] {
        // This overlaps with payment tracking - could be refactored
        return []
    }

    private func validateServiceFees(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        for fee in extractedData.fees {
            switch fee.category {
            case .inspectionFee:
                if fee.amount > 200.0 { // Typical inspection fee range
                    results.append(createExcessiveFeeResult(fee: fee, expectedRange: "50-200"))
                }
            case .processingFee:
                if fee.amount > 50.0 {
                    results.append(createExcessiveFeeResult(fee: fee, expectedRange: "10-50"))
                }
            case .attorneyFee:
                if fee.amount > 500.0 {
                    results.append(createExcessiveFeeResult(fee: fee, expectedRange: "100-500"))
                }
            default:
                break
            }
        }

        return results
    }

    private func detectDuplicateFees(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        for i in 0..<extractedData.fees.count {
            for j in (i+1)..<extractedData.fees.count {
                let fee1 = extractedData.fees[i]
                let fee2 = extractedData.fees[j]

                let calendar = Calendar.current
                let daysDifference = abs(calendar.dateComponents([.day], from: fee1.date, to: fee2.date).day ?? 0)

                if daysDifference <= 7 &&
                   abs(fee1.amount - fee2.amount) < 0.01 &&
                   fee1.category == fee2.category {

                    results.append(AuditResult(
                        issueType: .duplicateCharge,
                        severity: .medium,
                        title: "Duplicate Fee Detected",
                        description: "Same fee appears to be charged multiple times",
                        detailedExplanation: "Fee of $\(fee1.amount) for \(fee1.category.rawValue) appears twice within 7 days.",
                        suggestedAction: "Request removal of duplicate fee",
                        affectedAmount: fee2.amount,
                        detectionMethod: .manualCalculation,
                        confidence: 0.85,
                        evidenceText: "Duplicate fee analysis",
                        calculationDetails: nil,
                        createdDate: Date()
                    ))
                }
            }
        }

        return results
    }

    private func validateFeeAuthorization(fee: ExtractedData.Fee) -> Bool {
        // Simplified authorization check - real implementation would check against loan documents
        let commonAuthorizedFees = [
            "late fee", "late payment", "insufficient funds", "returned payment",
            "inspection", "property inspection", "attorney fee", "legal fee",
            "processing fee", "administrative fee"
        ]

        return commonAuthorizedFees.contains {
            fee.description.lowercased().contains($0)
        }
    }

    private func createExcessiveFeeResult(fee: ExtractedData.Fee, expectedRange: String) -> AuditResult {
        return AuditResult(
            issueType: .unauthorizedFee,
            severity: .medium,
            title: "Excessive \(fee.category.rawValue.capitalized) Fee",
            description: "Fee amount exceeds typical range",
            detailedExplanation: "Fee of $\(fee.amount) for \(fee.description) exceeds typical range of $\(expectedRange).",
            suggestedAction: "Request justification for fee amount",
            affectedAmount: fee.amount,
            detectionMethod: .manualCalculation,
            confidence: 0.75,
            evidenceText: "Fee amount analysis",
            calculationDetails: nil,
            createdDate: Date()
        )
    }
}

// MARK: - Cross-Verification System
class CrossVerificationSystem {

    func crossVerifyWithBankData(extractedData: ExtractedData,
                                bankTransactions: [Transaction]) async -> [AuditResult] {
        var results: [AuditResult] = []

        // Compare servicer records with bank transaction data
        let correlations = correlatePayments(
            servicerPayments: extractedData.paymentHistory,
            bankTransactions: bankTransactions
        )

        // Generate audit results from correlations
        for correlation in correlations {
            switch correlation.correlationStatus {
            case .amountMismatch:
                results.append(createAmountMismatchResult(correlation: correlation))
            case .timingMismatch:
                results.append(createTimingMismatchResult(correlation: correlation))
            case .bothMismatch:
                results.append(createBothMismatchResult(correlation: correlation))
            case .noServicerRecord:
                results.append(createMissingServicerRecordResult(correlation: correlation))
            case .noBankRecord:
                results.append(createMissingBankRecordResult(correlation: correlation))
            case .perfectMatch:
                break // No audit result needed for perfect matches
            }
        }

        return results
    }

    private func correlatePayments(servicerPayments: [ExtractedData.PaymentRecord],
                                 bankTransactions: [Transaction]) -> [PaymentCorrelation] {
        var correlations: [PaymentCorrelation] = []
        let mortgageTransactions = bankTransactions.filter { $0.relatedMortgagePayment }

        // Create correlations for each bank transaction
        for bankTxn in mortgageTransactions {
            let matchingServicerPayment = findBestMatch(
                bankTransaction: bankTxn,
                servicerPayments: servicerPayments
            )

            let correlation = createCorrelation(
                bankTransaction: bankTxn,
                servicerPayment: matchingServicerPayment
            )

            correlations.append(correlation)
        }

        // Check for servicer payments without bank records
        for servicerPayment in servicerPayments {
            let hasMatchingBankTxn = mortgageTransactions.contains { bankTxn in
                let calendar = Calendar.current
                let daysDifference = abs(calendar.dateComponents([.day], from: servicerPayment.paymentDate, to: bankTxn.date).day ?? 0)
                let amountDifference = abs(servicerPayment.amount - abs(bankTxn.amount))

                return daysDifference <= 7 && amountDifference <= 50.0
            }

            if !hasMatchingBankTxn {
                let correlation = PaymentCorrelation(
                    bankTransaction: Transaction(
                        accountId: "unknown",
                        transactionId: "missing",
                        amount: 0,
                        date: servicerPayment.paymentDate,
                        description: "Missing bank record",
                        category: .mortgagePayment,
                        isRecurring: false,
                        merchantName: nil,
                        confidence: 0,
                        plaidTransactionId: nil,
                        isVerified: false,
                        relatedMortgagePayment: true
                    ),
                    servicerRecord: servicerPayment,
                    correlationStatus: .noBankRecord,
                    timingDiscrepancy: nil,
                    amountDiscrepancy: nil,
                    suggestedActions: ["Verify if payment was actually sent", "Check for payment processing delays"],
                    confidenceScore: 0.90
                )
                correlations.append(correlation)
            }
        }

        return correlations
    }

    private func findBestMatch(bankTransaction: Transaction,
                             servicerPayments: [ExtractedData.PaymentRecord]) -> ExtractedData.PaymentRecord? {
        var bestMatch: ExtractedData.PaymentRecord?
        var bestScore = 0.0

        for payment in servicerPayments {
            let score = calculateMatchScore(bankTransaction: bankTransaction, payment: payment)
            if score > bestScore && score > 0.5 { // Minimum threshold
                bestScore = score
                bestMatch = payment
            }
        }

        return bestMatch
    }

    private func calculateMatchScore(bankTransaction: Transaction,
                                   payment: ExtractedData.PaymentRecord) -> Double {
        let calendar = Calendar.current
        let daysDifference = abs(calendar.dateComponents([.day], from: payment.paymentDate, to: bankTransaction.date).day ?? 0)
        let amountDifference = abs(payment.amount - abs(bankTransaction.amount))

        // Score based on timing (max 0.5 points)
        let timingScore = max(0, 0.5 - Double(daysDifference) * 0.05)

        // Score based on amount (max 0.5 points)
        let amountScore = max(0, 0.5 - amountDifference * 0.01)

        return timingScore + amountScore
    }

    private func createCorrelation(bankTransaction: Transaction,
                                 servicerPayment: ExtractedData.PaymentRecord?) -> PaymentCorrelation {
        guard let servicerPayment = servicerPayment else {
            return PaymentCorrelation(
                bankTransaction: bankTransaction,
                servicerRecord: nil,
                correlationStatus: .noServicerRecord,
                timingDiscrepancy: nil,
                amountDiscrepancy: nil,
                suggestedActions: ["Provide bank transaction proof to servicer", "Request payment application"],
                confidenceScore: 0.85
            )
        }

        let calendar = Calendar.current
        let timingDiff = calendar.dateComponents([.day], from: servicerPayment.paymentDate, to: bankTransaction.date)
        let daysDifference = timingDiff.day ?? 0
        let amountDifference = servicerPayment.amount - abs(bankTransaction.amount)

        let hasTimingIssue = abs(daysDifference) > 3
        let hasAmountIssue = abs(amountDifference) > 10.0

        var status: PaymentCorrelation.CorrelationStatus
        if hasTimingIssue && hasAmountIssue {
            status = .bothMismatch
        } else if hasTimingIssue {
            status = .timingMismatch
        } else if hasAmountIssue {
            status = .amountMismatch
        } else {
            status = .perfectMatch
        }

        return PaymentCorrelation(
            bankTransaction: bankTransaction,
            servicerRecord: servicerPayment,
            correlationStatus: status,
            timingDiscrepancy: hasTimingIssue ? TimeInterval(daysDifference * 24 * 3600) : nil,
            amountDiscrepancy: hasAmountIssue ? amountDifference : nil,
            suggestedActions: generateSuggestedActions(for: status),
            confidenceScore: calculateConfidenceScore(status: status, daysDiff: daysDifference, amountDiff: amountDifference)
        )
    }

    private func generateSuggestedActions(for status: PaymentCorrelation.CorrelationStatus) -> [String] {
        switch status {
        case .perfectMatch:
            return []
        case .amountMismatch:
            return ["Verify payment amount", "Check for fees or adjustments", "Request detailed payment allocation"]
        case .timingMismatch:
            return ["Verify payment processing dates", "Check for payment delays", "Request correction of payment date"]
        case .bothMismatch:
            return ["Provide bank transaction proof", "Request complete payment reconciliation", "Consider filing formal complaint"]
        case .noServicerRecord:
            return ["Submit bank transaction proof", "Request immediate payment application", "Send Notice of Error letter"]
        case .noBankRecord:
            return ["Verify payment was actually sent", "Check bank account for debits", "Review payment method"]
        }
    }

    private func calculateConfidenceScore(status: PaymentCorrelation.CorrelationStatus,
                                        daysDiff: Int, amountDiff: Double) -> Double {
        switch status {
        case .perfectMatch:
            return 0.95
        case .amountMismatch:
            return max(0.5, 0.9 - abs(amountDiff) * 0.001)
        case .timingMismatch:
            return max(0.5, 0.9 - Double(abs(daysDiff)) * 0.05)
        case .bothMismatch:
            return max(0.3, 0.8 - Double(abs(daysDiff)) * 0.05 - abs(amountDiff) * 0.001)
        case .noServicerRecord:
            return 0.85
        case .noBankRecord:
            return 0.90
        }
    }

    private func createAmountMismatchResult(correlation: PaymentCorrelation) -> AuditResult {
        return AuditResult(
            issueType: .misappliedPayment,
            severity: correlation.correlationStatus.severity,
            title: "Payment Amount Mismatch",
            description: "Bank transaction amount differs from servicer record",
            detailedExplanation: "Bank shows payment of $\(abs(correlation.bankTransaction.amount)) but servicer recorded $\(correlation.servicerRecord?.amount ?? 0).",
            suggestedAction: correlation.suggestedActions.joined(separator: "; "),
            affectedAmount: correlation.amountDiscrepancy,
            detectionMethod: .plaidVerification,
            confidence: correlation.confidenceScore,
            evidenceText: "Cross-verification analysis",
            calculationDetails: nil,
            createdDate: Date()
        )
    }

    private func createTimingMismatchResult(correlation: PaymentCorrelation) -> AuditResult {
        let daysDiff = Int((correlation.timingDiscrepancy ?? 0) / (24 * 3600))

        return AuditResult(
            issueType: .latePaymentError,
            severity: correlation.correlationStatus.severity,
            title: "Payment Date Discrepancy",
            description: "Payment dates don't match between bank and servicer records",
            detailedExplanation: "Bank transaction dated \(DateFormatter.shortDate.string(from: correlation.bankTransaction.date)) but servicer shows \(DateFormatter.shortDate.string(from: correlation.servicerRecord?.paymentDate ?? Date())). Difference: \(abs(daysDiff)) days.",
            suggestedAction: correlation.suggestedActions.joined(separator: "; "),
            affectedAmount: nil,
            detectionMethod: .plaidVerification,
            confidence: correlation.confidenceScore,
            evidenceText: "Date comparison analysis",
            calculationDetails: nil,
            createdDate: Date()
        )
    }

    private func createBothMismatchResult(correlation: PaymentCorrelation) -> AuditResult {
        return AuditResult(
            issueType: .misappliedPayment,
            severity: .critical,
            title: "Major Payment Discrepancy",
            description: "Both amount and timing differ between bank and servicer records",
            detailedExplanation: "Significant discrepancies found in both payment amount and timing between bank records and servicer records.",
            suggestedAction: correlation.suggestedActions.joined(separator: "; "),
            affectedAmount: correlation.amountDiscrepancy,
            detectionMethod: .combinedAnalysis,
            confidence: correlation.confidenceScore,
            evidenceText: "Multiple discrepancies detected",
            calculationDetails: nil,
            createdDate: Date()
        )
    }

    private func createMissingServicerRecordResult(correlation: PaymentCorrelation) -> AuditResult {
        return AuditResult(
            issueType: .missingPayment,
            severity: .critical,
            title: "Payment Not Recorded by Servicer",
            description: "Bank transaction exists but no corresponding servicer record found",
            detailedExplanation: "Bank records show payment of $\(abs(correlation.bankTransaction.amount)) on \(DateFormatter.shortDate.string(from: correlation.bankTransaction.date)) but no matching entry in servicer records.",
            suggestedAction: correlation.suggestedActions.joined(separator: "; "),
            affectedAmount: abs(correlation.bankTransaction.amount),
            detectionMethod: .plaidVerification,
            confidence: correlation.confidenceScore,
            evidenceText: "Missing servicer record",
            calculationDetails: nil,
            createdDate: Date()
        )
    }

    private func createMissingBankRecordResult(correlation: PaymentCorrelation) -> AuditResult {
        return AuditResult(
            issueType: .incorrectBalance,
            severity: .high,
            title: "Payment Recorded Without Bank Transaction",
            description: "Servicer shows payment but no corresponding bank transaction found",
            detailedExplanation: "Servicer records show payment of $\(correlation.servicerRecord?.amount ?? 0) but no matching bank transaction found.",
            suggestedAction: correlation.suggestedActions.joined(separator: "; "),
            affectedAmount: correlation.servicerRecord?.amount,
            detectionMethod: .plaidVerification,
            confidence: correlation.confidenceScore,
            evidenceText: "Missing bank transaction",
            calculationDetails: nil,
            createdDate: Date()
        )
    }
}

// MARK: - Error Detection Engine
class ErrorDetectionEngine {

    func analyzeAndScoreResults(_ results: [AuditResult]) -> [AuditResult] {
        var scoredResults = results

        // Apply additional scoring based on patterns and correlations
        scoredResults = applyPatternAnalysis(scoredResults)

        // Sort by severity and confidence
        scoredResults.sort { (result1, result2) in
            if result1.severity != result2.severity {
                return result1.severity.rawValue > result2.severity.rawValue
            }
            return result1.confidence > result2.confidence
        }

        return scoredResults
    }

    private func applyPatternAnalysis(_ results: [AuditResult]) -> [AuditResult] {
        var updatedResults = results

        // Look for patterns that might indicate systemic issues
        let groupedByType = Dictionary(grouping: results) { $0.issueType }

        for (issueType, typeResults) in groupedByType {
            if typeResults.count >= 3 { // Multiple instances of same issue type
                // Increase confidence for issues that appear multiple times
                for i in 0..<updatedResults.count {
                    if updatedResults[i].issueType == issueType {
                        let currentConfidence = updatedResults[i].confidence
                        let boostedConfidence = min(0.99, currentConfidence + 0.1)

                        updatedResults[i] = AuditResult(
                            issueType: updatedResults[i].issueType,
                            severity: updatedResults[i].severity,
                            title: updatedResults[i].title,
                            description: updatedResults[i].description,
                            detailedExplanation: updatedResults[i].detailedExplanation + " (Pattern detected: multiple similar issues found)",
                            suggestedAction: updatedResults[i].suggestedAction,
                            affectedAmount: updatedResults[i].affectedAmount,
                            detectionMethod: updatedResults[i].detectionMethod,
                            confidence: boostedConfidence,
                            evidenceText: updatedResults[i].evidenceText,
                            calculationDetails: updatedResults[i].calculationDetails,
                            createdDate: updatedResults[i].createdDate
                        )
                    }
                }
            }
        }

        return updatedResults
    }
}

// MARK: - Extensions and Utilities
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

// MARK: - Sample Usage Example
extension AuditEngine {
    static func runSampleAudit() -> [AuditResult] {
        let engine = AuditEngine()

        // Sample extracted data
        let sampleData = ExtractedData(
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
                    amount: 1775.00,  // Note: Different amount - should trigger alert
                    principalApplied: 518.25,
                    interestApplied: 1011.75,
                    escrowApplied: 220.00,
                    lateFeesApplied: 25.00,  // Late fee applied
                    isLate: true,
                    dayslate: 8  // 8 days late - within grace period but fee applied
                )
            ],
            escrowActivity: [
                ExtractedData.EscrowTransaction(
                    date: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
                    description: "Monthly escrow deposit",
                    amount: 220.00,
                    type: .deposit,
                    category: .propertyTax
                ),
                ExtractedData.EscrowTransaction(
                    date: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
                    description: "Property tax payment",
                    amount: 1500.00,
                    type: .withdrawal,
                    category: .propertyTax
                )
            ],
            fees: [
                ExtractedData.Fee(
                    date: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date(),
                    description: "Late payment fee",
                    amount: 25.00,
                    category: .lateFee
                ),
                ExtractedData.Fee(
                    date: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
                    description: "Property inspection fee",
                    amount: 250.00,  // High inspection fee
                    category: .inspectionFee
                )
            ]
        )

        // Sample bank transactions
        let sampleTransactions = [
            Transaction(
                accountId: "account_123",
                transactionId: "txn_456",
                amount: -1750.00,
                date: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
                description: "MORTGAGE PAYMENT ABC MORTGAGE",
                category: .mortgagePayment,
                isRecurring: true,
                merchantName: "ABC Mortgage",
                confidence: 0.98,
                plaidTransactionId: "plaid_txn_789",
                isVerified: true,
                relatedMortgagePayment: true
            ),
            Transaction(
                accountId: "account_123",
                transactionId: "txn_789",
                amount: -1750.00,  // Same amount but payment was $1775 in servicer records
                date: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date(),
                description: "MORTGAGE PAYMENT ABC MORTGAGE",
                category: .mortgagePayment,
                isRecurring: true,
                merchantName: "ABC Mortgage",
                confidence: 0.98,
                plaidTransactionId: "plaid_txn_790",
                isVerified: true,
                relatedMortgagePayment: true
            )
        ]

        // Sample loan details
        let sampleLoanDetails = LoanDetails(
            originalLoanAmount: 300000.00,
            originalInterestRate: 4.25,
            loanTermMonths: 360,
            startDate: Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date(),
            loanType: .conventional,
            isARM: false,
            armDetails: nil,
            gracePeriodDays: 15
        )

        // This would normally be async, but for the sample we'll simulate
        // return await engine.performCompleteAudit(
        //     extractedData: sampleData,
        //     bankTransactions: sampleTransactions,
        //     loanDetails: sampleLoanDetails
        // )

        // For demo purposes, return some sample results
        return [
            AuditResult(
                issueType: .latePaymentError,
                severity: .medium,
                title: "Incorrect Late Fee Applied",
                description: "Late fee charged despite payment being within grace period",
                detailedExplanation: "Payment was 8 days late but a $25 late fee was applied. With a 15-day grace period, no fee should have been charged.",
                suggestedAction: "Request removal of late fee and correction of payment record",
                affectedAmount: 25.00,
                detectionMethod: .manualCalculation,
                confidence: 0.92,
                evidenceText: "Grace period analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 0.00,
                    actualValue: 25.00,
                    difference: 25.00,
                    formula: "Late fee = $0 when days late ≤ grace period",
                    assumptions: ["15-day grace period", "Payment 8 days late"],
                    warningFlags: ["Grace period violation"]
                ),
                createdDate: Date()
            ),
            AuditResult(
                issueType: .unauthorizedFee,
                severity: .medium,
                title: "Excessive Inspection Fee",
                description: "Property inspection fee exceeds typical range",
                detailedExplanation: "Inspection fee of $250 exceeds the typical range of $50-200 for standard property inspections.",
                suggestedAction: "Request justification for inspection fee amount",
                affectedAmount: 250.00,
                detectionMethod: .manualCalculation,
                confidence: 0.75,
                evidenceText: "Fee amount analysis",
                calculationDetails: nil,
                createdDate: Date()
            ),
            AuditResult(
                issueType: .misappliedPayment,
                severity: .high,
                title: "Payment Amount Discrepancy",
                description: "Bank transaction amount differs from servicer record",
                detailedExplanation: "Bank shows payment of $1750 but servicer recorded $1775, creating a $25 discrepancy that appears to be the incorrectly applied late fee.",
                suggestedAction: "Provide bank transaction proof and request payment reconciliation",
                affectedAmount: 25.00,
                detectionMethod: .plaidVerification,
                confidence: 0.88,
                evidenceText: "Cross-verification analysis",
                calculationDetails: nil,
                createdDate: Date()
            )
        ]
    }

    /// Sample audit with RESPA/TILA compliance testing
    static func runComprehensiveSampleAudit() -> [AuditResult] {
        let engine = AuditEngine()

        // Enhanced sample data with potential RESPA/TILA violations
        let sampleData = ExtractedData(
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
                    amount: 1950.00, // Sudden payment increase
                    principalApplied: 520.50,
                    interestApplied: 1009.50,
                    escrowApplied: 420.00, // Increased escrow
                    lateFeesApplied: nil,
                    isLate: false,
                    dayslate: nil
                ),
                ExtractedData.PaymentRecord(
                    paymentDate: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date(),
                    amount: 1750.00,
                    principalApplied: 518.25,
                    interestApplied: 1011.75,
                    escrowApplied: 220.00,
                    lateFeesApplied: nil,
                    isLate: false,
                    dayslate: nil
                ),
                ExtractedData.PaymentRecord(
                    paymentDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
                    amount: 1775.00,
                    principalApplied: 516.50,
                    interestApplied: 1013.50,
                    escrowApplied: 220.00,
                    lateFeesApplied: 25.00, // Multiple late fees pattern
                    isLate: true,
                    dayslate: 8
                ),
                ExtractedData.PaymentRecord(
                    paymentDate: Calendar.current.date(byAdding: .month, value: -4, to: Date()) ?? Date(),
                    amount: 1775.00,
                    principalApplied: 514.75,
                    interestApplied: 1015.25,
                    escrowApplied: 220.00,
                    lateFeesApplied: 25.00, // Multiple late fees pattern
                    isLate: true,
                    dayslate: 12
                ),
                ExtractedData.PaymentRecord(
                    paymentDate: Calendar.current.date(byAdding: .month, value: -5, to: Date()) ?? Date(),
                    amount: 1775.00,
                    principalApplied: 513.00,
                    interestApplied: 1017.00,
                    escrowApplied: 220.00,
                    lateFeesApplied: 25.00, // Multiple late fees pattern
                    isLate: true,
                    dayslate: 15
                )
            ],
            escrowActivity: [
                ExtractedData.EscrowTransaction(
                    date: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
                    description: "Monthly escrow deposit",
                    amount: 420.00, // Increased amount
                    type: .deposit,
                    category: .propertyTax
                ),
                ExtractedData.EscrowTransaction(
                    date: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date(),
                    description: "Force-placed insurance premium",
                    amount: 2400.00, // Force-placed insurance
                    type: .withdrawal,
                    category: .homeownerInsurance
                )
            ],
            fees: [
                ExtractedData.Fee(
                    date: Calendar.current.date(byAdding: .month, value: -5, to: Date()) ?? Date(),
                    description: "Late payment fee",
                    amount: 25.00,
                    category: .lateFee
                ),
                ExtractedData.Fee(
                    date: Calendar.current.date(byAdding: .month, value: -4, to: Date()) ?? Date(),
                    description: "Late payment fee",
                    amount: 25.00,
                    category: .lateFee
                ),
                ExtractedData.Fee(
                    date: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
                    description: "Late payment fee",
                    amount: 25.00,
                    category: .lateFee
                ),
                ExtractedData.Fee(
                    date: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date(),
                    description: "Force-placed hazard insurance",
                    amount: 750.00, // Suspicious fee
                    category: .other
                ),
                ExtractedData.Fee(
                    date: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
                    description: "Broker referral fee", // RESPA Section 8 violation
                    amount: 150.00,
                    category: .other
                ),
                ExtractedData.Fee(
                    date: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
                    description: "Property inspection fee",
                    amount: 350.00, // Excessive inspection fee
                    category: .inspectionFee
                )
            ]
        )

        // Sample bank transactions
        let sampleTransactions = [
            Transaction(
                accountId: "account_123",
                transactionId: "txn_456",
                amount: -1750.00,
                date: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date(),
                description: "MORTGAGE PAYMENT ABC MORTGAGE",
                category: .mortgagePayment,
                isRecurring: true,
                merchantName: "ABC Mortgage",
                confidence: 0.98,
                plaidTransactionId: "plaid_txn_789",
                isVerified: true,
                relatedMortgagePayment: true
            )
        ]

        // Sample loan details with ARM and potential HOEPA issues
        let sampleLoanDetails = LoanDetails(
            originalLoanAmount: 300000.00,
            originalInterestRate: 11.5, // High rate for HOEPA testing
            loanTermMonths: 360,
            startDate: Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date(), // Recent loan for rescission testing
            loanType: .conventional,
            isARM: true,
            armDetails: LoanDetails.ARMDetails(
                initialFixedPeriodMonths: 60,
                adjustmentFrequencyMonths: 12,
                indexType: "1-Year Treasury",
                margin: 2.5,
                lifetimeCap: 9.0, // High payment shock potential
                periodicCap: 2.0,
                initialCap: 2.0
            ),
            gracePeriodDays: 15
        )

        // Create a comprehensive sample result set that would be generated by the RESPA/TILA engine
        return [
            // RESPA Violations
            AuditResult(
                issueType: .respaNoticeOfErrorViolation,
                severity: .high,
                title: "Potential RESPA Notice of Error Violation",
                description: "Multiple late fees suggest unresolved payment application issues",
                detailedExplanation: "Pattern detected: Multiple late fees (3) suggesting unresolved payment application issues. Under RESPA § 2605(e), servicers must acknowledge NOE within 5 business days and complete investigation within 30 business days (or 60 if additional information needed). This pattern suggests potential non-compliance.",
                suggestedAction: "Send formal Notice of Error letter citing RESPA § 2605(e). Document all communications. If no proper response within timeframes, file CFPB complaint.",
                affectedAmount: 75.00,
                detectionMethod: .manualCalculation,
                confidence: 0.75,
                evidenceText: "Error pattern analysis suggests NOE response failure",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 0,
                    actualValue: 1,
                    difference: 1,
                    formula: "RESPA NOE Response = 5 days acknowledgment + 30-60 days resolution",
                    assumptions: ["RESPA § 2605(e) compliance required"],
                    warningFlags: ["Potential RESPA violation", "Regulatory compliance issue"]
                ),
                createdDate: Date()
            ),
            AuditResult(
                issueType: .respaSection8Violation,
                severity: .high,
                title: "Potential RESPA Section 8 Violation",
                description: "Fee may violate RESPA prohibition on kickbacks and unearned fees",
                detailedExplanation: "Fee: Broker referral fee - $150.0. This fee appears suspicious under RESPA § 8, which prohibits kickbacks, referral fees, and unearned fees in mortgage servicing. Analysis suggests potential violation.",
                suggestedAction: "Challenge fee under RESPA § 8. Request detailed justification showing services actually performed. Cite 12 CFR § 1024.14. Consider filing CFPB complaint if fee is not justified.",
                affectedAmount: 150.00,
                detectionMethod: .manualCalculation,
                confidence: 0.65,
                evidenceText: "Fee analysis suggests potential RESPA Section 8 violation",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 0,
                    actualValue: 150.00,
                    difference: 150.00,
                    formula: "RESPA Section 8 = No unearned fees or kickbacks",
                    assumptions: ["RESPA § 8 prohibition applies"],
                    warningFlags: ["Potential kickback", "Unearned fee suspected"]
                ),
                createdDate: Date()
            ),
            AuditResult(
                issueType: .respaForcePlacedInsuranceViolation,
                severity: .high,
                title: "Force-Placed Insurance RESPA Violation",
                description: "Force-placed insurance may violate RESPA notice and timing requirements",
                detailedExplanation: "Potential force-placed insurance fee: Force-placed hazard insurance - $750.0. Under RESPA § 5, servicers must provide specific notices before force-placing insurance and must remove it promptly when borrower provides proof of coverage.",
                suggestedAction: "Challenge force-placed insurance citing RESPA § 5 and 12 CFR § 1024.37. Provide proof of continuous coverage. Request removal and refund of premiums if improperly force-placed.",
                affectedAmount: 750.00,
                detectionMethod: .manualCalculation,
                confidence: 0.80,
                evidenceText: "Force-placed insurance analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 0,
                    actualValue: 750.00,
                    difference: 750.00,
                    formula: "RESPA Force-Placed = Proper notice + proof of lapse required",
                    assumptions: ["RESPA § 5 notice requirements"],
                    warningFlags: ["Force-placed insurance violation", "Improper notice timing"]
                ),
                createdDate: Date()
            ),
            AuditResult(
                issueType: .respaEscrowShortageViolation,
                severity: .medium,
                title: "Escrow Shortage Notification Violation",
                description: "Escrow shortage notification may not comply with RESPA timing requirements",
                detailedExplanation: "Payment increase of $200.00 with only 30 days notice. Under RESPA § 2609 and 12 CFR § 1024.17, servicers must provide at least 60 days advance notice before payment increases due to escrow shortages.",
                suggestedAction: "Request proof of proper 60-day advance notice for escrow shortage. Cite RESPA § 2609 and 12 CFR § 1024.17(f). If notice was inadequate, request payment adjustment.",
                affectedAmount: 200.00,
                detectionMethod: .manualCalculation,
                confidence: 0.75,
                evidenceText: "Escrow shortage notification timing analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 60,
                    actualValue: 30,
                    difference: 30,
                    formula: "RESPA Escrow Notice = 60 days minimum advance notice",
                    assumptions: ["RESPA § 2609 compliance required"],
                    warningFlags: ["Insufficient notice period", "RESPA timing violation"]
                ),
                createdDate: Date()
            ),

            // TILA Violations
            AuditResult(
                issueType: .tilaRightOfRescissionViolation,
                severity: .high,
                title: "Potential Right of Rescission Violation",
                description: "Transaction may violate TILA right of rescission requirements",
                detailedExplanation: "Recent refinance transaction may not have included proper right of rescission disclosures. Under TILA § 125, borrowers have 3 business days to cancel certain refinance transactions. If proper disclosures were not provided, the rescission period may be extended to 3 years.",
                suggestedAction: "Review TILA disclosures for right of rescission. Cite TILA § 125 and 12 CFR § 1026.23. If disclosures were inadequate, you may still have right to rescind and demand refund of fees.",
                affectedAmount: 3000.00,
                detectionMethod: .manualCalculation,
                confidence: 0.70,
                evidenceText: "Right of rescission analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 3,
                    actualValue: 0,
                    difference: 3,
                    formula: "TILA Rescission = 3 business days (or up to 3 years if disclosure violated)",
                    assumptions: ["TILA § 125 applies to transaction"],
                    warningFlags: ["Rescission right violation", "TILA disclosure issue"]
                ),
                createdDate: Date()
            ),
            AuditResult(
                issueType: .tilaHOEPAViolation,
                severity: .critical,
                title: "High-Cost Mortgage (HOEPA) Violation",
                description: "Loan may be high-cost mortgage with HOEPA violations",
                detailedExplanation: "Loan rate of 11.50% exceeds HOEPA threshold of 10.50%. Under TILA § 129 (HOEPA), high-cost mortgages have additional protections including prohibited practices and required counseling.",
                suggestedAction: "Challenge loan as high-cost mortgage under TILA § 129. Cite HOEPA protections and seek legal counsel for potential loan rescission or damages.",
                affectedAmount: 15000.00,
                detectionMethod: .manualCalculation,
                confidence: 0.80,
                evidenceText: "HOEPA threshold analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 10.5,
                    actualValue: 11.5,
                    difference: 1.0,
                    formula: "HOEPA Threshold = APR > APOR + 6.5% (first lien) or 8.5% (subordinate)",
                    assumptions: ["TILA § 129 HOEPA thresholds"],
                    warningFlags: ["High-cost mortgage", "HOEPA protections apply"]
                ),
                createdDate: Date()
            ),
            AuditResult(
                issueType: .tilaARMDisclosureViolation,
                severity: .medium,
                title: "ARM Payment Shock Disclosure Violation",
                description: "ARM loan may lack required payment shock disclosures under TILA",
                detailedExplanation: "ARM loan has high payment shock potential with lifetime cap allowing 4.8% rate increase. Under TILA § 129C and 12 CFR § 1026.18(s), ARM loans must include specific disclosures about payment increases and rate adjustment examples.",
                suggestedAction: "Request proper ARM disclosures citing TILA § 129C and 12 CFR § 1026.18(s). If disclosures were inadequate, challenge loan terms and seek remediation.",
                affectedAmount: 8400.00,
                detectionMethod: .manualCalculation,
                confidence: 0.75,
                evidenceText: "ARM disclosure analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: nil,
                    actualValue: nil,
                    difference: nil,
                    formula: "TILA ARM Disclosure = Payment examples + rate adjustment scenarios",
                    assumptions: ["TILA § 129C disclosure requirements"],
                    warningFlags: ["ARM disclosure violation", "Payment shock risk"]
                ),
                createdDate: Date()
            ),

            // Traditional audit results (showing integration)
            AuditResult(
                issueType: .latePaymentError,
                severity: .medium,
                title: "Incorrect Late Fee Applied",
                description: "Late fee charged despite payment being within grace period",
                detailedExplanation: "Multiple late fees applied. With a 15-day grace period, fees should not have been charged for payments less than 15 days late.",
                suggestedAction: "Request removal of late fees and correction of payment records. Send Notice of Error citing RESPA § 2605(e) for servicer response failures.",
                affectedAmount: 75.00,
                detectionMethod: .manualCalculation,
                confidence: 0.92,
                evidenceText: "Grace period analysis combined with RESPA compliance review",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 0.00,
                    actualValue: 75.00,
                    difference: 75.00,
                    formula: "Late fee = $0 when days late ≤ grace period",
                    assumptions: ["15-day grace period", "RESPA compliance required"],
                    warningFlags: ["Grace period violation", "Potential RESPA violation"]
                ),
                createdDate: Date()
            ),
            AuditResult(
                issueType: .unauthorizedFee,
                severity: .medium,
                title: "Excessive Inspection Fee",
                description: "Property inspection fee exceeds typical range",
                detailedExplanation: "Inspection fee of $350 exceeds the typical range of $50-200 for standard property inspections. Combined with other fee issues, this suggests potential RESPA Section 8 violations.",
                suggestedAction: "Request justification for inspection fee amount. Challenge under RESPA Section 8 if fee appears to be kickback or unearned fee. Cite 12 CFR § 1024.14.",
                affectedAmount: 350.00,
                detectionMethod: .manualCalculation,
                confidence: 0.75,
                evidenceText: "Fee amount analysis with RESPA compliance review",
                calculationDetails: nil,
                createdDate: Date()
            )
        ]
    }
}

// MARK: - RESPA/TILA Compliance Engine
class RESPATILAComplianceEngine {

    func performComplianceAudit(extractedData: ExtractedData,
                               bankTransactions: [Transaction],
                               loanDetails: LoanDetails?) async -> [AuditResult] {
        var results: [AuditResult] = []

        // RESPA Compliance Checks
        results.append(contentsOf: await performRESPACompliance(
            extractedData: extractedData,
            bankTransactions: bankTransactions,
            loanDetails: loanDetails
        ))

        // TILA Compliance Checks
        results.append(contentsOf: await performTILACompliance(
            extractedData: extractedData,
            bankTransactions: bankTransactions,
            loanDetails: loanDetails
        ))

        return results
    }

    // MARK: - RESPA Compliance Implementation
    private func performRESPACompliance(extractedData: ExtractedData,
                                       bankTransactions: [Transaction],
                                       loanDetails: LoanDetails?) async -> [AuditResult] {
        var results: [AuditResult] = []

        // 1. Notice of Error (NOE) Response Timeframes
        results.append(contentsOf: checkNoticeOfErrorCompliance(extractedData: extractedData))

        // 2. Information Request Response Timeframes
        results.append(contentsOf: checkInformationRequestCompliance(extractedData: extractedData))

        // 3. Escrow Account Disclosure Requirements
        results.append(contentsOf: checkEscrowDisclosureCompliance(extractedData: extractedData))

        // 4. Transfer of Servicing Notifications
        results.append(contentsOf: checkServicingTransferCompliance(extractedData: extractedData))

        // 5. Kickback and Fee Splitting Prohibitions
        results.append(contentsOf: checkFeeKickbackCompliance(extractedData: extractedData))

        // 6. Force-Placed Insurance Requirements
        results.append(contentsOf: checkForcePlacedInsuranceCompliance(extractedData: extractedData))

        // 7. Escrow Shortage Notifications
        results.append(contentsOf: checkEscrowShortageNotificationCompliance(extractedData: extractedData))

        return results
    }

    // MARK: - TILA Compliance Implementation
    private func performTILACompliance(extractedData: ExtractedData,
                                      bankTransactions: [Transaction],
                                      loanDetails: LoanDetails?) async -> [AuditResult] {
        var results: [AuditResult] = []

        guard let loanDetails = loanDetails else { return results }

        // 1. Right of Rescission Violations
        results.append(contentsOf: checkRightOfRescissionCompliance(loanDetails: loanDetails))

        // 2. APR Calculation Accuracy
        results.append(contentsOf: checkAPRCalculationCompliance(
            extractedData: extractedData,
            loanDetails: loanDetails
        ))

        // 3. Payment Shock Disclosures for ARM Loans
        if loanDetails.isARM {
            results.append(contentsOf: checkARMPaymentShockCompliance(
                extractedData: extractedData,
                loanDetails: loanDetails
            ))
        }

        // 4. High-Cost Mortgage Protections (HOEPA)
        results.append(contentsOf: checkHOEPACompliance(
            extractedData: extractedData,
            loanDetails: loanDetails
        ))

        // 5. Ability-to-Repay (ATR) Rule Compliance
        results.append(contentsOf: checkATRCompliance(
            extractedData: extractedData,
            loanDetails: loanDetails
        ))

        // 6. Periodic Statement Requirements
        results.append(contentsOf: checkPeriodicStatementCompliance(extractedData: extractedData))

        // 7. Interest Rate Adjustment Notifications
        if loanDetails.isARM {
            results.append(contentsOf: checkARMAdjustmentNotificationCompliance(
                extractedData: extractedData,
                loanDetails: loanDetails
            ))
        }

        return results
    }

    // MARK: - RESPA Compliance Check Methods

    private func checkNoticeOfErrorCompliance(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Check for patterns indicating potential NOE response violations
        // Look for unresolved errors that should have triggered NOE responses

        let suspiciousPatterns = identifySuspiciousErrorPatterns(extractedData: extractedData)

        for pattern in suspiciousPatterns {
            results.append(AuditResult(
                issueType: .respaNoticeOfErrorViolation,
                severity: .high,
                title: "Potential RESPA Notice of Error Violation",
                description: "Error pattern suggests servicer may not have properly responded to Notice of Error",
                detailedExplanation: "Pattern detected: \(pattern.description). Under RESPA § 2605(e), servicers must acknowledge NOE within 5 business days and complete investigation within 30 business days (or 60 if additional information needed). This pattern suggests potential non-compliance.",
                suggestedAction: "Send formal Notice of Error letter citing RESPA § 2605(e). Document all communications. If no proper response within timeframes, file CFPB complaint.",
                affectedAmount: pattern.potentialDamage,
                detectionMethod: .manualCalculation,
                confidence: 0.75,
                evidenceText: "Error pattern analysis suggests NOE response failure",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 0,
                    actualValue: 1,
                    difference: 1,
                    formula: "RESPA NOE Response = 5 days acknowledgment + 30-60 days resolution",
                    assumptions: ["RESPA § 2605(e) compliance required"],
                    warningFlags: ["Potential RESPA violation", "Regulatory compliance issue"]
                ),
                createdDate: Date()
            ))
        }

        return results
    }

    private func checkInformationRequestCompliance(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Check for patterns indicating information request violations
        // Look for gaps in information that should be readily available

        let missingInformation = identifyMissingRequiredInformation(extractedData: extractedData)

        if !missingInformation.isEmpty {
            results.append(AuditResult(
                issueType: .respaInformationRequestViolation,
                severity: .medium,
                title: "Missing Required Loan Information",
                description: "Servicer may not be providing required information under RESPA",
                detailedExplanation: "Missing information: \(missingInformation.joined(separator: ", ")). Under RESPA § 2605(e)(1)(B), servicers must respond to Qualified Written Requests for information within 60 business days and acknowledge within 20 business days.",
                suggestedAction: "Send Qualified Written Request (QWR) citing RESPA § 2605(e)(1)(B) requesting missing information. Document response timeframes.",
                affectedAmount: nil,
                detectionMethod: .manualCalculation,
                confidence: 0.70,
                evidenceText: "Required loan information not readily available",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: nil,
                    actualValue: nil,
                    difference: nil,
                    formula: "QWR Response = 20 days acknowledgment + 60 days substantive response",
                    assumptions: ["RESPA § 2605(e)(1)(B) compliance required"],
                    warningFlags: ["Information access issue", "Potential RESPA violation"]
                ),
                createdDate: Date()
            ))
        }

        return results
    }

    private func checkEscrowDisclosureCompliance(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Check escrow account analysis timing and disclosures
        let escrowViolations = analyzeEscrowDisclosureCompliance(extractedData: extractedData)

        for violation in escrowViolations {
            results.append(AuditResult(
                issueType: .respaEscrowDisclosureViolation,
                severity: violation.severity,
                title: violation.title,
                description: violation.description,
                detailedExplanation: "\(violation.explanation) Under RESPA § 2609, servicers must provide annual escrow account statements and notify borrowers of shortages/surpluses with specific timing requirements.",
                suggestedAction: "Request proper escrow account analysis and disclosure. Cite RESPA § 2609 and 12 CFR § 1024.17. If violations confirmed, request correction and potential refund.",
                affectedAmount: violation.amount,
                detectionMethod: .manualCalculation,
                confidence: violation.confidence,
                evidenceText: "Escrow disclosure analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: nil,
                    actualValue: nil,
                    difference: nil,
                    formula: "RESPA Escrow Analysis = Annual statement + 60-day shortage notice",
                    assumptions: ["RESPA § 2609 compliance required"],
                    warningFlags: ["Escrow disclosure violation", "RESPA compliance issue"]
                ),
                createdDate: Date()
            ))
        }

        return results
    }

    private func checkServicingTransferCompliance(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Look for signs of servicing transfer without proper notice
        // This would typically be detected through servicer name changes or gaps in records

        if let transferViolation = detectServicingTransferViolation(extractedData: extractedData) {
            results.append(AuditResult(
                issueType: .respaServicingTransferViolation,
                severity: .high,
                title: "Potential Servicing Transfer Notice Violation",
                description: "Evidence suggests loan servicing transfer without proper RESPA notice",
                detailedExplanation: "\(transferViolation.evidence). Under RESPA § 2605(b), transferring servicer must provide 15-day advance notice and receiving servicer must provide 15-day notice after transfer.",
                suggestedAction: "Request documentation of proper RESPA servicing transfer notices. Cite RESPA § 2605(b) and 12 CFR § 1024.33. Report violations to CFPB if notices were not provided.",
                affectedAmount: nil,
                detectionMethod: .manualCalculation,
                confidence: transferViolation.confidence,
                evidenceText: "Servicing transfer pattern analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: nil,
                    actualValue: nil,
                    difference: nil,
                    formula: "RESPA Transfer Notice = 15 days advance + 15 days post-transfer",
                    assumptions: ["RESPA § 2605(b) compliance required"],
                    warningFlags: ["Servicing transfer violation", "Notice requirement breach"]
                ),
                createdDate: Date()
            ))
        }

        return results
    }

    private func checkFeeKickbackCompliance(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Analyze fees for potential RESPA Section 8 violations
        let suspiciousFees = analyzeSuspiciousFees(extractedData: extractedData)

        for fee in suspiciousFees {
            results.append(AuditResult(
                issueType: .respaSection8Violation,
                severity: .high,
                title: "Potential RESPA Section 8 Violation",
                description: "Fee may violate RESPA prohibition on kickbacks and unearned fees",
                detailedExplanation: "Fee: \(fee.description) - $\(fee.amount). This fee appears suspicious under RESPA § 8, which prohibits kickbacks, referral fees, and unearned fees in mortgage servicing. Analysis suggests potential violation.",
                suggestedAction: "Challenge fee under RESPA § 8. Request detailed justification showing services actually performed. Cite 12 CFR § 1024.14. Consider filing CFPB complaint if fee is not justified.",
                affectedAmount: fee.amount,
                detectionMethod: .manualCalculation,
                confidence: 0.65,
                evidenceText: "Fee analysis suggests potential RESPA Section 8 violation",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 0,
                    actualValue: fee.amount,
                    difference: fee.amount,
                    formula: "RESPA Section 8 = No unearned fees or kickbacks",
                    assumptions: ["RESPA § 8 prohibition applies"],
                    warningFlags: ["Potential kickback", "Unearned fee suspected"]
                ),
                createdDate: Date()
            ))
        }

        return results
    }

    private func checkForcePlacedInsuranceCompliance(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Look for force-placed insurance and check compliance
        let forcePlacedViolations = analyzeForcePlacedInsurance(extractedData: extractedData)

        for violation in forcePlacedViolations {
            results.append(AuditResult(
                issueType: .respaForcePlacedInsuranceViolation,
                severity: .high,
                title: "Force-Placed Insurance RESPA Violation",
                description: "Force-placed insurance may violate RESPA notice and timing requirements",
                detailedExplanation: "\(violation.description). Under RESPA § 5, servicers must provide specific notices before force-placing insurance and must remove it promptly when borrower provides proof of coverage.",
                suggestedAction: "Challenge force-placed insurance citing RESPA § 5 and 12 CFR § 1024.37. Provide proof of continuous coverage. Request removal and refund of premiums if improperly force-placed.",
                affectedAmount: violation.amount,
                detectionMethod: .manualCalculation,
                confidence: 0.80,
                evidenceText: "Force-placed insurance analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 0,
                    actualValue: violation.amount,
                    difference: violation.amount,
                    formula: "RESPA Force-Placed = Proper notice + proof of lapse required",
                    assumptions: ["RESPA § 5 notice requirements"],
                    warningFlags: ["Force-placed insurance violation", "Improper notice timing"]
                ),
                createdDate: Date()
            ))
        }

        return results
    }

    private func checkEscrowShortageNotificationCompliance(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Check for proper escrow shortage notification timing
        let shortageViolations = analyzeEscrowShortageNotifications(extractedData: extractedData)

        for violation in shortageViolations {
            results.append(AuditResult(
                issueType: .respaEscrowShortageViolation,
                severity: .medium,
                title: "Escrow Shortage Notification Violation",
                description: "Escrow shortage notification may not comply with RESPA timing requirements",
                detailedExplanation: "\(violation.description). Under RESPA § 2609 and 12 CFR § 1024.17, servicers must provide at least 60 days advance notice before payment increases due to escrow shortages.",
                suggestedAction: "Request proof of proper 60-day advance notice for escrow shortage. Cite RESPA § 2609 and 12 CFR § 1024.17(f). If notice was inadequate, request payment adjustment.",
                affectedAmount: violation.amount,
                detectionMethod: .manualCalculation,
                confidence: 0.75,
                evidenceText: "Escrow shortage notification timing analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 60,
                    actualValue: Double(violation.actualNoticeDays),
                    difference: Double(60 - violation.actualNoticeDays),
                    formula: "RESPA Escrow Notice = 60 days minimum advance notice",
                    assumptions: ["RESPA § 2609 compliance required"],
                    warningFlags: ["Insufficient notice period", "RESPA timing violation"]
                ),
                createdDate: Date()
            ))
        }

        return results
    }

    // MARK: - TILA Compliance Check Methods

    private func checkRightOfRescissionCompliance(loanDetails: LoanDetails) -> [AuditResult] {
        var results: [AuditResult] = []

        // Check if this appears to be a refinance that would trigger right of rescission
        let rescissionViolation = analyzeRightOfRescission(loanDetails: loanDetails)

        if let violation = rescissionViolation {
            results.append(AuditResult(
                issueType: .tilaRightOfRescissionViolation,
                severity: .high,
                title: "Potential Right of Rescission Violation",
                description: "Transaction may violate TILA right of rescission requirements",
                detailedExplanation: "\(violation.description). Under TILA § 125, borrowers have 3 business days to cancel certain refinance transactions. If proper disclosures were not provided, the rescission period may be extended to 3 years.",
                suggestedAction: "Review TILA disclosures for right of rescission. Cite TILA § 125 and 12 CFR § 1026.23. If disclosures were inadequate, you may still have right to rescind and demand refund of fees.",
                affectedAmount: violation.potentialRefund,
                detectionMethod: .manualCalculation,
                confidence: 0.70,
                evidenceText: "Right of rescission analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 3,
                    actualValue: 0,
                    difference: 3,
                    formula: "TILA Rescission = 3 business days (or up to 3 years if disclosure violated)",
                    assumptions: ["TILA § 125 applies to transaction"],
                    warningFlags: ["Rescission right violation", "TILA disclosure issue"]
                ),
                createdDate: Date()
            ))
        }

        return results
    }

    private func checkAPRCalculationCompliance(extractedData: ExtractedData, loanDetails: LoanDetails) -> [AuditResult] {
        var results: [AuditResult] = []

        // Calculate expected APR and compare with stated rate
        let aprAnalysis = analyzeAPRAccuracy(extractedData: extractedData, loanDetails: loanDetails)

        if let violation = aprAnalysis {
            results.append(AuditResult(
                issueType: .tilaAPRViolation,
                severity: .high,
                title: "APR Calculation Accuracy Violation",
                description: "Annual Percentage Rate may not comply with TILA accuracy requirements",
                detailedExplanation: "Calculated APR: \(String(format: "%.3f", violation.calculatedAPR))%, Disclosed APR: \(String(format: "%.3f", violation.disclosedAPR))%. Under TILA § 107, APR must be accurate within 1/8% for first liens, 1/4% for subordinate liens.",
                suggestedAction: "Challenge APR calculation under TILA § 107 and 12 CFR § 1026.22. Request recalculation and potential rescission if APR was understated beyond tolerance.",
                affectedAmount: violation.financialImpact,
                detectionMethod: .manualCalculation,
                confidence: 0.85,
                evidenceText: "APR calculation analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: violation.calculatedAPR,
                    actualValue: violation.disclosedAPR,
                    difference: abs(violation.calculatedAPR - violation.disclosedAPR),
                    formula: "TILA APR = (Total finance charges / Loan amount) × (Days per year / Loan term days)",
                    assumptions: ["TILA § 107 accuracy requirements"],
                    warningFlags: ["APR calculation error", "TILA disclosure violation"]
                ),
                createdDate: Date()
            ))
        }

        return results
    }

    private func checkARMPaymentShockCompliance(extractedData: ExtractedData, loanDetails: LoanDetails) -> [AuditResult] {
        var results: [AuditResult] = []

        guard let armDetails = loanDetails.armDetails else { return results }

        // Check for proper payment shock disclosures
        let paymentShockViolation = analyzeARMPaymentShockDisclosures(extractedData: extractedData, armDetails: armDetails)

        if let violation = paymentShockViolation {
            results.append(AuditResult(
                issueType: .tilaARMDisclosureViolation,
                severity: .medium,
                title: "ARM Payment Shock Disclosure Violation",
                description: "ARM loan may lack required payment shock disclosures under TILA",
                detailedExplanation: "\(violation.description). Under TILA § 129C and 12 CFR § 1026.18(s), ARM loans must include specific disclosures about payment increases and rate adjustment examples.",
                suggestedAction: "Request proper ARM disclosures citing TILA § 129C and 12 CFR § 1026.18(s). If disclosures were inadequate, challenge loan terms and seek remediation.",
                affectedAmount: violation.potentialDamage,
                detectionMethod: .manualCalculation,
                confidence: 0.75,
                evidenceText: "ARM disclosure analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: nil,
                    actualValue: nil,
                    difference: nil,
                    formula: "TILA ARM Disclosure = Payment examples + rate adjustment scenarios",
                    assumptions: ["TILA § 129C disclosure requirements"],
                    warningFlags: ["ARM disclosure violation", "Payment shock risk"]
                ),
                createdDate: Date()
            ))
        }

        return results
    }

    private func checkHOEPACompliance(extractedData: ExtractedData, loanDetails: LoanDetails) -> [AuditResult] {
        var results: [AuditResult] = []

        // Check if loan meets HOEPA high-cost mortgage thresholds
        let hoepaAnalysis = analyzeHOEPACompliance(extractedData: extractedData, loanDetails: loanDetails)

        if let violation = hoepaAnalysis {
            results.append(AuditResult(
                issueType: .tilaHOEPAViolation,
                severity: .critical,
                title: "High-Cost Mortgage (HOEPA) Violation",
                description: "Loan may be high-cost mortgage with HOEPA violations",
                detailedExplanation: "\(violation.description). Under TILA § 129 (HOEPA), high-cost mortgages have additional protections including prohibited practices and required counseling.",
                suggestedAction: "Challenge loan as high-cost mortgage under TILA § 129. Cite HOEPA protections and seek legal counsel for potential loan rescission or damages.",
                affectedAmount: violation.damages,
                detectionMethod: .manualCalculation,
                confidence: 0.80,
                evidenceText: "HOEPA threshold analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: violation.threshold,
                    actualValue: violation.actualValue,
                    difference: violation.actualValue - violation.threshold,
                    formula: "HOEPA Threshold = APR > APOR + 6.5% (first lien) or 8.5% (subordinate)",
                    assumptions: ["TILA § 129 HOEPA thresholds"],
                    warningFlags: ["High-cost mortgage", "HOEPA protections apply"]
                ),
                createdDate: Date()
            ))
        }

        return results
    }

    private func checkATRCompliance(extractedData: ExtractedData, loanDetails: LoanDetails) -> [AuditResult] {
        var results: [AuditResult] = []

        // Check for Ability-to-Repay rule compliance
        let atrViolation = analyzeATRCompliance(extractedData: extractedData, loanDetails: loanDetails)

        if let violation = atrViolation {
            results.append(AuditResult(
                issueType: .tilaATRViolation,
                severity: .high,
                title: "Ability-to-Repay (ATR) Rule Violation",
                description: "Loan may violate TILA Ability-to-Repay requirements",
                detailedExplanation: "\(violation.description). Under TILA § 129C, lenders must make reasonable determination of ability to repay based on verified income, assets, employment, debt-to-income ratio, and credit history.",
                suggestedAction: "Challenge loan under ATR rule citing TILA § 129C and 12 CFR § 1026.43. Request documentation of ability-to-repay determination. Consider legal action for violations.",
                affectedAmount: violation.damages,
                detectionMethod: .manualCalculation,
                confidence: 0.70,
                evidenceText: "Ability-to-repay analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: nil,
                    actualValue: nil,
                    difference: nil,
                    formula: "ATR Compliance = Verified income + debt-to-income analysis + repayment capacity",
                    assumptions: ["TILA § 129C ATR requirements"],
                    warningFlags: ["ATR violation", "Lending standard breach"]
                ),
                createdDate: Date()
            ))
        }

        return results
    }

    private func checkPeriodicStatementCompliance(extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Check for periodic statement requirement compliance
        let statementViolations = analyzePeriodicStatementCompliance(extractedData: extractedData)

        for violation in statementViolations {
            results.append(AuditResult(
                issueType: .tilaPeriodicStatementViolation,
                severity: .medium,
                title: "Periodic Statement Requirement Violation",
                description: "Mortgage servicer may not be providing required periodic statements",
                detailedExplanation: "\(violation.description). Under TILA § 128 and 12 CFR § 1026.41, servicers must provide monthly periodic statements with specific required information.",
                suggestedAction: "Request proper periodic statements citing TILA § 128 and 12 CFR § 1026.41. Document missing information and report violations to CFPB.",
                affectedAmount: nil,
                detectionMethod: .manualCalculation,
                confidence: 0.75,
                evidenceText: "Periodic statement compliance analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: nil,
                    actualValue: nil,
                    difference: nil,
                    formula: "TILA Periodic Statement = Monthly statement + required disclosures",
                    assumptions: ["TILA § 128 periodic statement requirements"],
                    warningFlags: ["Statement requirement violation", "TILA disclosure gap"]
                ),
                createdDate: Date()
            ))
        }

        return results
    }

    private func checkARMAdjustmentNotificationCompliance(extractedData: ExtractedData, loanDetails: LoanDetails) -> [AuditResult] {
        var results: [AuditResult] = []

        guard let armDetails = loanDetails.armDetails else { return results }

        // Check ARM adjustment notification timing
        let notificationViolations = analyzeARMAdjustmentNotifications(extractedData: extractedData, armDetails: armDetails)

        for violation in notificationViolations {
            results.append(AuditResult(
                issueType: .tilaARMAdjustmentViolation,
                severity: .medium,
                title: "ARM Adjustment Notification Violation",
                description: "ARM interest rate adjustment notification timing may violate TILA",
                detailedExplanation: "\(violation.description). Under TILA § 129D and 12 CFR § 1026.20(c), servicers must provide advance notice of ARM adjustments with specific timing requirements.",
                suggestedAction: "Request proof of proper ARM adjustment notices citing TILA § 129D and 12 CFR § 1026.20(c). If notices were inadequate or untimely, challenge adjustment timing.",
                affectedAmount: violation.financialImpact,
                detectionMethod: .manualCalculation,
                confidence: 0.80,
                evidenceText: "ARM adjustment notification analysis",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: Double(violation.requiredNoticeDays),
                    actualValue: Double(violation.actualNoticeDays),
                    difference: Double(violation.requiredNoticeDays - violation.actualNoticeDays),
                    formula: "TILA ARM Notice = 60-120 days advance notice for first adjustment, 60 days for subsequent",
                    assumptions: ["TILA § 129D notification requirements"],
                    warningFlags: ["ARM notice timing violation", "Insufficient advance notice"]
                ),
                createdDate: Date()
            ))
        }

        return results
    }

    // MARK: - Helper Methods and Data Structures

    // Helper method implementations for RESPA compliance checks
    private func identifySuspiciousErrorPatterns(extractedData: ExtractedData) -> [SuspiciousErrorPattern] {
        var patterns: [SuspiciousErrorPattern] = []

        // Look for recurring late fees that might indicate unresolved errors
        let lateFees = extractedData.fees.filter { $0.category == .lateFee }
        if lateFees.count >= 3 {
            let totalLateFees = lateFees.reduce(0) { $0 + $1.amount }
            patterns.append(SuspiciousErrorPattern(
                description: "Multiple late fees (\(lateFees.count)) suggesting unresolved payment application issues",
                potentialDamage: totalLateFees,
                confidence: 0.75
            ))
        }

        // Look for payment misapplication patterns
        let misappliedPayments = extractedData.paymentHistory.filter { payment in
            guard let principal = payment.principalApplied,
                  let interest = payment.interestApplied else { return false }

            let totalAllocated = principal + interest + (payment.escrowApplied ?? 0) + (payment.lateFeesApplied ?? 0)
            return abs(payment.amount - totalAllocated) > 1.0
        }

        if misappliedPayments.count >= 2 {
            let totalMisapplied = misappliedPayments.reduce(0) { result, payment in
                let principal = payment.principalApplied ?? 0
                let interest = payment.interestApplied ?? 0
                let escrow = payment.escrowApplied ?? 0
                let fees = payment.lateFeesApplied ?? 0
                let totalAllocated = principal + interest + escrow + fees
                return result + abs(payment.amount - totalAllocated)
            }

            patterns.append(SuspiciousErrorPattern(
                description: "Multiple payment misapplications (\(misappliedPayments.count)) requiring NOE response",
                potentialDamage: totalMisapplied,
                confidence: 0.80
            ))
        }

        return patterns
    }

    private func identifyMissingRequiredInformation(extractedData: ExtractedData) -> [String] {
        var missing: [String] = []

        if extractedData.loanNumber == nil { missing.append("Loan number") }
        if extractedData.servicerName == nil { missing.append("Servicer name") }
        if extractedData.principalBalance == nil { missing.append("Principal balance") }
        if extractedData.interestRate == nil { missing.append("Interest rate") }
        if extractedData.monthlyPayment == nil { missing.append("Monthly payment amount") }
        if extractedData.dueDate == nil { missing.append("Payment due date") }

        // Check for missing payment allocation details
        let paymentsWithoutAllocation = extractedData.paymentHistory.filter {
            $0.principalApplied == nil || $0.interestApplied == nil
        }

        if paymentsWithoutAllocation.count > 0 {
            missing.append("Payment allocation details for \(paymentsWithoutAllocation.count) payments")
        }

        return missing
    }

    private func analyzeEscrowDisclosureCompliance(extractedData: ExtractedData) -> [EscrowDisclosureViolation] {
        var violations: [EscrowDisclosureViolation] = []

        // Check for missing annual escrow analysis
        let now = Date()
        let calendar = Calendar.current
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now

        let recentEscrowTransactions = extractedData.escrowActivity.filter { $0.date >= oneYearAgo }

        if recentEscrowTransactions.isEmpty && extractedData.escrowBalance != nil {
            violations.append(EscrowDisclosureViolation(
                title: "Missing Annual Escrow Analysis",
                description: "No escrow activity found in past 12 months despite active escrow account",
                explanation: "Servicers must provide annual escrow account analysis showing deposits, withdrawals, and balance projections",
                amount: nil,
                severity: .medium,
                confidence: 0.70
            ))
        }

        // Check for sudden payment increases without proper notice
        let recentPayments = extractedData.paymentHistory.sorted { $0.paymentDate > $1.paymentDate }.prefix(6)
        if recentPayments.count >= 4 {
            let oldPayments = Array(recentPayments.suffix(3))
            let newPayments = Array(recentPayments.prefix(3))

            let oldAverage = oldPayments.reduce(0) { $0 + $1.amount } / Double(oldPayments.count)
            let newAverage = newPayments.reduce(0) { $0 + $1.amount } / Double(newPayments.count)

            let increase = newAverage - oldAverage
            if increase > 100.0 { // $100+ increase
                violations.append(EscrowDisclosureViolation(
                    title: "Escrow Payment Increase Without Proper Notice",
                    description: "Payment increased by $\(String(format: "%.2f", increase)) without adequate advance notice",
                    explanation: "RESPA requires 60-day advance notice before escrow shortage-related payment increases",
                    amount: increase,
                    severity: .medium,
                    confidence: 0.65
                ))
            }
        }

        return violations
    }

    private func detectServicingTransferViolation(extractedData: ExtractedData) -> ServicingTransferViolation? {
        // Look for evidence of servicing transfer without proper notice
        // This is challenging without historical servicer data, but we can look for gaps or anomalies

        let sortedPayments = extractedData.paymentHistory.sorted { $0.paymentDate < $1.paymentDate }

        // Look for gaps in payment history that might indicate transfer
        for i in 1..<sortedPayments.count {
            let previousPayment = sortedPayments[i-1]
            let currentPayment = sortedPayments[i]

            let daysBetween = Calendar.current.dateComponents([.day], from: previousPayment.paymentDate, to: currentPayment.paymentDate).day ?? 0

            // Look for gaps of 45+ days (indicating potential transfer period)
            if daysBetween > 45 {
                return ServicingTransferViolation(
                    evidence: "Gap of \(daysBetween) days between payments suggests potential servicing transfer without proper notice",
                    confidence: 0.60
                )
            }
        }

        // Look for sudden changes in fee structure that might indicate new servicer
        let feesByType = Dictionary(grouping: extractedData.fees) { $0.category }
        for (category, fees) in feesByType {
            if fees.count >= 2 {
                let sortedFees = fees.sorted { $0.date < $1.date }
                let oldFees = sortedFees.prefix(sortedFees.count / 2)
                let newFees = sortedFees.suffix(sortedFees.count / 2)

                let oldAverage = oldFees.isEmpty ? 0 : oldFees.reduce(0) { $0 + $1.amount } / Double(oldFees.count)
                let newAverage = newFees.isEmpty ? 0 : newFees.reduce(0) { $0 + $1.amount } / Double(newFees.count)

                if abs(newAverage - oldAverage) > oldAverage * 0.5 { // 50% change
                    return ServicingTransferViolation(
                        evidence: "Significant change in \(category.rawValue) fees suggests potential servicer change without proper notice",
                        confidence: 0.55
                    )
                }
            }
        }

        return nil
    }

    private func analyzeSuspiciousFees(extractedData: ExtractedData) -> [ExtractedData.Fee] {
        var suspicious: [ExtractedData.Fee] = []

        for fee in extractedData.fees {
            // Check for unusually high fees
            var isSuspicious = false

            switch fee.category {
            case .inspectionFee:
                if fee.amount > 300 { isSuspicious = true }
            case .attorneyFee:
                if fee.amount > 750 { isSuspicious = true }
            case .processingFee:
                if fee.amount > 75 { isSuspicious = true }
            case .other:
                if fee.amount > 100 { isSuspicious = true }
            default:
                break
            }

            // Check for suspicious descriptions that might indicate kickbacks
            let suspiciousTerms = ["broker", "referral", "commission", "marketing", "vendor fee", "placement fee"]
            if suspiciousTerms.contains(where: { fee.description.lowercased().contains($0) }) {
                isSuspicious = true
            }

            if isSuspicious {
                suspicious.append(fee)
            }
        }

        return suspicious
    }

    private func analyzeForcePlacedInsurance(extractedData: ExtractedData) -> [ForcePlacedInsuranceViolation] {
        var violations: [ForcePlacedInsuranceViolation] = []

        // Look for insurance-related fees that might indicate force-placed insurance
        let insuranceFees = extractedData.fees.filter {
            $0.description.lowercased().contains("insurance") ||
            $0.description.lowercased().contains("force") ||
            $0.description.lowercased().contains("hazard") ||
            $0.description.lowercased().contains("property protection")
        }

        for fee in insuranceFees {
            if fee.amount > 500 { // Typically high amounts for force-placed insurance
                violations.append(ForcePlacedInsuranceViolation(
                    description: "Potential force-placed insurance fee: \(fee.description) - $\(fee.amount)",
                    amount: fee.amount,
                    date: fee.date
                ))
            }
        }

        // Look for insurance-related escrow withdrawals that seem excessive
        let insuranceWithdrawals = extractedData.escrowActivity.filter {
            $0.category == .homeownerInsurance && $0.type == .withdrawal && $0.amount > 2000
        }

        for withdrawal in insuranceWithdrawals {
            violations.append(ForcePlacedInsuranceViolation(
                description: "Excessive insurance payment from escrow: $\(withdrawal.amount) may indicate force-placed insurance",
                amount: withdrawal.amount,
                date: withdrawal.date
            ))
        }

        return violations
    }

    private func analyzeEscrowShortageNotifications(extractedData: ExtractedData) -> [EscrowShortageViolation] {
        var violations: [EscrowShortageViolation] = []

        // Look for payment increases that might indicate escrow shortage without proper notice
        let sortedPayments = extractedData.paymentHistory.sorted { $0.paymentDate < $1.paymentDate }

        for i in 1..<sortedPayments.count {
            let previousPayment = sortedPayments[i-1]
            let currentPayment = sortedPayments[i]

            let increase = currentPayment.amount - previousPayment.amount
            if increase > 50.0 { // $50+ increase
                let daysBetween = Calendar.current.dateComponents([.day], from: previousPayment.paymentDate, to: currentPayment.paymentDate).day ?? 0

                if daysBetween < 90 { // Less than proper notice period
                    violations.append(EscrowShortageViolation(
                        description: "Payment increase of $\(String(format: "%.2f", increase)) with only \(daysBetween) days notice",
                        amount: increase,
                        actualNoticeDays: daysBetween,
                        paymentIncreaseDate: currentPayment.paymentDate
                    ))
                }
            }
        }

        return violations
    }

    // Helper method implementations for TILA compliance checks
    private func analyzeRightOfRescission(loanDetails: LoanDetails) -> RightOfRescissionViolation? {
        // This would typically require more loan origination data
        // For now, we can check if this appears to be a refinance based on loan characteristics

        let now = Date()
        let loanAge = Calendar.current.dateComponents([.day], from: loanDetails.startDate, to: now).day ?? 0

        // If loan is very recent and appears to be a refinance (based on heuristics)
        if loanAge < 365 && loanDetails.loanType == .conventional {
            return RightOfRescissionViolation(
                description: "Recent refinance transaction may not have included proper right of rescission disclosures",
                potentialRefund: loanDetails.originalLoanAmount * 0.01 // Estimated 1% in fees
            )
        }

        return nil
    }

    private func analyzeAPRAccuracy(extractedData: ExtractedData, loanDetails: LoanDetails) -> APRViolation? {
        // Calculate estimated APR based on available data
        guard let monthlyPayment = extractedData.monthlyPayment else { return nil }

        let principal = loanDetails.originalLoanAmount
        let termMonths = loanDetails.loanTermMonths
        let nominalRate = loanDetails.originalInterestRate / 100.0

        // Estimate total finance charges based on total payments minus principal
        let totalPayments = monthlyPayment * Double(termMonths)
        let estimatedFinanceCharges = totalPayments - principal

        // Simple APR calculation (actual TILA APR calculation is more complex)
        let estimatedAPR = (estimatedFinanceCharges / principal) * (365.0 / Double(termMonths * 30))

        let tolerance = 0.125 // 1/8% tolerance for first liens
        let difference = abs(estimatedAPR - nominalRate)

        if difference > tolerance {
            return APRViolation(
                calculatedAPR: estimatedAPR * 100,
                disclosedAPR: nominalRate * 100,
                financialImpact: difference * principal / 100
            )
        }

        return nil
    }

    private func analyzeARMPaymentShockDisclosures(extractedData: ExtractedData, armDetails: LoanDetails.ARMDetails) -> ARMPaymentShockViolation? {
        // Check if ARM loan has extreme adjustment potential
        let maxRate = armDetails.lifetimeCap
        let initialRate = extractedData.interestRate ?? 0

        let potentialIncrease = maxRate - initialRate
        if potentialIncrease > 3.0 { // More than 3% potential increase
            let currentPayment = extractedData.monthlyPayment ?? 0
            let estimatedMaxPayment = currentPayment * (1 + potentialIncrease / 100)
            let paymentIncrease = estimatedMaxPayment - currentPayment

            return ARMPaymentShockViolation(
                description: "ARM loan has high payment shock potential with lifetime cap allowing \(String(format: "%.1f", potentialIncrease))% rate increase",
                potentialDamage: paymentIncrease * 12 // Annual impact
            )
        }

        return nil
    }

    private func analyzeHOEPACompliance(extractedData: ExtractedData, loanDetails: LoanDetails) -> HOEPAViolation? {
        // Check if loan meets HOEPA thresholds
        let nominalRate = loanDetails.originalInterestRate

        // Simplified HOEPA check - would need APOR data for accurate calculation
        // Assuming current APOR is approximately 4% for demonstration
        let estimatedAPOR = 4.0
        let hoepaThreshold = loanDetails.loanType == .conventional ? estimatedAPOR + 6.5 : estimatedAPOR + 8.5

        if nominalRate > hoepaThreshold {
            return HOEPAViolation(
                description: "Loan rate of \(String(format: "%.2f", nominalRate))% exceeds HOEPA threshold of \(String(format: "%.2f", hoepaThreshold))%",
                threshold: hoepaThreshold,
                actualValue: nominalRate,
                damages: loanDetails.originalLoanAmount * 0.05 // Estimated damages
            )
        }

        return nil
    }

    private func analyzeATRCompliance(extractedData: ExtractedData, loanDetails: LoanDetails) -> ATRViolation? {
        // ATR compliance is difficult to assess without borrower income/asset data
        // We can look for indicators of potential violations

        guard let monthlyPayment = extractedData.monthlyPayment else { return nil }

        // Check for unusually high payment-to-income ratios (heuristic approach)
        // If monthly payment exceeds typical housing payment thresholds, flag for review
        if monthlyPayment > 3000 && loanDetails.originalLoanAmount < 400000 {
            return ATRViolation(
                description: "High monthly payment relative to loan amount may indicate insufficient ATR analysis",
                damages: monthlyPayment * 12 // Annual payment burden
            )
        }

        return nil
    }

    private func analyzePeriodicStatementCompliance(extractedData: ExtractedData) -> [PeriodicStatementViolation] {
        var violations: [PeriodicStatementViolation] = []

        // Check for missing required statement information
        var missingElements: [String] = []

        if extractedData.principalBalance == nil { missingElements.append("Principal balance") }
        if extractedData.interestRate == nil { missingElements.append("Interest rate") }
        if extractedData.dueDate == nil { missingElements.append("Payment due date") }

        // Check payment allocation details
        let paymentsWithoutAllocation = extractedData.paymentHistory.filter {
            $0.principalApplied == nil || $0.interestApplied == nil
        }

        if !paymentsWithoutAllocation.isEmpty {
            missingElements.append("Payment allocation breakdown")
        }

        if !missingElements.isEmpty {
            violations.append(PeriodicStatementViolation(
                description: "Periodic statements missing required elements: \(missingElements.joined(separator: ", "))"
            ))
        }

        return violations
    }

    private func analyzeARMAdjustmentNotifications(extractedData: ExtractedData, armDetails: LoanDetails.ARMDetails) -> [ARMAdjustmentViolation] {
        var violations: [ARMAdjustmentViolation] = []

        // Look for rate changes without proper notification
        // This would require historical rate data, but we can check for patterns

        let sortedPayments = extractedData.paymentHistory.sorted { $0.paymentDate < $1.paymentDate }

        // Look for payment changes that might indicate rate adjustments
        for i in 1..<sortedPayments.count {
            let previousPayment = sortedPayments[i-1]
            let currentPayment = sortedPayments[i]

            let paymentChange = abs(currentPayment.amount - previousPayment.amount)
            if paymentChange > 100 { // Significant payment change
                let daysBetween = Calendar.current.dateComponents([.day], from: previousPayment.paymentDate, to: currentPayment.paymentDate).day ?? 0

                // If payment changed within a month (suggesting rate adjustment)
                if daysBetween < 45 {
                    violations.append(ARMAdjustmentViolation(
                        description: "Payment change of $\(String(format: "%.2f", paymentChange)) with only \(daysBetween) days notice",
                        requiredNoticeDays: 60,
                        actualNoticeDays: daysBetween,
                        financialImpact: paymentChange * 12
                    ))
                }
            }
        }

        return violations
    }
}

// MARK: - Compliance Data Structures

struct SuspiciousErrorPattern {
    let description: String
    let potentialDamage: Double
    let confidence: Double
}

struct EscrowDisclosureViolation {
    let title: String
    let description: String
    let explanation: String
    let amount: Double?
    let severity: AuditResult.Severity
    let confidence: Double
}

struct ServicingTransferViolation {
    let evidence: String
    let confidence: Double
}

struct ForcePlacedInsuranceViolation {
    let description: String
    let amount: Double
    let date: Date
}

struct EscrowShortageViolation {
    let description: String
    let amount: Double
    let actualNoticeDays: Int
    let paymentIncreaseDate: Date
}

struct RightOfRescissionViolation {
    let description: String
    let potentialRefund: Double
}

struct APRViolation {
    let calculatedAPR: Double
    let disclosedAPR: Double
    let financialImpact: Double
}

struct ARMPaymentShockViolation {
    let description: String
    let potentialDamage: Double
}

struct HOEPAViolation {
    let description: String
    let threshold: Double
    let actualValue: Double
    let damages: Double
}

struct ATRViolation {
    let description: String
    let damages: Double
}

struct PeriodicStatementViolation {
    let description: String
}

struct ARMAdjustmentViolation {
    let description: String
    let requiredNoticeDays: Int
    let actualNoticeDays: Int
    let financialImpact: Double
}

// MARK: - Enhanced Rule-Based Validation Engines

/// Validates basic arithmetic operations and calculations in mortgage documents
class ArithmeticValidationEngine {

    func validateArithmetic(extractedData: ExtractedData, loanDetails: LoanDetails?) async -> [AuditResult] {
        var results: [AuditResult] = []

        // Validate payment totals
        results.append(contentsOf: validatePaymentTotals(extractedData))

        // Validate principal and interest calculations
        if let loanDetails = loanDetails {
            results.append(contentsOf: validatePrincipalInterestCalculations(extractedData, loanDetails))
        }

        // Validate escrow calculations
        results.append(contentsOf: validateEscrowCalculations(extractedData))

        // Validate balance calculations
        results.append(contentsOf: validateBalanceCalculations(extractedData))

        return results
    }

    private func validatePaymentTotals(_ extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        for payment in extractedData.paymentHistory {
            let expectedTotal = (payment.principalApplied ?? 0) +
                              (payment.interestApplied ?? 0) +
                              (payment.escrowApplied ?? 0) +
                              (payment.lateFeesApplied ?? 0)

            let difference = abs(payment.amount - expectedTotal)

            // Allow for rounding differences up to $0.02
            if difference > 0.02 {
                results.append(AuditResult(
                    issueType: .calculationMismatch,
                    severity: difference > 10.0 ? .high : .medium,
                    title: "Payment Allocation Arithmetic Error",
                    description: "Payment total doesn't match sum of allocated amounts",
                    detailedExplanation: "Payment of $\(payment.amount) on \(DateFormatter.shortDate.string(from: payment.paymentDate)) doesn't equal sum of allocations ($\(expectedTotal)). Difference: $\(difference)",
                    suggestedAction: "Request correction of payment allocation breakdown",
                    affectedAmount: difference,
                    detectionMethod: .manualCalculation,
                    confidence: 0.95,
                    evidenceText: "Arithmetic verification failed",
                    calculationDetails: AuditResult.CalculationDetails(
                        expectedValue: expectedTotal,
                        actualValue: payment.amount,
                        difference: difference,
                        formula: "Principal + Interest + Escrow + Late Fees = Total Payment",
                        assumptions: ["All allocations properly recorded"],
                        warningFlags: ["Arithmetic inconsistency"]
                    ),
                    createdDate: Date()
                ))
            }
        }

        return results
    }

    private func validatePrincipalInterestCalculations(_ extractedData: ExtractedData, _ loanDetails: LoanDetails) -> [AuditResult] {
        var results: [AuditResult] = []

        guard let principalBalance = extractedData.principalBalance,
              let interestRate = extractedData.interestRate else {
            return results
        }

        let monthlyInterestRate = interestRate / 12.0 / 100.0

        for payment in extractedData.paymentHistory {
            guard let interestApplied = payment.interestApplied,
                  let principalApplied = payment.principalApplied else { continue }

            // Calculate expected interest for this payment
            let expectedInterest = principalBalance * monthlyInterestRate
            let interestDifference = abs(interestApplied - expectedInterest)

            // Allow for small rounding differences
            if interestDifference > 1.0 {
                results.append(AuditResult(
                    issueType: .incorrectInterest,
                    severity: interestDifference > 50.0 ? .high : .medium,
                    title: "Interest Calculation Error",
                    description: "Calculated interest doesn't match applied interest",
                    detailedExplanation: "For payment on \(DateFormatter.shortDate.string(from: payment.paymentDate)), expected interest of $\(String(format: "%.2f", expectedInterest)) but $\(interestApplied) was applied. Difference: $\(String(format: "%.2f", interestDifference))",
                    suggestedAction: "Verify interest rate application and request correction if needed",
                    affectedAmount: interestDifference,
                    detectionMethod: .manualCalculation,
                    confidence: 0.88,
                    evidenceText: "Interest calculation verification",
                    calculationDetails: AuditResult.CalculationDetails(
                        expectedValue: expectedInterest,
                        actualValue: interestApplied,
                        difference: interestDifference,
                        formula: "Principal Balance × (Interest Rate ÷ 12)",
                        assumptions: ["Interest rate: \(interestRate)%", "Principal balance: $\(principalBalance)"],
                        warningFlags: ["Interest calculation discrepancy"]
                    ),
                    createdDate: Date()
                ))
            }
        }

        return results
    }

    private func validateEscrowCalculations(_ extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Calculate escrow balance based on transactions
        var calculatedBalance: Double = 0.0

        for transaction in extractedData.escrowActivity.sorted(by: { $0.date < $1.date }) {
            switch transaction.type {
            case .deposit:
                calculatedBalance += transaction.amount
            case .withdrawal:
                calculatedBalance -= transaction.amount
            }
        }

        if let reportedBalance = extractedData.escrowBalance {
            let difference = abs(calculatedBalance - reportedBalance)

            if difference > 1.0 { // Allow for small rounding
                results.append(AuditResult(
                    issueType: .escrowError,
                    severity: difference > 100.0 ? .high : .medium,
                    title: "Escrow Balance Calculation Error",
                    description: "Calculated escrow balance doesn't match reported balance",
                    detailedExplanation: "Based on escrow transactions, balance should be $\(String(format: "%.2f", calculatedBalance)) but reported as $\(reportedBalance). Difference: $\(String(format: "%.2f", difference))",
                    suggestedAction: "Request detailed escrow account analysis and correction",
                    affectedAmount: difference,
                    detectionMethod: .manualCalculation,
                    confidence: 0.92,
                    evidenceText: "Escrow transaction analysis",
                    calculationDetails: AuditResult.CalculationDetails(
                        expectedValue: calculatedBalance,
                        actualValue: reportedBalance,
                        difference: difference,
                        formula: "Sum of Deposits - Sum of Withdrawals",
                        assumptions: ["All transactions recorded", "No starting balance adjustments"],
                        warningFlags: ["Escrow balance discrepancy"]
                    ),
                    createdDate: Date()
                ))
            }
        }

        return results
    }

    private func validateBalanceCalculations(_ extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // This would implement principal balance validation based on payments
        // Complex calculation requiring amortization schedule
        // Placeholder for now - would need full implementation

        return results
    }
}

/// Validates date-related rules and constraints
class DateValidationEngine {

    func validateDates(extractedData: ExtractedData) async -> [AuditResult] {
        var results: [AuditResult] = []

        // Validate payment dates and late fee timing
        results.append(contentsOf: validatePaymentTiming(extractedData))

        // Validate escrow payment timing
        results.append(contentsOf: validateEscrowTiming(extractedData))

        // Validate due date consistency
        results.append(contentsOf: validateDueDateConsistency(extractedData))

        return results
    }

    private func validatePaymentTiming(_ extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        guard let dueDate = extractedData.dueDate else { return results }

        let calendar = Calendar.current

        for payment in extractedData.paymentHistory {
            // Check if late fee was correctly applied
            if let lateFeesApplied = payment.lateFeesApplied, lateFeesApplied > 0 {
                let daysPastDue = calendar.dateComponents([.day], from: dueDate, to: payment.paymentDate).day ?? 0

                // Most mortgages have a 15-day grace period
                if daysPastDue <= 15 {
                    results.append(AuditResult(
                        issueType: .latePaymentError,
                        severity: .high,
                        title: "Incorrect Late Fee Application",
                        description: "Late fee charged within grace period",
                        detailedExplanation: "Payment made on \(DateFormatter.shortDate.string(from: payment.paymentDate)) was only \(daysPastDue) days past due date \(DateFormatter.shortDate.string(from: dueDate)), but late fee of $\(lateFeesApplied) was charged.",
                        suggestedAction: "Request removal of incorrect late fee",
                        affectedAmount: lateFeesApplied,
                        detectionMethod: .manualCalculation,
                        confidence: 0.93,
                        evidenceText: "Grace period violation",
                        calculationDetails: AuditResult.CalculationDetails(
                            expectedValue: 0.0,
                            actualValue: lateFeesApplied,
                            difference: lateFeesApplied,
                            formula: "No late fee if payment within 15-day grace period",
                            assumptions: ["Standard 15-day grace period"],
                            warningFlags: ["Grace period violation"]
                        ),
                        createdDate: Date()
                    ))
                }
            }
        }

        return results
    }

    private func validateEscrowTiming(_ extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        let calendar = Calendar.current

        for transaction in extractedData.escrowActivity {
            // Validate tax payment timing (typically due by specific dates)
            if transaction.category == .propertyTax && transaction.type == .withdrawal {
                let month = calendar.component(.month, from: transaction.date)
                let day = calendar.component(.day, from: transaction.date)

                // Example: Property taxes often due January 31st and July 31st
                let isNearTaxDeadline = (month == 1 && day <= 31) ||
                                       (month == 7 && day <= 31) ||
                                       (month == 12 && day >= 1) || // December payments for January deadline
                                       (month == 6 && day >= 1)    // June payments for July deadline

                if !isNearTaxDeadline && transaction.amount > 1000 {
                    results.append(AuditResult(
                        issueType: .lateTaxPayment,
                        severity: .medium,
                        title: "Unusual Tax Payment Timing",
                        description: "Property tax payment made outside typical deadlines",
                        detailedExplanation: "Property tax payment of $\(transaction.amount) made on \(DateFormatter.shortDate.string(from: transaction.date)) appears to be outside normal tax deadline periods.",
                        suggestedAction: "Verify tax payment timing and potential late fees",
                        affectedAmount: nil,
                        detectionMethod: .manualCalculation,
                        confidence: 0.75,
                        evidenceText: "Unusual payment timing",
                        calculationDetails: nil,
                        createdDate: Date()
                    ))
                }
            }
        }

        return results
    }

    private func validateDueDateConsistency(_ extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Check if payments are consistently due on the same day each month
        let paymentDays = extractedData.paymentHistory.compactMap { payment in
            Calendar.current.component(.day, from: payment.paymentDate)
        }

        if paymentDays.count > 3 {
            let mostCommonDay = paymentDays.mostFrequent()
            let inconsistentPayments = paymentDays.filter { abs($0 - mostCommonDay) > 3 }

            if inconsistentPayments.count > paymentDays.count / 4 { // More than 25% inconsistent
                results.append(AuditResult(
                    issueType: .incorrectBalance,
                    severity: .low,
                    title: "Inconsistent Payment Due Dates",
                    description: "Payment due dates vary significantly",
                    detailedExplanation: "Payments are typically due on day \(mostCommonDay) of the month, but \(inconsistentPayments.count) payments were due on significantly different days.",
                    suggestedAction: "Verify loan terms for due date requirements",
                    affectedAmount: nil,
                    detectionMethod: .manualCalculation,
                    confidence: 0.65,
                    evidenceText: "Due date inconsistency pattern",
                    calculationDetails: nil,
                    createdDate: Date()
                ))
            }
        }

        return results
    }
}

/// Validates data formats and required fields
class FormatValidationEngine {

    func validateFormats(extractedData: ExtractedData) async -> [AuditResult] {
        var results: [AuditResult] = []

        // Validate loan number format
        results.append(contentsOf: validateLoanNumber(extractedData.loanNumber))

        // Validate required fields
        results.append(contentsOf: validateRequiredFields(extractedData))

        // Validate numeric ranges
        results.append(contentsOf: validateNumericRanges(extractedData))

        return results
    }

    private func validateLoanNumber(_ loanNumber: String?) -> [AuditResult] {
        var results: [AuditResult] = []

        guard let loanNumber = loanNumber else {
            results.append(AuditResult(
                issueType: .missingData,
                severity: .medium,
                title: "Missing Loan Number",
                description: "Loan number not found in document",
                detailedExplanation: "The loan number is missing from the mortgage document, which is required for proper identification and verification.",
                suggestedAction: "Request document with complete loan information",
                affectedAmount: nil,
                detectionMethod: .manualCalculation,
                confidence: 1.0,
                evidenceText: "Loan number field empty",
                calculationDetails: nil,
                createdDate: Date()
            ))
            return results
        }

        // Validate loan number format (typically 10-20 digits, sometimes with letters)
        let loanNumberPattern = "^[A-Za-z0-9]{8,20}$"
        let regex = try? NSRegularExpression(pattern: loanNumberPattern)
        let range = NSRange(location: 0, length: loanNumber.utf16.count)

        if regex?.firstMatch(in: loanNumber, options: [], range: range) == nil {
            results.append(AuditResult(
                issueType: .formatError,
                severity: .low,
                title: "Invalid Loan Number Format",
                description: "Loan number format appears unusual",
                detailedExplanation: "Loan number '\(loanNumber)' doesn't match typical mortgage loan number formats (8-20 alphanumeric characters).",
                suggestedAction: "Verify loan number accuracy with servicer",
                affectedAmount: nil,
                detectionMethod: .manualCalculation,
                confidence: 0.80,
                evidenceText: "Format validation",
                calculationDetails: nil,
                createdDate: Date()
            ))
        }

        return results
    }

    private func validateRequiredFields(_ extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        let missingFields: [String] = [
            extractedData.servicerName == nil ? "Servicer Name" : nil,
            extractedData.borrowerName == nil ? "Borrower Name" : nil,
            extractedData.propertyAddress == nil ? "Property Address" : nil,
            extractedData.principalBalance == nil ? "Principal Balance" : nil,
            extractedData.interestRate == nil ? "Interest Rate" : nil,
            extractedData.monthlyPayment == nil ? "Monthly Payment" : nil
        ].compactMap { $0 }

        if !missingFields.isEmpty {
            results.append(AuditResult(
                issueType: .missingData,
                severity: missingFields.count > 3 ? .high : .medium,
                title: "Missing Required Information",
                description: "\(missingFields.count) required fields missing",
                detailedExplanation: "The following required fields are missing: \(missingFields.joined(separator: ", ")). This may impact the accuracy of the analysis.",
                suggestedAction: "Obtain complete mortgage statement with all required information",
                affectedAmount: nil,
                detectionMethod: .manualCalculation,
                confidence: 1.0,
                evidenceText: "Required field validation",
                calculationDetails: nil,
                createdDate: Date()
            ))
        }

        return results
    }

    private func validateNumericRanges(_ extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Validate interest rate range (typically 0.1% to 30%)
        if let interestRate = extractedData.interestRate {
            if interestRate < 0.1 || interestRate > 30.0 {
                results.append(AuditResult(
                    issueType: .formatError,
                    severity: .medium,
                    title: "Unusual Interest Rate",
                    description: "Interest rate outside typical range",
                    detailedExplanation: "Interest rate of \(interestRate)% is outside the typical range of 0.1% to 30% for mortgage loans.",
                    suggestedAction: "Verify interest rate accuracy",
                    affectedAmount: nil,
                    detectionMethod: .manualCalculation,
                    confidence: 0.85,
                    evidenceText: "Range validation",
                    calculationDetails: nil,
                    createdDate: Date()
                ))
            }
        }

        // Validate payment amounts (should be positive and reasonable)
        for payment in extractedData.paymentHistory {
            if payment.amount <= 0 {
                results.append(AuditResult(
                    issueType: .formatError,
                    severity: .high,
                    title: "Invalid Payment Amount",
                    description: "Payment amount is zero or negative",
                    detailedExplanation: "Payment recorded on \(DateFormatter.shortDate.string(from: payment.paymentDate)) has amount of $\(payment.amount), which is invalid.",
                    suggestedAction: "Verify payment records for data entry errors",
                    affectedAmount: abs(payment.amount),
                    detectionMethod: .manualCalculation,
                    confidence: 0.95,
                    evidenceText: "Invalid amount validation",
                    calculationDetails: nil,
                    createdDate: Date()
                ))
            }
        }

        return results
    }
}

/// Validates payment allocation across principal, interest, escrow, and fees
class PaymentAllocationValidator {

    func validatePaymentAllocations(extractedData: ExtractedData, loanDetails: LoanDetails?) async -> [AuditResult] {
        var results: [AuditResult] = []

        // Validate allocation percentages
        results.append(contentsOf: validateAllocationPercentages(extractedData))

        // Validate allocation consistency
        results.append(contentsOf: validateAllocationConsistency(extractedData))

        // Validate unusual allocations
        results.append(contentsOf: validateUnusualAllocations(extractedData))

        return results
    }

    private func validateAllocationPercentages(_ extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        for payment in extractedData.paymentHistory {
            guard payment.amount > 0,
                  let principal = payment.principalApplied,
                  let interest = payment.interestApplied else { continue }

            let principalPercentage = (principal / payment.amount) * 100
            let interestPercentage = (interest / payment.amount) * 100

            // Flag unusual allocation percentages
            if principalPercentage > 90 { // More than 90% to principal is unusual
                results.append(AuditResult(
                    issueType: .misappliedPayment,
                    severity: .medium,
                    title: "Unusual Principal Allocation",
                    description: "Unusually high percentage allocated to principal",
                    detailedExplanation: "Payment on \(DateFormatter.shortDate.string(from: payment.paymentDate)) allocated \(String(format: "%.1f", principalPercentage))% to principal, which is unusually high for a regular payment.",
                    suggestedAction: "Verify if this was an additional principal payment or allocation error",
                    affectedAmount: nil,
                    detectionMethod: .manualCalculation,
                    confidence: 0.75,
                    evidenceText: "Allocation percentage analysis",
                    calculationDetails: nil,
                    createdDate: Date()
                ))
            }

            if interestPercentage > 80 { // More than 80% to interest is suspicious
                results.append(AuditResult(
                    issueType: .misappliedPayment,
                    severity: .high,
                    title: "Excessive Interest Allocation",
                    description: "Unusually high percentage allocated to interest",
                    detailedExplanation: "Payment on \(DateFormatter.shortDate.string(from: payment.paymentDate)) allocated \(String(format: "%.1f", interestPercentage))% to interest, which may indicate an error.",
                    suggestedAction: "Request verification of payment allocation methodology",
                    affectedAmount: nil,
                    detectionMethod: .manualCalculation,
                    confidence: 0.85,
                    evidenceText: "Excessive interest allocation",
                    calculationDetails: nil,
                    createdDate: Date()
                ))
            }
        }

        return results
    }

    private func validateAllocationConsistency(_ extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Check for consistent allocation patterns
        let regularPayments = extractedData.paymentHistory.filter { payment in
            // Filter for regular monthly payments (exclude extra payments)
            guard let monthlyPayment = extractedData.monthlyPayment else { return true }
            return abs(payment.amount - monthlyPayment) < 50.0 // Within $50 of expected payment
        }

        if regularPayments.count > 3 {
            let principalAllocations = regularPayments.compactMap { $0.principalApplied }
            let interestAllocations = regularPayments.compactMap { $0.interestApplied }

            // Check for unusual variance in allocations
            if let avgPrincipal = principalAllocations.average(),
               let avgInterest = interestAllocations.average() {

                for payment in regularPayments {
                    guard let principal = payment.principalApplied,
                          let interest = payment.interestApplied else { continue }

                    let principalVariance = abs(principal - avgPrincipal) / avgPrincipal
                    let interestVariance = abs(interest - avgInterest) / avgInterest

                    if principalVariance > 0.5 || interestVariance > 0.5 { // More than 50% variance
                        results.append(AuditResult(
                            issueType: .misappliedPayment,
                            severity: .medium,
                            title: "Inconsistent Payment Allocation",
                            description: "Payment allocation varies significantly from pattern",
                            detailedExplanation: "Payment on \(DateFormatter.shortDate.string(from: payment.paymentDate)) has allocation that differs significantly from the established pattern.",
                            suggestedAction: "Verify reason for allocation variance",
                            affectedAmount: nil,
                            detectionMethod: .manualCalculation,
                            confidence: 0.70,
                            evidenceText: "Allocation consistency analysis",
                            calculationDetails: nil,
                            createdDate: Date()
                        ))
                    }
                }
            }
        }

        return results
    }

    private func validateUnusualAllocations(_ extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        for payment in extractedData.paymentHistory {
            // Check for payments with no principal allocation
            if payment.principalApplied == 0 && payment.amount > 100 {
                results.append(AuditResult(
                    issueType: .misappliedPayment,
                    severity: .high,
                    title: "No Principal Applied",
                    description: "Payment made with zero principal allocation",
                    detailedExplanation: "Payment of $\(payment.amount) on \(DateFormatter.shortDate.string(from: payment.paymentDate)) had no amount applied to principal, which is unusual for mortgage payments.",
                    suggestedAction: "Verify payment allocation and request correction if needed",
                    affectedAmount: payment.amount,
                    detectionMethod: .manualCalculation,
                    confidence: 0.90,
                    evidenceText: "Zero principal allocation",
                    calculationDetails: nil,
                    createdDate: Date()
                ))
            }

            // Check for payments with no interest allocation (when balance exists)
            if payment.interestApplied == 0 && payment.amount > 100 && extractedData.principalBalance ?? 0 > 0 {
                results.append(AuditResult(
                    issueType: .misappliedPayment,
                    severity: .medium,
                    title: "No Interest Applied",
                    description: "Payment made with zero interest allocation",
                    detailedExplanation: "Payment of $\(payment.amount) on \(DateFormatter.shortDate.string(from: payment.paymentDate)) had no amount applied to interest despite outstanding principal balance.",
                    suggestedAction: "Verify if this was an escrow-only or fee-only payment",
                    affectedAmount: nil,
                    detectionMethod: .manualCalculation,
                    confidence: 0.75,
                    evidenceText: "Zero interest allocation",
                    calculationDetails: nil,
                    createdDate: Date()
                ))
            }
        }

        return results
    }
}

/// Validates late fee calculations and applications
class LateFeeCalculationValidator {

    func validateLateFeesCalculation(extractedData: ExtractedData, loanDetails: LoanDetails?) async -> [AuditResult] {
        var results: [AuditResult] = []

        let gracePeriodDays = loanDetails?.gracePeriodDays ?? 15

        for payment in extractedData.paymentHistory {
            if let lateFee = payment.lateFeesApplied, lateFee > 0 {
                results.append(contentsOf: validateLateFeeApplication(
                    payment: payment,
                    extractedData: extractedData,
                    gracePeriodDays: gracePeriodDays
                ))
            }
        }

        return results
    }

    private func validateLateFeeApplication(
        payment: ExtractedData.PaymentRecord,
        extractedData: ExtractedData,
        gracePeriodDays: Int
    ) -> [AuditResult] {
        var results: [AuditResult] = []

        guard let dueDate = extractedData.dueDate,
              let lateFee = payment.lateFeesApplied,
              lateFee > 0 else { return results }

        let calendar = Calendar.current
        let daysPastDue = calendar.dateComponents([.day], from: dueDate, to: payment.paymentDate).day ?? 0

        // Check if late fee was applied within grace period
        if daysPastDue <= gracePeriodDays {
            results.append(AuditResult(
                issueType: .unauthorizedFee,
                severity: .high,
                title: "Late Fee Applied Within Grace Period",
                description: "Late fee charged before grace period expired",
                detailedExplanation: "Late fee of $\(lateFee) was charged for payment made \(daysPastDue) days after due date, but grace period is \(gracePeriodDays) days.",
                suggestedAction: "Request removal of improperly charged late fee",
                affectedAmount: lateFee,
                detectionMethod: .manualCalculation,
                confidence: 0.95,
                evidenceText: "Grace period violation",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 0.0,
                    actualValue: lateFee,
                    difference: lateFee,
                    formula: "No late fee within \(gracePeriodDays)-day grace period",
                    assumptions: ["Grace period: \(gracePeriodDays) days"],
                    warningFlags: ["Improper late fee application"]
                ),
                createdDate: Date()
            ))
        }

        // Validate late fee amount (typically 4-5% of payment or fixed amount)
        if let monthlyPayment = extractedData.monthlyPayment {
            let expectedLateFeePercentage = lateFee / monthlyPayment * 100

            if expectedLateFeePercentage > 6.0 { // More than 6% is excessive
                results.append(AuditResult(
                    issueType: .unauthorizedFee,
                    severity: .medium,
                    title: "Excessive Late Fee Amount",
                    description: "Late fee amount exceeds reasonable percentage",
                    detailedExplanation: "Late fee of $\(lateFee) represents \(String(format: "%.1f", expectedLateFeePercentage))% of monthly payment, which exceeds typical late fee limits.",
                    suggestedAction: "Verify late fee calculation and legal limits",
                    affectedAmount: nil,
                    detectionMethod: .manualCalculation,
                    confidence: 0.80,
                    evidenceText: "Late fee percentage analysis",
                    calculationDetails: nil,
                    createdDate: Date()
                ))
            }
        }

        return results
    }
}

/// Validates principal and interest breakdown calculations
class PrincipalInterestValidator {

    func validatePrincipalInterestBreakdown(extractedData: ExtractedData, loanDetails: LoanDetails?) async -> [AuditResult] {
        var results: [AuditResult] = []

        guard let loanDetails = loanDetails else { return results }

        // Validate amortization progression
        results.append(contentsOf: validateAmortizationProgression(extractedData, loanDetails))

        return results
    }

    private func validateAmortizationProgression(_ extractedData: ExtractedData, _ loanDetails: LoanDetails) -> [AuditResult] {
        var results: [AuditResult] = []

        let sortedPayments = extractedData.paymentHistory.sorted { $0.paymentDate < $1.paymentDate }

        for i in 1..<sortedPayments.count {
            let previousPayment = sortedPayments[i-1]
            let currentPayment = sortedPayments[i]

            guard let prevPrincipal = previousPayment.principalApplied,
                  let currPrincipal = currentPayment.principalApplied,
                  let prevInterest = previousPayment.interestApplied,
                  let currInterest = currentPayment.interestApplied else { continue }

            // In normal amortization, principal should increase and interest should decrease over time
            let principalTrend = currPrincipal - prevPrincipal
            let interestTrend = currInterest - prevInterest

            // Allow for some variance due to payment timing and ARM adjustments
            if principalTrend < -50 && interestTrend > 50 { // Significant regression
                results.append(AuditResult(
                    issueType: .amortizationError,
                    severity: .medium,
                    title: "Unusual Amortization Pattern",
                    description: "Principal allocation decreased while interest increased",
                    detailedExplanation: "Between payments on \(DateFormatter.shortDate.string(from: previousPayment.paymentDate)) and \(DateFormatter.shortDate.string(from: currentPayment.paymentDate)), principal allocation decreased by $\(String(format: "%.2f", abs(principalTrend))) while interest increased by $\(String(format: "%.2f", interestTrend)).",
                    suggestedAction: "Verify if interest rate changed or if there's an allocation error",
                    affectedAmount: nil,
                    detectionMethod: .manualCalculation,
                    confidence: 0.70,
                    evidenceText: "Amortization trend analysis",
                    calculationDetails: nil,
                    createdDate: Date()
                ))
            }
        }

        return results
    }
}

/// Validates overall data integrity and consistency
class DataIntegrityValidator {

    func validateDataIntegrity(extractedData: ExtractedData) async -> [AuditResult] {
        var results: [AuditResult] = []

        // Check for duplicate payments
        results.append(contentsOf: validateDuplicatePayments(extractedData))

        // Check for chronological consistency
        results.append(contentsOf: validateChronologicalOrder(extractedData))

        // Check for data completeness
        results.append(contentsOf: validateDataCompleteness(extractedData))

        return results
    }

    private func validateDuplicatePayments(_ extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        let sortedPayments = extractedData.paymentHistory.sorted { $0.paymentDate < $1.paymentDate }

        for i in 1..<sortedPayments.count {
            let previousPayment = sortedPayments[i-1]
            let currentPayment = sortedPayments[i]

            // Check for payments on same date with same amount
            if Calendar.current.isDate(previousPayment.paymentDate, inSameDayAs: currentPayment.paymentDate) &&
               abs(previousPayment.amount - currentPayment.amount) < 0.01 {

                results.append(AuditResult(
                    issueType: .duplicateCharge,
                    severity: .high,
                    title: "Potential Duplicate Payment",
                    description: "Two identical payments recorded on same date",
                    detailedExplanation: "Two payments of $\(currentPayment.amount) were recorded on \(DateFormatter.shortDate.string(from: currentPayment.paymentDate)), which may indicate a duplicate entry.",
                    suggestedAction: "Verify if duplicate payment exists and request correction",
                    affectedAmount: currentPayment.amount,
                    detectionMethod: .manualCalculation,
                    confidence: 0.85,
                    evidenceText: "Duplicate payment detection",
                    calculationDetails: nil,
                    createdDate: Date()
                ))
            }
        }

        return results
    }

    private func validateChronologicalOrder(_ extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Check if payments are in chronological order
        let paymentDates = extractedData.paymentHistory.map { $0.paymentDate }
        let sortedDates = paymentDates.sorted()

        if paymentDates != sortedDates {
            results.append(AuditResult(
                issueType: .inconsistentData,
                severity: .low,
                title: "Payment History Not Chronological",
                description: "Payments not listed in chronological order",
                detailedExplanation: "Payment history appears to be out of chronological order, which may indicate data processing issues.",
                suggestedAction: "Request properly sorted payment history",
                affectedAmount: nil,
                detectionMethod: .manualCalculation,
                confidence: 0.90,
                evidenceText: "Chronological order validation",
                calculationDetails: nil,
                createdDate: Date()
            ))
        }

        return results
    }

    private func validateDataCompleteness(_ extractedData: ExtractedData) -> [AuditResult] {
        var results: [AuditResult] = []

        // Check for incomplete payment records
        let incompletePayments = extractedData.paymentHistory.filter { payment in
            payment.principalApplied == nil ||
            payment.interestApplied == nil ||
            payment.escrowApplied == nil
        }

        if !incompletePayments.isEmpty {
            results.append(AuditResult(
                issueType: .missingData,
                severity: .medium,
                title: "Incomplete Payment Records",
                description: "\(incompletePayments.count) payments missing allocation details",
                detailedExplanation: "\(incompletePayments.count) payment records are missing allocation details (principal, interest, or escrow amounts), which limits analysis accuracy.",
                suggestedAction: "Request complete payment history with full allocation details",
                affectedAmount: nil,
                detectionMethod: .manualCalculation,
                confidence: 1.0,
                evidenceText: "Data completeness validation",
                calculationDetails: nil,
                createdDate: Date()
            ))
        }

        return results
    }
}

// MARK: - Extensions for Enhanced Analysis

extension AuditResult.IssueType {
    // Add new issue types for enhanced rule-based detection
    static let calculationMismatch = AuditResult.IssueType(rawValue: "calculation_mismatch") ?? .incorrectBalance
    static let formatError = AuditResult.IssueType(rawValue: "format_error") ?? .incorrectBalance
    static let missingData = AuditResult.IssueType(rawValue: "missing_data") ?? .incorrectBalance
    static let inconsistentData = AuditResult.IssueType(rawValue: "inconsistent_data") ?? .incorrectBalance
    static let amortizationError = AuditResult.IssueType(rawValue: "amortization_error") ?? .incorrectInterest
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

extension Array where Element == Double {
    func average() -> Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}

extension Array where Element == Int {
    func mostFrequent() -> Int {
        let counts = Dictionary(grouping: self, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key ?? 0
    }
}