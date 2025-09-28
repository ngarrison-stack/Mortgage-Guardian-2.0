import Foundation
import Vision
import NaturalLanguage
import OSLog

// MARK: - DocumentAnalysisService Field Extraction Extension
extension DocumentAnalysisService {

    // MARK: - Tax Return Field Extraction

    func extractAdjustedGrossIncome(from text: String) -> Double? {
        let patterns = [
            "Adjusted Gross Income[\\s\\S]*?([0-9,]+\\.?[0-9]*)",
            "AGI[\\s\\S]*?([0-9,]+\\.?[0-9]*)",
            "Line 11[\\s\\S]*?([0-9,]+\\.?[0-9]*)",
            "37[\\s\\S]*?([0-9,]+\\.?[0-9]*)" // Form 1040 line 37
        ]
        return extractFirstCurrencyMatch(patterns: patterns, from: text)
    }

    func extractTotalIncome(from text: String) -> Double? {
        let patterns = [
            "Total Income[\\s\\S]*?([0-9,]+\\.?[0-9]*)",
            "Gross Income[\\s\\S]*?([0-9,]+\\.?[0-9]*)",
            "Line 9[\\s\\S]*?([0-9,]+\\.?[0-9]*)"
        ]
        return extractFirstCurrencyMatch(patterns: patterns, from: text)
    }

    func extractTaxLiability(from text: String) -> Double? {
        let patterns = [
            "Tax[\\s]*Liability[\\s\\S]*?([0-9,]+\\.?[0-9]*)",
            "Total Tax[\\s\\S]*?([0-9,]+\\.?[0-9]*)",
            "Line 24[\\s\\S]*?([0-9,]+\\.?[0-9]*)"
        ]
        return extractFirstCurrencyMatch(patterns: patterns, from: text)
    }

    func extractFilingStatus(from text: String) -> FilingStatus? {
        let statusPatterns = [
            ("Single", FilingStatus.single),
            ("Married Filing Jointly", FilingStatus.marriedFilingJointly),
            ("Married Filing Separately", FilingStatus.marriedFilingSeparately),
            ("Head of Household", FilingStatus.headOfHousehold),
            ("Qualifying Widow", FilingStatus.qualifyingWidow)
        ]

        for (pattern, status) in statusPatterns {
            if text.localizedCaseInsensitiveContains(pattern) {
                return status
            }
        }

        return nil
    }

    func extractDependents(from text: String) -> Int? {
        let patterns = [
            "Dependents[\\s\\S]*?([0-9]+)",
            "Number of dependents[\\s\\S]*?([0-9]+)",
            "Line 6c[\\s\\S]*?([0-9]+)"
        ]

        for pattern in patterns {
            if let match = extractFirstNumberMatch(pattern: pattern, from: text) {
                return Int(match)
            }
        }

        return nil
    }

    func extractTaxYear(from text: String) -> Int? {
        let patterns = [
            "(20[0-9]{2})\\s*Tax Return",
            "Form 1040.*?(20[0-9]{2})",
            "Tax Year[\\s]*(20[0-9]{2})"
        ]

        for pattern in patterns {
            if let match = extractFirstNumberMatch(pattern: pattern, from: text) {
                return Int(match)
            }
        }

        return nil
    }

    func extractRefundAmount(from text: String) -> Double? {
        let patterns = [
            "Refund[\\s\\S]*?([0-9,]+\\.?[0-9]*)",
            "Amount You Owe[\\s\\S]*?([0-9,]+\\.?[0-9]*)",
            "Line 35[\\s\\S]*?([0-9,]+\\.?[0-9]*)"
        ]
        return extractFirstCurrencyMatch(patterns: patterns, from: text)
    }

    func extractPreparedBy(from text: String) -> String? {
        let patterns = [
            "Prepared by[\\s]*:?[\\s]*([A-Za-z\\s,]+)",
            "Tax Preparer[\\s]*:?[\\s]*([A-Za-z\\s,]+)",
            "CPA[\\s]*:?[\\s]*([A-Za-z\\s,]+)"
        ]

        for pattern in patterns {
            if let match = extractFirstStringMatch(pattern: pattern, from: text) {
                return match.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    func extractTaxDeductions(from text: String) -> TaxDeductions {
        let standardDeduction = extractFirstCurrencyMatch(
            patterns: ["Standard Deduction[\\s\\S]*?([0-9,]+\\.?[0-9]*)"],
            from: text
        )

        let itemizedDeductions = extractFirstCurrencyMatch(
            patterns: ["Itemized Deductions[\\s\\S]*?([0-9,]+\\.?[0-9]*)"],
            from: text
        )

        let mortgageInterest = extractFirstCurrencyMatch(
            patterns: ["Mortgage Interest[\\s\\S]*?([0-9,]+\\.?[0-9]*)"],
            from: text
        )

        let stateAndLocalTaxes = extractFirstCurrencyMatch(
            patterns: ["State and Local Taxes[\\s\\S]*?([0-9,]+\\.?[0-9]*)"],
            from: text
        )

        let charitableContributions = extractFirstCurrencyMatch(
            patterns: ["Charitable[\\s]*Contributions[\\s\\S]*?([0-9,]+\\.?[0-9]*)"],
            from: text
        )

        return TaxDeductions(
            standardDeduction: standardDeduction,
            itemizedDeductions: itemizedDeductions,
            mortgageInterest: mortgageInterest,
            stateAndLocalTaxes: stateAndLocalTaxes,
            charitableContributions: charitableContributions
        )
    }

    func calculateTaxReturnExtractionConfidence(
        agi: Double?,
        totalIncome: Double?,
        taxLiability: Double?,
        filingStatus: FilingStatus?,
        deductions: TaxDeductions
    ) -> Double {
        var score = 0.0
        var maxScore = 5.0

        if agi != nil { score += 1.5 }
        if totalIncome != nil { score += 1.0 }
        if taxLiability != nil { score += 1.0 }
        if filingStatus != nil { score += 1.0 }
        if deductions.standardDeduction != nil || deductions.itemizedDeductions != nil { score += 0.5 }

        return min(score / maxScore, 1.0)
    }

    // MARK: - Property Appraisal Field Extraction

    func extractAppraisedValue(from text: String) -> Double? {
        let patterns = [
            "Appraised Value[\\s\\S]*?\\$?([0-9,]+\\.?[0-9]*)",
            "Market Value[\\s\\S]*?\\$?([0-9,]+\\.?[0-9]*)",
            "Opinion of Value[\\s\\S]*?\\$?([0-9,]+\\.?[0-9]*)",
            "Final Value[\\s\\S]*?\\$?([0-9,]+\\.?[0-9]*)"
        ]
        return extractFirstCurrencyMatch(patterns: patterns, from: text)
    }

    func extractAppraisalDate(from text: String) -> Date? {
        let patterns = [
            "Date of Appraisal[\\s]*:?[\\s]*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})",
            "Effective Date[\\s]*:?[\\s]*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})",
            "Inspection Date[\\s]*:?[\\s]*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})"
        ]

        for pattern in patterns {
            if let dateString = extractFirstStringMatch(pattern: pattern, from: text) {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yyyy"
                if let date = formatter.date(from: dateString) {
                    return date
                }
                formatter.dateFormat = "MM-dd-yyyy"
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
        }

        return nil
    }

    func extractPropertyAddress(from text: String) -> String? {
        let patterns = [
            "Property Address[\\s]*:?[\\s]*([0-9]+[^\\n\\r]*)",
            "Subject Property[\\s]*:?[\\s]*([0-9]+[^\\n\\r]*)",
            "Address[\\s]*:?[\\s]*([0-9]+[^\\n\\r]*)"
        ]

        for pattern in patterns {
            if let match = extractFirstStringMatch(pattern: pattern, from: text) {
                return match.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    func extractSquareFootage(from text: String) -> Int? {
        let patterns = [
            "Square Feet[\\s]*:?[\\s]*([0-9,]+)",
            "Sq\\.*\\s*Ft[\\s]*:?[\\s]*([0-9,]+)",
            "GLA[\\s]*:?[\\s]*([0-9,]+)",
            "Living Area[\\s]*:?[\\s]*([0-9,]+)"
        ]

        for pattern in patterns {
            if let match = extractFirstNumberMatch(pattern: pattern, from: text) {
                return Int(match)
            }
        }

        return nil
    }

    func extractLotSize(from text: String) -> Double? {
        let patterns = [
            "Lot Size[\\s]*:?[\\s]*([0-9.]+)",
            "Site[\\s]*:?[\\s]*([0-9.]+)\\s*acres",
            "Land Area[\\s]*:?[\\s]*([0-9.]+)"
        ]
        return extractFirstCurrencyMatch(patterns: patterns, from: text)
    }

    func extractYearBuilt(from text: String) -> Int? {
        let patterns = [
            "Year Built[\\s]*:?[\\s]*([0-9]{4})",
            "Built[\\s]*:?[\\s]*([0-9]{4})",
            "Construction[\\s]*:?[\\s]*([0-9]{4})"
        ]

        for pattern in patterns {
            if let match = extractFirstNumberMatch(pattern: pattern, from: text) {
                return Int(match)
            }
        }

        return nil
    }

    func extractPropertyType(from text: String) -> String? {
        let patterns = [
            "Property Type[\\s]*:?[\\s]*([A-Za-z\\s]+)",
            "Type[\\s]*:?[\\s]*([A-Za-z\\s]+)"
        ]

        for pattern in patterns {
            if let match = extractFirstStringMatch(pattern: pattern, from: text) {
                return match.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    func extractConditionRating(from text: String) -> PropertyCondition? {
        let conditionMappings = [
            ("Excellent", PropertyCondition.excellent),
            ("Good", PropertyCondition.good),
            ("Average", PropertyCondition.average),
            ("Fair", PropertyCondition.fair),
            ("Poor", PropertyCondition.poor)
        ]

        for (keyword, condition) in conditionMappings {
            if text.localizedCaseInsensitiveContains(keyword) {
                return condition
            }
        }

        return nil
    }

    func extractComparableSales(from text: String) -> [ComparableSale] {
        var comparables: [ComparableSale] = []

        // Look for comparable sales sections
        let compPattern = "Comparable[\\s]*Sale[\\s]*[#]?[0-9]+"
        let regex = try? NSRegularExpression(pattern: compPattern, options: .caseInsensitive)
        let nsText = text as NSString

        if let regex = regex {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

            for match in matches.prefix(6) { // Limit to 6 comparables
                let startRange = match.range.location
                let endRange = min(startRange + 500, nsText.length) // Extract 500 chars after match
                let sectionText = nsText.substring(with: NSRange(location: startRange, length: endRange - startRange))

                let address = extractComparableAddress(from: sectionText)
                let salePrice = extractComparablePrice(from: sectionText)
                let saleDate = extractComparableDate(from: sectionText)
                let squareFootage = extractComparableSquareFootage(from: sectionText)
                let adjustments = extractComparableAdjustments(from: sectionText)

                let comparable = ComparableSale(
                    address: address,
                    salePrice: salePrice,
                    saleDate: saleDate,
                    squareFootage: squareFootage,
                    adjustments: adjustments
                )
                comparables.append(comparable)
            }
        }

        return comparables
    }

    func extractAppraiserName(from text: String) -> String? {
        let patterns = [
            "Appraiser[\\s]*:?[\\s]*([A-Za-z\\s,]+)",
            "Licensed Appraiser[\\s]*:?[\\s]*([A-Za-z\\s,]+)",
            "By[\\s]*:?[\\s]*([A-Za-z\\s,]+)"
        ]

        for pattern in patterns {
            if let match = extractFirstStringMatch(pattern: pattern, from: text) {
                return match.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    func extractAppraisalCompany(from text: String) -> String? {
        let patterns = [
            "Company[\\s]*:?[\\s]*([A-Za-z\\s,&]+)",
            "Appraisal Company[\\s]*:?[\\s]*([A-Za-z\\s,&]+)",
            "Firm[\\s]*:?[\\s]*([A-Za-z\\s,&]+)"
        ]

        for pattern in patterns {
            if let match = extractFirstStringMatch(pattern: pattern, from: text) {
                return match.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    func calculateAppraisalExtractionConfidence(
        appraisedValue: Double?,
        propertyAddress: String?,
        squareFootage: Int?,
        comparableSales: [ComparableSale]
    ) -> Double {
        var score = 0.0
        var maxScore = 4.0

        if appraisedValue != nil { score += 2.0 }
        if propertyAddress != nil { score += 1.0 }
        if squareFootage != nil { score += 0.5 }
        if !comparableSales.isEmpty { score += 0.5 }

        return min(score / maxScore, 1.0)
    }

    // MARK: - Bank Statement Field Extraction

    func extractAccountNumber(from text: String) -> String? {
        let patterns = [
            "Account Number[\\s]*:?[\\s]*([0-9X\\*\\-]+)",
            "Account[\\s]*#[\\s]*:?[\\s]*([0-9X\\*\\-]+)",
            "Acct[\\s]*:?[\\s]*([0-9X\\*\\-]+)"
        ]

        for pattern in patterns {
            if let match = extractFirstStringMatch(pattern: pattern, from: text) {
                return match.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    func extractBankName(from text: String) -> String? {
        let bankNames = [
            "Chase", "Bank of America", "Wells Fargo", "Citibank", "US Bank",
            "PNC Bank", "Capital One", "TD Bank", "Regions Bank", "Fifth Third",
            "KeyBank", "Huntington", "BBVA", "SunTrust", "BB&T"
        ]

        for bankName in bankNames {
            if text.localizedCaseInsensitiveContains(bankName) {
                return bankName
            }
        }

        // Generic pattern matching
        let patterns = [
            "([A-Za-z\\s]+)\\s*Bank",
            "([A-Za-z\\s]+)\\s*Credit Union"
        ]

        for pattern in patterns {
            if let match = extractFirstStringMatch(pattern: pattern, from: text) {
                return match.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    func extractStatementPeriod(from text: String) -> DateInterval? {
        let patterns = [
            "Statement Period[\\s]*:?[\\s]*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})\\s*to\\s*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})",
            "Period[\\s]*:?[\\s]*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})\\s*-\\s*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})"
        ]

        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let nsText = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

                if let match = matches.first, match.numberOfRanges >= 3 {
                    let startDateString = nsText.substring(with: match.range(at: 1))
                    let endDateString = nsText.substring(with: match.range(at: 2))

                    let formatter = DateFormatter()
                    formatter.dateFormat = "MM/dd/yyyy"

                    if let startDate = formatter.date(from: startDateString),
                       let endDate = formatter.date(from: endDateString) {
                        return DateInterval(start: startDate, end: endDate)
                    }
                }
            } catch {
                continue
            }
        }

        return nil
    }

    func extractOpeningBalance(from text: String) -> Double? {
        let patterns = [
            "Opening Balance[\\s\\S]*?\\$?([0-9,]+\\.?[0-9]*)",
            "Beginning Balance[\\s\\S]*?\\$?([0-9,]+\\.?[0-9]*)",
            "Previous Balance[\\s\\S]*?\\$?([0-9,]+\\.?[0-9]*)"
        ]
        return extractFirstCurrencyMatch(patterns: patterns, from: text)
    }

    func extractClosingBalance(from text: String) -> Double? {
        let patterns = [
            "Closing Balance[\\s\\S]*?\\$?([0-9,]+\\.?[0-9]*)",
            "Ending Balance[\\s\\S]*?\\$?([0-9,]+\\.?[0-9]*)",
            "Current Balance[\\s\\S]*?\\$?([0-9,]+\\.?[0-9]*)"
        ]
        return extractFirstCurrencyMatch(patterns: patterns, from: text)
    }

    func extractInterestEarned(from text: String) -> Double? {
        let patterns = [
            "Interest Earned[\\s\\S]*?\\$?([0-9,]+\\.?[0-9]*)",
            "Interest Income[\\s\\S]*?\\$?([0-9,]+\\.?[0-9]*)",
            "INT[\\s\\S]*?\\$?([0-9,]+\\.?[0-9]*)"
        ]
        return extractFirstCurrencyMatch(patterns: patterns, from: text)
    }

    func extractBankTransactions(from text: String, observations: [VNRecognizedTextObservation]) async -> [BankTransaction] {
        var transactions: [BankTransaction] = []

        // Split text into lines for transaction parsing
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            if let transaction = parseBankTransactionLine(line) {
                transactions.append(transaction)
            }
        }

        return transactions
    }

    func extractBankFees(from text: String) -> [BankFee] {
        var fees: [BankFee] = []

        let feePatterns = [
            "Monthly Service Fee[\\s\\S]*?\\$([0-9.]+)",
            "ATM Fee[\\s\\S]*?\\$([0-9.]+)",
            "Overdraft Fee[\\s\\S]*?\\$([0-9.]+)",
            "Wire Transfer Fee[\\s\\S]*?\\$([0-9.]+)"
        ]

        for pattern in feePatterns {
            if let amount = extractFirstCurrencyMatch(patterns: [pattern], from: text) {
                let feeType = pattern.components(separatedBy: "[")[0]
                let fee = BankFee(type: feeType, amount: amount, date: nil)
                fees.append(fee)
            }
        }

        return fees
    }

    func calculateAverageDailyBalance(
        openingBalance: Double?,
        closingBalance: Double?,
        transactions: [BankTransaction]
    ) -> Double? {
        guard let opening = openingBalance, let closing = closingBalance else { return nil }

        // Simple average for now - in production would calculate actual daily balances
        return (opening + closing) / 2.0
    }

    func calculateBankStatementExtractionConfidence(
        accountNumber: String?,
        bankName: String?,
        openingBalance: Double?,
        closingBalance: Double?,
        transactions: [BankTransaction]
    ) -> Double {
        var score = 0.0
        var maxScore = 5.0

        if accountNumber != nil { score += 1.0 }
        if bankName != nil { score += 1.0 }
        if openingBalance != nil { score += 1.5 }
        if closingBalance != nil { score += 1.5 }
        if !transactions.isEmpty { score += 1.0 }

        return min(score / maxScore, 1.0)
    }

    // MARK: - Pay Stub Field Extraction

    func extractEmployerName(from text: String) -> String? {
        let patterns = [
            "Employer[\\s]*:?[\\s]*([A-Za-z\\s,&.]+)",
            "Company[\\s]*:?[\\s]*([A-Za-z\\s,&.]+)",
            "Pay from[\\s]*:?[\\s]*([A-Za-z\\s,&.]+)"
        ]

        for pattern in patterns {
            if let match = extractFirstStringMatch(pattern: pattern, from: text) {
                return match.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    func extractEmployeeName(from text: String) -> String? {
        let patterns = [
            "Employee[\\s]*:?[\\s]*([A-Za-z\\s,]+)",
            "Name[\\s]*:?[\\s]*([A-Za-z\\s,]+)",
            "Pay to[\\s]*:?[\\s]*([A-Za-z\\s,]+)"
        ]

        for pattern in patterns {
            if let match = extractFirstStringMatch(pattern: pattern, from: text) {
                return match.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    func extractPayPeriod(from text: String) -> DateInterval? {
        let patterns = [
            "Pay Period[\\s]*:?[\\s]*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})\\s*to\\s*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})",
            "Period[\\s]*:?[\\s]*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})\\s*-\\s*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})"
        ]

        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let nsText = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

                if let match = matches.first, match.numberOfRanges >= 3 {
                    let startDateString = nsText.substring(with: match.range(at: 1))
                    let endDateString = nsText.substring(with: match.range(at: 2))

                    let formatter = DateFormatter()
                    formatter.dateFormat = "MM/dd/yyyy"

                    if let startDate = formatter.date(from: startDateString),
                       let endDate = formatter.date(from: endDateString) {
                        return DateInterval(start: startDate, end: endDate)
                    }
                }
            } catch {
                continue
            }
        }

        return nil
    }

    func extractPayRate(from text: String) -> Double? {
        let patterns = [
            "Pay Rate[\\s]*:?[\\s]*\\$?([0-9.]+)",
            "Hourly Rate[\\s]*:?[\\s]*\\$?([0-9.]+)",
            "Rate[\\s]*:?[\\s]*\\$?([0-9.]+)"
        ]
        return extractFirstCurrencyMatch(patterns: patterns, from: text)
    }

    func extractHoursWorked(from text: String) -> Double? {
        let patterns = [
            "Hours Worked[\\s]*:?[\\s]*([0-9.]+)",
            "Total Hours[\\s]*:?[\\s]*([0-9.]+)",
            "Reg Hours[\\s]*:?[\\s]*([0-9.]+)"
        ]
        return extractFirstCurrencyMatch(patterns: patterns, from: text)
    }

    func extractGrossPay(from text: String) -> PayAmount? {
        let currentPatterns = [
            "Gross Pay[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)",
            "Gross[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)",
            "Total Gross[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"
        ]

        let ytdPatterns = [
            "Gross Pay YTD[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)",
            "YTD Gross[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"
        ]

        let current = extractFirstCurrencyMatch(patterns: currentPatterns, from: text) ?? 0.0
        let ytd = extractFirstCurrencyMatch(patterns: ytdPatterns, from: text) ?? 0.0

        return PayAmount(current: current, yearToDate: ytd)
    }

    func extractNetPay(from text: String) -> PayAmount? {
        let currentPatterns = [
            "Net Pay[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)",
            "Net[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)",
            "Take Home[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"
        ]

        let ytdPatterns = [
            "Net Pay YTD[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)",
            "YTD Net[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"
        ]

        let current = extractFirstCurrencyMatch(patterns: currentPatterns, from: text) ?? 0.0
        let ytd = extractFirstCurrencyMatch(patterns: ytdPatterns, from: text) ?? 0.0

        return PayAmount(current: current, yearToDate: ytd)
    }

    func extractPayrollDeductions(from text: String) -> PayrollDeductions {
        let healthInsurance = extractFirstCurrencyMatch(
            patterns: ["Health[\\s]*Insurance[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"],
            from: text
        )

        let dentalInsurance = extractFirstCurrencyMatch(
            patterns: ["Dental[\\s]*Insurance[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"],
            from: text
        )

        let retirement401k = extractFirstCurrencyMatch(
            patterns: ["401[kK][\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"],
            from: text
        )

        let lifeInsurance = extractFirstCurrencyMatch(
            patterns: ["Life[\\s]*Insurance[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"],
            from: text
        )

        return PayrollDeductions(
            healthInsurance: healthInsurance,
            dentalInsurance: dentalInsurance,
            retirement401k: retirement401k,
            lifeInsurance: lifeInsurance,
            otherDeductions: [:]
        )
    }

    func extractPayrollTaxes(from text: String) -> PayrollTaxes {
        let federalIncomeTax = extractFirstCurrencyMatch(
            patterns: ["Federal[\\s]*Income[\\s]*Tax[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"],
            from: text
        )

        let stateIncomeTax = extractFirstCurrencyMatch(
            patterns: ["State[\\s]*Income[\\s]*Tax[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"],
            from: text
        )

        let socialSecurityTax = extractFirstCurrencyMatch(
            patterns: ["Social[\\s]*Security[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"],
            from: text
        )

        let medicareTax = extractFirstCurrencyMatch(
            patterns: ["Medicare[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"],
            from: text
        )

        return PayrollTaxes(
            federalIncomeTax: federalIncomeTax,
            stateIncomeTax: stateIncomeTax,
            socialSecurityTax: socialSecurityTax,
            medicareTax: medicareTax,
            otherTaxes: [:]
        )
    }

    func extractYearToDateTotals(from text: String) -> YearToDateTotals? {
        let grossPay = extractFirstCurrencyMatch(
            patterns: ["YTD[\\s]*Gross[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"],
            from: text
        ) ?? 0.0

        let netPay = extractFirstCurrencyMatch(
            patterns: ["YTD[\\s]*Net[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"],
            from: text
        ) ?? 0.0

        let federalTax = extractFirstCurrencyMatch(
            patterns: ["YTD[\\s]*Federal[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"],
            from: text
        ) ?? 0.0

        let stateTax = extractFirstCurrencyMatch(
            patterns: ["YTD[\\s]*State[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"],
            from: text
        ) ?? 0.0

        let socialSecurity = extractFirstCurrencyMatch(
            patterns: ["YTD[\\s]*Social[\\s]*Security[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"],
            from: text
        ) ?? 0.0

        let medicare = extractFirstCurrencyMatch(
            patterns: ["YTD[\\s]*Medicare[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"],
            from: text
        ) ?? 0.0

        return YearToDateTotals(
            grossPay: grossPay,
            netPay: netPay,
            federalTax: federalTax,
            stateTax: stateTax,
            socialSecurity: socialSecurity,
            medicare: medicare
        )
    }

    func calculatePayStubExtractionConfidence(
        employerName: String?,
        grossPay: PayAmount?,
        netPay: PayAmount?,
        deductions: PayrollDeductions,
        taxes: PayrollTaxes
    ) -> Double {
        var score = 0.0
        var maxScore = 5.0

        if employerName != nil { score += 1.0 }
        if grossPay?.current != 0 { score += 1.5 }
        if netPay?.current != 0 { score += 1.5 }
        if taxes.federalIncomeTax != nil || taxes.stateIncomeTax != nil { score += 0.5 }
        if deductions.healthInsurance != nil || deductions.retirement401k != nil { score += 0.5 }

        return min(score / maxScore, 1.0)
    }

    // MARK: - ML Confidence and Quality Assessment

    func calculateMLConfidenceScores(
        structuredData: DocumentStructuredData,
        nlpInsights: NLPInsights,
        observations: [VNRecognizedTextObservation]
    ) -> [String: Double] {
        var scores: [String: Double] = [:]

        // Base extraction confidence
        scores["extraction"] = structuredData.extractionConfidence

        // OCR quality assessment
        if !observations.isEmpty {
            let ocrConfidences = observations.compactMap { $0.topCandidates(1).first?.confidence }
            scores["ocr_quality"] = ocrConfidences.reduce(0.0, +) / Double(ocrConfidences.count)
        } else {
            scores["ocr_quality"] = 0.8 // Default for text-based analysis
        }

        // NLP analysis quality
        scores["nlp_quality"] = calculateNLPQuality(nlpInsights: nlpInsights)

        // Named entity confidence
        let entityConfidences = nlpInsights.namedEntities.map { $0.confidence }
        scores["entity_recognition"] = entityConfidences.isEmpty ? 0.5 : entityConfidences.reduce(0.0, +) / Double(entityConfidences.count)

        return scores
    }

    func assessExtractionQuality(
        structuredData: DocumentStructuredData,
        rawText: String,
        observations: [VNRecognizedTextObservation]
    ) -> ExtractionQuality {
        // Calculate overall quality metrics
        let overallScore = structuredData.extractionConfidence

        // Text clarity assessment
        let textClarity = assessTextClarity(rawText: rawText, observations: observations)

        // Structural integrity assessment
        let structuralIntegrity = assessStructuralIntegrity(structuredData: structuredData)

        // Data completeness assessment
        let dataCompleteness = assessDataCompleteness(structuredData: structuredData)

        return ExtractionQuality(
            overallScore: overallScore,
            textClarity: textClarity,
            structuralIntegrity: structuralIntegrity,
            dataCompleteness: dataCompleteness
        )
    }

    // MARK: - Utility Functions

    private func extractFirstCurrencyMatch(patterns: [String], from text: String) -> Double? {
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let nsText = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

                if let match = matches.first, match.numberOfRanges > 1 {
                    let numberString = nsText.substring(with: match.range(at: 1))
                    let cleanedNumber = numberString.replacingOccurrences(of: ",", with: "")
                    return Double(cleanedNumber)
                }
            } catch {
                continue
            }
        }
        return nil
    }

    private func extractFirstNumberMatch(pattern: String, from text: String) -> Double? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let nsText = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

            if let match = matches.first, match.numberOfRanges > 1 {
                let numberString = nsText.substring(with: match.range(at: 1))
                return Double(numberString)
            }
        } catch {
            return nil
        }
        return nil
    }

    private func extractFirstStringMatch(pattern: String, from text: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let nsText = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

            if let match = matches.first, match.numberOfRanges > 1 {
                return nsText.substring(with: match.range(at: 1))
            }
        } catch {
            return nil
        }
        return nil
    }

    private func parseBankTransactionLine(_ line: String) -> BankTransaction? {
        // Simple transaction parsing - in production would be more sophisticated
        let components = line.components(separatedBy: " ")
        guard components.count >= 3 else { return nil }

        // Look for date pattern
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"

        var date: Date?
        var description = ""
        var amount: Double = 0.0

        for component in components {
            if date == nil, let parsedDate = dateFormatter.date(from: component) {
                date = parsedDate
            } else if amount == 0.0, let parsedAmount = Double(component.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) {
                amount = parsedAmount
            } else {
                description += " " + component
            }
        }

        guard date != nil, !description.isEmpty else { return nil }

        let type = categorizeTransactionType(description: description, amount: amount)
        let category = categorizeTransaction(description: description)

        return BankTransaction(
            date: date,
            description: description.trimmingCharacters(in: .whitespaces),
            amount: amount,
            type: type,
            category: category,
            confidence: 0.7
        )
    }

    private func categorizeTransactionType(description: String, amount: Double) -> TransactionType {
        let desc = description.lowercased()

        if desc.contains("check") {
            return .check
        } else if desc.contains("transfer") {
            return .transfer
        } else if desc.contains("fee") {
            return .fee
        } else if desc.contains("interest") {
            return .interest
        } else if amount > 0 {
            return .credit
        } else {
            return .debit
        }
    }

    private func categorizeTransaction(description: String) -> TransactionCategory {
        let desc = description.lowercased()

        if desc.contains("salary") || desc.contains("payroll") || desc.contains("wages") {
            return .salary
        } else if desc.contains("mortgage") || desc.contains("loan") {
            return .mortgage
        } else if desc.contains("utility") || desc.contains("electric") || desc.contains("gas") {
            return .utilities
        } else if desc.contains("grocery") || desc.contains("food") {
            return .groceries
        } else if desc.contains("gas") || desc.contains("fuel") {
            return .gasoline
        } else if desc.contains("insurance") {
            return .insurance
        } else if desc.contains("medical") || desc.contains("doctor") {
            return .medical
        } else if desc.contains("restaurant") || desc.contains("dining") {
            return .restaurant
        } else if desc.contains("transfer") {
            return .transfer
        } else if desc.contains("fee") {
            return .fee
        } else {
            return .other
        }
    }

    // MARK: - Comparable Sales Helper Functions

    private func extractComparableAddress(from text: String) -> String? {
        let patterns = [
            "([0-9]+[^\\n\\r]*)",
            "Address[\\s]*:?[\\s]*([^\\n\\r]*)"
        ]

        for pattern in patterns {
            if let match = extractFirstStringMatch(pattern: pattern, from: text) {
                return match.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    private func extractComparablePrice(from text: String) -> Double? {
        let patterns = [
            "Sale Price[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)",
            "Price[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)",
            "\\$([0-9,]+\\.?[0-9]*)"
        ]
        return extractFirstCurrencyMatch(patterns: patterns, from: text)
    }

    private func extractComparableDate(from text: String) -> Date? {
        let patterns = [
            "Sale Date[\\s]*:?[\\s]*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})",
            "Date[\\s]*:?[\\s]*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})"
        ]

        for pattern in patterns {
            if let dateString = extractFirstStringMatch(pattern: pattern, from: text) {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yyyy"
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
        }

        return nil
    }

    private func extractComparableSquareFootage(from text: String) -> Int? {
        let patterns = [
            "Square Feet[\\s]*:?[\\s]*([0-9,]+)",
            "Sq\\.?\\s*Ft[\\s]*:?[\\s]*([0-9,]+)",
            "([0-9,]+)\\s*sq"
        ]

        for pattern in patterns {
            if let match = extractFirstNumberMatch(pattern: pattern, from: text) {
                return Int(match)
            }
        }

        return nil
    }

    private func extractComparableAdjustments(from text: String) -> Double? {
        let patterns = [
            "Adjustments[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)",
            "Adj[\\s]*:?[\\s]*\\$?([0-9,]+\\.?[0-9]*)"
        ]
        return extractFirstCurrencyMatch(patterns: patterns, from: text)
    }

    // MARK: - Quality Assessment Helper Functions

    private func calculateNLPQuality(nlpInsights: NLPInsights) -> Double {
        var score = 0.0

        // Language detection confidence
        if nlpInsights.languageDetection == "en" {
            score += 0.3
        }

        // Named entity quality
        if !nlpInsights.namedEntities.isEmpty {
            let avgEntityConfidence = nlpInsights.namedEntities.map { $0.confidence }.reduce(0.0, +) / Double(nlpInsights.namedEntities.count)
            score += avgEntityConfidence * 0.4
        }

        // Key phrase quality
        if !nlpInsights.keyPhrases.isEmpty {
            score += 0.3
        }

        return min(score, 1.0)
    }

    private func assessTextClarity(rawText: String, observations: [VNRecognizedTextObservation]) -> Double {
        if !observations.isEmpty {
            let confidences = observations.compactMap { $0.topCandidates(1).first?.confidence }
            return confidences.reduce(0.0, +) / Double(confidences.count)
        }

        // Text-based quality assessment
        let wordCount = rawText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let characterCount = rawText.count

        // Simple heuristic: reasonable word-to-character ratio indicates good text quality
        if wordCount > 0 && characterCount > 0 {
            let ratio = Double(characterCount) / Double(wordCount)
            return min(ratio / 6.0, 1.0) // Average word length around 6 characters
        }

        return 0.5
    }

    private func assessStructuralIntegrity(structuredData: DocumentStructuredData) -> Double {
        // Assess how well the document structure was understood
        switch structuredData.documentType {
        case .taxReturn:
            if let data = structuredData as? TaxReturnData {
                var score = 0.0
                if data.adjustedGrossIncome != nil { score += 0.3 }
                if data.totalIncome != nil { score += 0.3 }
                if data.taxLiability != nil { score += 0.2 }
                if data.filingStatus != nil { score += 0.2 }
                return score
            }
        case .propertyAppraisal:
            if let data = structuredData as? PropertyAppraisalData {
                var score = 0.0
                if data.appraisedValue != nil { score += 0.4 }
                if data.propertyAddress != nil { score += 0.3 }
                if data.squareFootage != nil { score += 0.2 }
                if !data.comparableSales.isEmpty { score += 0.1 }
                return score
            }
        case .bankStatement:
            if let data = structuredData as? EnhancedBankStatementData {
                var score = 0.0
                if data.accountNumber != nil { score += 0.2 }
                if data.openingBalance != nil { score += 0.3 }
                if data.closingBalance != nil { score += 0.3 }
                if !data.transactions.isEmpty { score += 0.2 }
                return score
            }
        case .payStub:
            if let data = structuredData as? EnhancedPayStubData {
                var score = 0.0
                if data.employerName != nil { score += 0.2 }
                if data.grossPay?.current != 0 { score += 0.4 }
                if data.netPay?.current != 0 { score += 0.4 }
                return score
            }
        }

        return 0.5
    }

    private func assessDataCompleteness(structuredData: DocumentStructuredData) -> Double {
        // Assess how complete the extracted data is
        return structuredData.extractionConfidence
    }
}