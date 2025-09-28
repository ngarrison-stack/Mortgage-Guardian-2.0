import Foundation

// MARK: - Main Audit Engine
class AuditEngine {
    private let paymentTracker = PaymentTrackingAlgorithm()
    private let interestCalculator = InterestRecalculationEngine()
    private let escrowAuditor = EscrowAuditSystem()
    private let feeValidator = FeeValidationAlgorithm()
    private let crossVerifier = CrossVerificationSystem()
    private let errorDetector = ErrorDetectionEngine()

    func performCompleteAudit(extractedData: ExtractedData,
                            bankTransactions: [Transaction],
                            loanDetails: LoanDetails? = nil) async -> [AuditResult] {
        var allResults: [AuditResult] = []

        // 1. Payment Tracking Analysis
        let paymentResults = await paymentTracker.analyzePayments(
            extractedData: extractedData,
            bankTransactions: bankTransactions
        )
        allResults.append(contentsOf: paymentResults)

        // 2. Interest Recalculation
        if let loanDetails = loanDetails {
            let interestResults = await interestCalculator.recalculateInterest(
                extractedData: extractedData,
                loanDetails: loanDetails
            )
            allResults.append(contentsOf: interestResults)
        }

        // 3. Escrow Audit
        let escrowResults = await escrowAuditor.auditEscrowAccount(
            extractedData: extractedData,
            bankTransactions: bankTransactions
        )
        allResults.append(contentsOf: escrowResults)

        // 4. Fee Validation
        let feeResults = await feeValidator.validateFees(
            extractedData: extractedData,
            bankTransactions: bankTransactions
        )
        allResults.append(contentsOf: feeResults)

        // 5. Cross-Verification with Bank Data
        let crossVerificationResults = await crossVerifier.crossVerifyWithBankData(
            extractedData: extractedData,
            bankTransactions: bankTransactions
        )
        allResults.append(contentsOf: crossVerificationResults)

        // 6. Error Detection and Confidence Scoring
        return errorDetector.analyzeAndScoreResults(allResults)
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
}