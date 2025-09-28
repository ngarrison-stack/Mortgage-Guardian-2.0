import Vision
import VisionKit
import SwiftUI
import CoreML
import NaturalLanguage
import OSLog
import Foundation

@Observable
class DocumentAnalysisService {
    enum DocumentType {
        case bankStatement
        case payStub
        case taxReturn
        case propertyAppraisal
    }
    
    struct DocumentAnalysisResult {
        let type: DocumentType
        let extractedData: [String: Any]
        let confidence: Double
        let date: Date
        let mlResults: MLAnalysisResult?
    }

    struct MLAnalysisResult {
        let structuredData: DocumentStructuredData
        let nlpInsights: NLPInsights
        let confidenceScores: [String: Double]
        let extractionQuality: ExtractionQuality
    }

    struct NLPInsights {
        let languageDetection: String
        let sentimentAnalysis: Double?
        let keyPhrases: [String]
        let namedEntities: [NamedEntity]
    }

    struct NamedEntity {
        let text: String
        let category: NLLanguageTag
        let confidence: Double
        let range: NSRange
    }

    struct ExtractionQuality {
        let overallScore: Double // 0.0 - 1.0
        let textClarity: Double
        let structuralIntegrity: Double
        let dataCompleteness: Double
    }

    protocol DocumentStructuredData {
        var documentType: DocumentType { get }
        var extractionConfidence: Double { get }
    }

    struct TaxReturnData: DocumentStructuredData {
        let documentType = DocumentType.taxReturn
        let extractionConfidence: Double

        let adjustedGrossIncome: Double?
        let totalIncome: Double?
        let taxLiability: Double?
        let deductions: TaxDeductions
        let filingStatus: FilingStatus?
        let dependents: Int?
        let taxYear: Int?
        let refundAmount: Double?
        let preparedBy: String?
    }

    struct TaxDeductions {
        let standardDeduction: Double?
        let itemizedDeductions: Double?
        let mortgageInterest: Double?
        let stateAndLocalTaxes: Double?
        let charitableContributions: Double?
    }

    enum FilingStatus: String, CaseIterable {
        case single = "Single"
        case marriedFilingJointly = "Married Filing Jointly"
        case marriedFilingSeparately = "Married Filing Separately"
        case headOfHousehold = "Head of Household"
        case qualifyingWidow = "Qualifying Widow(er)"
    }

    struct PropertyAppraisalData: DocumentStructuredData {
        let documentType = DocumentType.propertyAppraisal
        let extractionConfidence: Double

        let appraisedValue: Double?
        let effectiveDate: Date?
        let propertyAddress: String?
        let squareFootage: Int?
        let lotSize: Double?
        let yearBuilt: Int?
        let propertyType: String?
        let conditionRating: PropertyCondition?
        let comparableSales: [ComparableSale]
        let appraiserName: String?
        let appraisalCompany: String?
    }

    enum PropertyCondition: String, CaseIterable {
        case excellent = "Excellent"
        case good = "Good"
        case average = "Average"
        case fair = "Fair"
        case poor = "Poor"
    }

    struct ComparableSale {
        let address: String?
        let salePrice: Double?
        let saleDate: Date?
        let squareFootage: Int?
        let adjustments: Double?
    }

    struct EnhancedBankStatementData: DocumentStructuredData {
        let documentType = DocumentType.bankStatement
        let extractionConfidence: Double

        let accountNumber: String?
        let bankName: String?
        let statementPeriod: DateInterval?
        let openingBalance: Double?
        let closingBalance: Double?
        let transactions: [BankTransaction]
        let fees: [BankFee]
        let interestEarned: Double?
        let averageDailyBalance: Double?
    }

    struct BankTransaction {
        let date: Date?
        let description: String
        let amount: Double
        let type: TransactionType
        let category: TransactionCategory
        let confidence: Double
    }

    enum TransactionType: String, CaseIterable {
        case debit = "Debit"
        case credit = "Credit"
        case check = "Check"
        case transfer = "Transfer"
        case fee = "Fee"
        case interest = "Interest"
    }

    enum TransactionCategory: String, CaseIterable {
        case salary = "Salary/Wages"
        case mortgage = "Mortgage Payment"
        case utilities = "Utilities"
        case groceries = "Groceries"
        case gasoline = "Gasoline"
        case insurance = "Insurance"
        case medical = "Medical"
        case entertainment = "Entertainment"
        case restaurant = "Restaurant"
        case shopping = "Shopping"
        case transfer = "Transfer"
        case fee = "Bank Fee"
        case other = "Other"
    }

    struct BankFee {
        let type: String
        let amount: Double
        let date: Date?
    }

    struct EnhancedPayStubData: DocumentStructuredData {
        let documentType = DocumentType.payStub
        let extractionConfidence: Double

        let employerName: String?
        let employeeName: String?
        let payPeriod: DateInterval?
        let grossPay: PayAmount?
        let netPay: PayAmount?
        let deductions: PayrollDeductions
        let taxes: PayrollTaxes
        let yearToDateTotals: YearToDateTotals?
        let payRate: Double?
        let hoursWorked: Double?
    }

    struct PayAmount {
        let current: Double
        let yearToDate: Double
    }

    struct PayrollDeductions {
        let healthInsurance: Double?
        let dentalInsurance: Double?
        let retirement401k: Double?
        let lifeInsurance: Double?
        let otherDeductions: [String: Double]
    }

    struct PayrollTaxes {
        let federalIncomeTax: Double?
        let stateIncomeTax: Double?
        let socialSecurityTax: Double?
        let medicareTax: Double?
        let otherTaxes: [String: Double]
    }

    struct YearToDateTotals {
        let grossPay: Double
        let netPay: Double
        let federalTax: Double
        let stateTax: Double
        let socialSecurity: Double
        let medicare: Double
    }
    
    private let defaultRecognitionLanguages = ["en-US"]
    private let logger = Logger(subsystem: "com.mortgageguardian.analysis", category: "DocumentAnalysis")

    // ML and NLP components
    private let nlProcessor = NLTagger(tagSchemes: [.nameType, .language, .sentiment])
    private var documentClassificationModel: MLModel?
    private var fieldExtractionModel: MLModel?

    // Pattern matching for structured data extraction
    private let currencyPattern = "\\$?([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?)"
    private let datePattern = "\\b(?:0?[1-9]|1[0-2])[/-](?:0?[1-9]|[12]\\d|3[01])[/-](?:19|20)?\\d{2}\\b"
    private let ssnPattern = "\\b\\d{3}-\\d{2}-\\d{4}\\b"
    private let phonePattern = "\\b(?:\\+?1[-.]?)?\\(?([0-9]{3})\\)?[-.]?([0-9]{3})[-.]?([0-9]{4})\\b"

    init() {
        loadMLModels()
    }

    func analyzeDocument(_ image: CGImage, expectedType: DocumentType) async throws -> DocumentAnalysisResult {
        // Try Google Cloud Vision OCR if API key present; otherwise fall back to local Vision framework
        var rawText = ""
        var observations: [VNRecognizedTextObservation] = []

        do {
            // Attempt Google OCR first (throws if missing key)
            rawText = try await googleService.analyzeImage(image, languageHints: ["en"])
        } catch {
            // Fallback to Vision OCR
            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = false
            textRequest.recognitionLanguages = defaultRecognitionLanguages

            let requestHandler = VNImageRequestHandler(cgImage: image)
            try await requestHandler.perform([textRequest])

            guard let obs = textRequest.results else {
                throw NSError(domain: "DocumentAnalysis", code: -1, userInfo: [NSLocalizedDescriptionKey: "No text found"])
            }
            observations = obs
            rawText = obs.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        }

        // Basic parsed data
        var extractedData: [String: Any] = [:]

        switch expectedType {
        case .bankStatement:
            if !observations.isEmpty {
                extractedData = try await analyzeBankStatement(observations: observations, rawText: rawText)
            } else {
                extractedData = try await analyzeBankStatement(text: [rawText])
            }
        case .payStub:
            if !observations.isEmpty {
                extractedData = try await analyzePayStub(observations: observations, rawText: rawText)
            } else {
                extractedData = try await analyzePayStub(text: [rawText])
            }
        case .taxReturn:
            if !observations.isEmpty {
                extractedData = try await analyzeTaxReturn(observations: observations, rawText: rawText)
            } else {
                extractedData = try await analyzeTaxReturn(text: [rawText])
            }
        case .propertyAppraisal:
            if !observations.isEmpty {
                extractedData = try await analyzePropertyAppraisal(observations: observations, rawText: rawText)
            } else {
                extractedData = try await analyzePropertyAppraisal(text: [rawText])
            }
        }

        // Perform ML analysis for enhanced extraction
        let mlResults = await performMLAnalysis(
            rawText: rawText,
            observations: observations,
            documentType: expectedType
        )

        let confidence = observations.isEmpty ? 1.0 : calculateConfidence(observations)
        return DocumentAnalysisResult(
            type: expectedType,
            extractedData: extractedData,
            confidence: confidence,
            date: Date(),
            mlResults: mlResults
        )
    }
    
    private func analyzeBankStatement(text: [String]) async throws -> [String: Any] {
        logger.info("Analyzing bank statement from text array")
        let fullText = text.joined(separator: "\n")
        return try await analyzeBankStatementFromText(fullText)
    }

    private func analyzeBankStatement(observations: [VNRecognizedTextObservation], rawText: String) async throws -> [String: Any] {
        logger.info("Analyzing bank statement from Vision observations")

        // Extract enhanced structured data using ML techniques
        let structuredData = try await extractEnhancedBankStatementData(observations: observations, rawText: rawText)

        return [
            "structured_data": structuredData,
            "opening_balance": structuredData.openingBalance ?? 0.0,
            "closing_balance": structuredData.closingBalance ?? 0.0,
            "transactions_count": structuredData.transactions.count,
            "total_fees": structuredData.fees.reduce(0.0) { $0 + $1.amount },
            "interest_earned": structuredData.interestEarned ?? 0.0,
            "account_number": structuredData.accountNumber ?? "",
            "bank_name": structuredData.bankName ?? "",
            "confidence": structuredData.extractionConfidence
        ]
    }

    private func analyzePayStub(text: [String]) async throws -> [String: Any] {
        logger.info("Analyzing pay stub from text array")
        let fullText = text.joined(separator: "\n")
        return try await analyzePayStubFromText(fullText)
    }

    private func analyzePayStub(observations: [VNRecognizedTextObservation], rawText: String) async throws -> [String: Any] {
        logger.info("Analyzing pay stub from Vision observations")

        // Extract enhanced structured data using ML techniques
        let structuredData = try await extractEnhancedPayStubData(observations: observations, rawText: rawText)

        return [
            "structured_data": structuredData,
            "gross_pay_current": structuredData.grossPay?.current ?? 0.0,
            "net_pay_current": structuredData.netPay?.current ?? 0.0,
            "gross_pay_ytd": structuredData.grossPay?.yearToDate ?? 0.0,
            "net_pay_ytd": structuredData.netPay?.yearToDate ?? 0.0,
            "employer_name": structuredData.employerName ?? "",
            "employee_name": structuredData.employeeName ?? "",
            "pay_rate": structuredData.payRate ?? 0.0,
            "hours_worked": structuredData.hoursWorked ?? 0.0,
            "confidence": structuredData.extractionConfidence
        ]
    }
    
    private func analyzeTaxReturn(text: [String]) async throws -> [String: Any] {
        logger.info("Analyzing tax return from text array")
        let fullText = text.joined(separator: "\n")
        return try await analyzeTaxReturnFromText(fullText)
    }

    private func analyzeTaxReturn(observations: [VNRecognizedTextObservation], rawText: String) async throws -> [String: Any] {
        logger.info("Analyzing tax return from Vision observations")

        // Extract structured data using ML techniques
        let structuredData = try await extractTaxReturnData(observations: observations, rawText: rawText)

        return [
            "structured_data": structuredData,
            "agi": structuredData.adjustedGrossIncome ?? 0.0,
            "total_income": structuredData.totalIncome ?? 0.0,
            "tax_liability": structuredData.taxLiability ?? 0.0,
            "filing_status": structuredData.filingStatus?.rawValue ?? "Unknown",
            "dependents": structuredData.dependents ?? 0,
            "tax_year": structuredData.taxYear ?? Calendar.current.component(.year, from: Date()),
            "confidence": structuredData.extractionConfidence
        ]
    }
    
    private func analyzePropertyAppraisal(text: [String]) async throws -> [String: Any] {
        logger.info("Analyzing property appraisal from text array")
        let fullText = text.joined(separator: "\n")
        return try await analyzePropertyAppraisalFromText(fullText)
    }

    private func analyzePropertyAppraisal(observations: [VNRecognizedTextObservation], rawText: String) async throws -> [String: Any] {
        logger.info("Analyzing property appraisal from Vision observations")

        // Extract structured data using ML techniques
        let structuredData = try await extractPropertyAppraisalData(observations: observations, rawText: rawText)

        return [
            "structured_data": structuredData,
            "appraised_value": structuredData.appraisedValue ?? 0.0,
            "property_address": structuredData.propertyAddress ?? "",
            "square_footage": structuredData.squareFootage ?? 0,
            "year_built": structuredData.yearBuilt ?? 0,
            "condition_rating": structuredData.conditionRating?.rawValue ?? "Unknown",
            "comparable_sales_count": structuredData.comparableSales.count,
            "confidence": structuredData.extractionConfidence
        ]
    }
    
    private func calculateConfidence(_ observations: [VNRecognizedTextObservation]) -> Double {
        let confidences = observations.compactMap { $0.topCandidates(1).first?.confidence }
        return confidences.reduce(0.0, +) / Double(confidences.count)
    }

    // MARK: - Simple text extraction helpers
    private func extractCurrencyNumbers(from text: String) -> [Double] {
        // Match patterns like $1,234.56 or 1,234.56
        let pattern = "\\$?([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?)"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let ns = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
            return matches.compactMap { m in
                if m.numberOfRanges > 1 {
                    let s = ns.substring(with: m.range(at: 1)).replacingOccurrences(of: ",", with: "")
                    return Double(s)
                }
                return nil
            }
        } catch {
            return []
        }
    }

    private func firstMatchingNumber(prefixes: [String], in text: String) -> Double? {
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            for prefix in prefixes {
                if line.localizedCaseInsensitiveContains(prefix) {
                    let nums = extractCurrencyNumbers(from: line)
                    if let first = nums.first { return first }
                }
            }
        }
        // Last ditch: return first currency-like number in the whole text
        return extractCurrencyNumbers(from: text).first
    }

    // MARK: - ML Model Loading and Management

    private func loadMLModels() {
        Task {
            await loadDocumentClassificationModel()
            await loadFieldExtractionModel()
        }
    }

    private func loadDocumentClassificationModel() async {
        do {
            if let modelURL = Bundle.main.url(forResource: "DocumentClassifier", withExtension: "mlmodelc") ??
                              Bundle.main.url(forResource: "DocumentClassifier", withExtension: "mlmodel") {
                documentClassificationModel = try MLModel(contentsOf: modelURL)
                logger.info("Loaded DocumentClassifier model")
            } else {
                logger.warning("DocumentClassifier model not found - using algorithmic fallback")
            }
        } catch {
            logger.error("Failed to load DocumentClassifier: \(error.localizedDescription)")
        }
    }

    private func loadFieldExtractionModel() async {
        do {
            if let modelURL = Bundle.main.url(forResource: "FieldExtractor", withExtension: "mlmodelc") ??
                              Bundle.main.url(forResource: "FieldExtractor", withExtension: "mlmodel") {
                fieldExtractionModel = try MLModel(contentsOf: modelURL)
                logger.info("Loaded FieldExtractor model")
            } else {
                logger.warning("FieldExtractor model not found - using algorithmic fallback")
            }
        } catch {
            logger.error("Failed to load FieldExtractor: \(error.localizedDescription)")
        }
    }

    // MARK: - ML Analysis Orchestration

    private func performMLAnalysis(
        rawText: String,
        observations: [VNRecognizedTextObservation],
        documentType: DocumentType
    ) async -> MLAnalysisResult? {
        do {
            logger.info("Performing ML analysis for document type: \(documentType)")

            // Perform NLP analysis
            let nlpInsights = await performNLPAnalysis(text: rawText)

            // Extract structured data based on document type
            let structuredData: DocumentStructuredData
            switch documentType {
            case .taxReturn:
                structuredData = try await extractTaxReturnData(observations: observations, rawText: rawText)
            case .propertyAppraisal:
                structuredData = try await extractPropertyAppraisalData(observations: observations, rawText: rawText)
            case .bankStatement:
                structuredData = try await extractEnhancedBankStatementData(observations: observations, rawText: rawText)
            case .payStub:
                structuredData = try await extractEnhancedPayStubData(observations: observations, rawText: rawText)
            }

            // Calculate confidence scores
            let confidenceScores = calculateMLConfidenceScores(
                structuredData: structuredData,
                nlpInsights: nlpInsights,
                observations: observations
            )

            // Assess extraction quality
            let extractionQuality = assessExtractionQuality(
                structuredData: structuredData,
                rawText: rawText,
                observations: observations
            )

            return MLAnalysisResult(
                structuredData: structuredData,
                nlpInsights: nlpInsights,
                confidenceScores: confidenceScores,
                extractionQuality: extractionQuality
            )
        } catch {
            logger.error("ML analysis failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - NLP Analysis

    private func performNLPAnalysis(text: String) async -> NLPInsights {
        logger.info("Performing NLP analysis")

        // Language detection
        nlProcessor.string = text
        let languageCode = nlProcessor.dominantLanguage?.rawValue ?? "en"

        // Named entity recognition
        let namedEntities = extractNamedEntities(from: text)

        // Key phrase extraction using statistical methods
        let keyPhrases = extractKeyPhrases(from: text)

        // Sentiment analysis (if applicable - mainly for document quality assessment)
        let sentiment = calculateDocumentSentiment(text: text)

        return NLPInsights(
            languageDetection: languageCode,
            sentimentAnalysis: sentiment,
            keyPhrases: keyPhrases,
            namedEntities: namedEntities
        )
    }

    private func extractNamedEntities(from text: String) -> [NamedEntity] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var entities: [NamedEntity] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                let entityText = String(text[range])
                let nsRange = NSRange(range, in: text)
                let confidence = 0.8 // Default confidence for NLTagger

                let entity = NamedEntity(
                    text: entityText,
                    category: tag,
                    confidence: confidence,
                    range: nsRange
                )
                entities.append(entity)
            }
            return true
        }

        return entities
    }

    private func extractKeyPhrases(from text: String) -> [String] {
        // Simple key phrase extraction using word frequency and patterns
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }

        let wordFreq = Dictionary(grouping: words, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }

        // Return top frequent words as key phrases
        return Array(wordFreq.prefix(10).map { $0.key })
    }

    private func calculateDocumentSentiment(text: String) -> Double? {
        let tagger = NLTagger(tagSchemes: [.sentiment])
        tagger.string = text

        var sentimentSum = 0.0
        var sentimentCount = 0

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .sentence, scheme: .sentiment) { tag, _ in
            if let sentiment = tag {
                switch sentiment {
                case .positive:
                    sentimentSum += 1.0
                case .negative:
                    sentimentSum -= 1.0
                case .neutral:
                    sentimentSum += 0.0
                default:
                    break
                }
                sentimentCount += 1
            }
            return true
        }

        return sentimentCount > 0 ? sentimentSum / Double(sentimentCount) : nil
    }

    // MARK: - Tax Return Analysis

    private func analyzeTaxReturnFromText(_ text: String) async throws -> [String: Any] {
        let structuredData = try await extractTaxReturnDataFromText(text)

        return [
            "structured_data": structuredData,
            "agi": structuredData.adjustedGrossIncome ?? 0.0,
            "total_income": structuredData.totalIncome ?? 0.0,
            "tax_liability": structuredData.taxLiability ?? 0.0,
            "filing_status": structuredData.filingStatus?.rawValue ?? "Unknown",
            "dependents": structuredData.dependents ?? 0,
            "tax_year": structuredData.taxYear ?? Calendar.current.component(.year, from: Date()),
            "confidence": structuredData.extractionConfidence
        ]
    }

    private func extractTaxReturnData(observations: [VNRecognizedTextObservation], rawText: String) async throws -> TaxReturnData {
        logger.info("Extracting tax return structured data")

        // Extract key financial figures using pattern matching
        let agi = extractAdjustedGrossIncome(from: rawText)
        let totalIncome = extractTotalIncome(from: rawText)
        let taxLiability = extractTaxLiability(from: rawText)
        let filingStatus = extractFilingStatus(from: rawText)
        let dependents = extractDependents(from: rawText)
        let taxYear = extractTaxYear(from: rawText)
        let refundAmount = extractRefundAmount(from: rawText)
        let preparedBy = extractPreparedBy(from: rawText)

        // Extract deductions
        let deductions = extractTaxDeductions(from: rawText)

        // Calculate extraction confidence
        let confidence = calculateTaxReturnExtractionConfidence(
            agi: agi,
            totalIncome: totalIncome,
            taxLiability: taxLiability,
            filingStatus: filingStatus,
            deductions: deductions
        )

        return TaxReturnData(
            extractionConfidence: confidence,
            adjustedGrossIncome: agi,
            totalIncome: totalIncome,
            taxLiability: taxLiability,
            deductions: deductions,
            filingStatus: filingStatus,
            dependents: dependents,
            taxYear: taxYear,
            refundAmount: refundAmount,
            preparedBy: preparedBy
        )
    }

    private func extractTaxReturnDataFromText(_ text: String) async throws -> TaxReturnData {
        logger.info("Extracting tax return data from plain text")

        // Use the same extraction logic as the observation-based method
        let agi = extractAdjustedGrossIncome(from: text)
        let totalIncome = extractTotalIncome(from: text)
        let taxLiability = extractTaxLiability(from: text)
        let filingStatus = extractFilingStatus(from: text)
        let dependents = extractDependents(from: text)
        let taxYear = extractTaxYear(from: text)
        let refundAmount = extractRefundAmount(from: text)
        let preparedBy = extractPreparedBy(from: text)

        // Extract deductions
        let deductions = extractTaxDeductions(from: text)

        // Calculate extraction confidence
        let confidence = calculateTaxReturnExtractionConfidence(
            agi: agi,
            totalIncome: totalIncome,
            taxLiability: taxLiability,
            filingStatus: filingStatus,
            deductions: deductions
        )

        return TaxReturnData(
            extractionConfidence: confidence,
            adjustedGrossIncome: agi,
            totalIncome: totalIncome,
            taxLiability: taxLiability,
            deductions: deductions,
            filingStatus: filingStatus,
            dependents: dependents,
            taxYear: taxYear,
            refundAmount: refundAmount,
            preparedBy: preparedBy
        )
    }

    // MARK: - Property Appraisal Analysis

    private func analyzePropertyAppraisalFromText(_ text: String) async throws -> [String: Any] {
        let structuredData = try await extractPropertyAppraisalDataFromText(text)

        return [
            "structured_data": structuredData,
            "appraised_value": structuredData.appraisedValue ?? 0.0,
            "property_address": structuredData.propertyAddress ?? "",
            "square_footage": structuredData.squareFootage ?? 0,
            "year_built": structuredData.yearBuilt ?? 0,
            "condition_rating": structuredData.conditionRating?.rawValue ?? "Unknown",
            "comparable_sales_count": structuredData.comparableSales.count,
            "confidence": structuredData.extractionConfidence
        ]
    }

    private func extractPropertyAppraisalData(observations: [VNRecognizedTextObservation], rawText: String) async throws -> PropertyAppraisalData {
        logger.info("Extracting property appraisal structured data")

        // Extract key property information
        let appraisedValue = extractAppraisedValue(from: rawText)
        let effectiveDate = extractAppraisalDate(from: rawText)
        let propertyAddress = extractPropertyAddress(from: rawText)
        let squareFootage = extractSquareFootage(from: rawText)
        let lotSize = extractLotSize(from: rawText)
        let yearBuilt = extractYearBuilt(from: rawText)
        let propertyType = extractPropertyType(from: rawText)
        let conditionRating = extractConditionRating(from: rawText)
        let comparableSales = extractComparableSales(from: rawText)
        let appraiserName = extractAppraiserName(from: rawText)
        let appraisalCompany = extractAppraisalCompany(from: rawText)

        // Calculate extraction confidence
        let confidence = calculateAppraisalExtractionConfidence(
            appraisedValue: appraisedValue,
            propertyAddress: propertyAddress,
            squareFootage: squareFootage,
            comparableSales: comparableSales
        )

        return PropertyAppraisalData(
            extractionConfidence: confidence,
            appraisedValue: appraisedValue,
            effectiveDate: effectiveDate,
            propertyAddress: propertyAddress,
            squareFootage: squareFootage,
            lotSize: lotSize,
            yearBuilt: yearBuilt,
            propertyType: propertyType,
            conditionRating: conditionRating,
            comparableSales: comparableSales,
            appraiserName: appraiserName,
            appraisalCompany: appraisalCompany
        )
    }

    private func extractPropertyAppraisalDataFromText(_ text: String) async throws -> PropertyAppraisalData {
        logger.info("Extracting property appraisal data from plain text")

        // Use the same extraction logic
        let appraisedValue = extractAppraisedValue(from: text)
        let effectiveDate = extractAppraisalDate(from: text)
        let propertyAddress = extractPropertyAddress(from: text)
        let squareFootage = extractSquareFootage(from: text)
        let lotSize = extractLotSize(from: text)
        let yearBuilt = extractYearBuilt(from: text)
        let propertyType = extractPropertyType(from: text)
        let conditionRating = extractConditionRating(from: text)
        let comparableSales = extractComparableSales(from: text)
        let appraiserName = extractAppraiserName(from: text)
        let appraisalCompany = extractAppraisalCompany(from: text)

        let confidence = calculateAppraisalExtractionConfidence(
            appraisedValue: appraisedValue,
            propertyAddress: propertyAddress,
            squareFootage: squareFootage,
            comparableSales: comparableSales
        )

        return PropertyAppraisalData(
            extractionConfidence: confidence,
            appraisedValue: appraisedValue,
            effectiveDate: effectiveDate,
            propertyAddress: propertyAddress,
            squareFootage: squareFootage,
            lotSize: lotSize,
            yearBuilt: yearBuilt,
            propertyType: propertyType,
            conditionRating: conditionRating,
            comparableSales: comparableSales,
            appraiserName: appraiserName,
            appraisalCompany: appraisalCompany
        )
    }

    // MARK: - Enhanced Bank Statement Analysis

    private func analyzeBankStatementFromText(_ text: String) async throws -> [String: Any] {
        let structuredData = try await extractEnhancedBankStatementDataFromText(text)

        return [
            "structured_data": structuredData,
            "opening_balance": structuredData.openingBalance ?? 0.0,
            "closing_balance": structuredData.closingBalance ?? 0.0,
            "transactions_count": structuredData.transactions.count,
            "total_fees": structuredData.fees.reduce(0.0) { $0 + $1.amount },
            "interest_earned": structuredData.interestEarned ?? 0.0,
            "account_number": structuredData.accountNumber ?? "",
            "bank_name": structuredData.bankName ?? "",
            "confidence": structuredData.extractionConfidence
        ]
    }

    private func extractEnhancedBankStatementData(observations: [VNRecognizedTextObservation], rawText: String) async throws -> EnhancedBankStatementData {
        logger.info("Extracting enhanced bank statement structured data")

        // Extract account information
        let accountNumber = extractAccountNumber(from: rawText)
        let bankName = extractBankName(from: rawText)
        let statementPeriod = extractStatementPeriod(from: rawText)
        let openingBalance = extractOpeningBalance(from: rawText)
        let closingBalance = extractClosingBalance(from: rawText)
        let interestEarned = extractInterestEarned(from: rawText)

        // Extract transactions with enhanced categorization
        let transactions = await extractBankTransactions(from: rawText, observations: observations)

        // Extract fees
        let fees = extractBankFees(from: rawText)

        // Calculate average daily balance
        let averageDailyBalance = calculateAverageDailyBalance(
            openingBalance: openingBalance,
            closingBalance: closingBalance,
            transactions: transactions
        )

        // Calculate extraction confidence
        let confidence = calculateBankStatementExtractionConfidence(
            accountNumber: accountNumber,
            bankName: bankName,
            openingBalance: openingBalance,
            closingBalance: closingBalance,
            transactions: transactions
        )

        return EnhancedBankStatementData(
            extractionConfidence: confidence,
            accountNumber: accountNumber,
            bankName: bankName,
            statementPeriod: statementPeriod,
            openingBalance: openingBalance,
            closingBalance: closingBalance,
            transactions: transactions,
            fees: fees,
            interestEarned: interestEarned,
            averageDailyBalance: averageDailyBalance
        )
    }

    private func extractEnhancedBankStatementDataFromText(_ text: String) async throws -> EnhancedBankStatementData {
        logger.info("Extracting enhanced bank statement data from plain text")

        // Use the same extraction logic without observations
        let accountNumber = extractAccountNumber(from: text)
        let bankName = extractBankName(from: text)
        let statementPeriod = extractStatementPeriod(from: text)
        let openingBalance = extractOpeningBalance(from: text)
        let closingBalance = extractClosingBalance(from: text)
        let interestEarned = extractInterestEarned(from: text)

        // Extract transactions
        let transactions = await extractBankTransactions(from: text, observations: [])

        // Extract fees
        let fees = extractBankFees(from: text)

        // Calculate average daily balance
        let averageDailyBalance = calculateAverageDailyBalance(
            openingBalance: openingBalance,
            closingBalance: closingBalance,
            transactions: transactions
        )

        let confidence = calculateBankStatementExtractionConfidence(
            accountNumber: accountNumber,
            bankName: bankName,
            openingBalance: openingBalance,
            closingBalance: closingBalance,
            transactions: transactions
        )

        return EnhancedBankStatementData(
            extractionConfidence: confidence,
            accountNumber: accountNumber,
            bankName: bankName,
            statementPeriod: statementPeriod,
            openingBalance: openingBalance,
            closingBalance: closingBalance,
            transactions: transactions,
            fees: fees,
            interestEarned: interestEarned,
            averageDailyBalance: averageDailyBalance
        )
    }

    // MARK: - Enhanced Pay Stub Analysis

    private func analyzePayStubFromText(_ text: String) async throws -> [String: Any] {
        let structuredData = try await extractEnhancedPayStubDataFromText(text)

        return [
            "structured_data": structuredData,
            "gross_pay_current": structuredData.grossPay?.current ?? 0.0,
            "net_pay_current": structuredData.netPay?.current ?? 0.0,
            "gross_pay_ytd": structuredData.grossPay?.yearToDate ?? 0.0,
            "net_pay_ytd": structuredData.netPay?.yearToDate ?? 0.0,
            "employer_name": structuredData.employerName ?? "",
            "employee_name": structuredData.employeeName ?? "",
            "pay_rate": structuredData.payRate ?? 0.0,
            "hours_worked": structuredData.hoursWorked ?? 0.0,
            "confidence": structuredData.extractionConfidence
        ]
    }

    private func extractEnhancedPayStubData(observations: [VNRecognizedTextObservation], rawText: String) async throws -> EnhancedPayStubData {
        logger.info("Extracting enhanced pay stub structured data")

        // Extract basic information
        let employerName = extractEmployerName(from: rawText)
        let employeeName = extractEmployeeName(from: rawText)
        let payPeriod = extractPayPeriod(from: rawText)
        let payRate = extractPayRate(from: rawText)
        let hoursWorked = extractHoursWorked(from: rawText)

        // Extract pay amounts
        let grossPay = extractGrossPay(from: rawText)
        let netPay = extractNetPay(from: rawText)

        // Extract deductions
        let deductions = extractPayrollDeductions(from: rawText)

        // Extract taxes
        let taxes = extractPayrollTaxes(from: rawText)

        // Extract year-to-date totals
        let ytdTotals = extractYearToDateTotals(from: rawText)

        // Calculate extraction confidence
        let confidence = calculatePayStubExtractionConfidence(
            employerName: employerName,
            grossPay: grossPay,
            netPay: netPay,
            deductions: deductions,
            taxes: taxes
        )

        return EnhancedPayStubData(
            extractionConfidence: confidence,
            employerName: employerName,
            employeeName: employeeName,
            payPeriod: payPeriod,
            grossPay: grossPay,
            netPay: netPay,
            deductions: deductions,
            taxes: taxes,
            yearToDateTotals: ytdTotals,
            payRate: payRate,
            hoursWorked: hoursWorked
        )
    }

    private func extractEnhancedPayStubDataFromText(_ text: String) async throws -> EnhancedPayStubData {
        logger.info("Extracting enhanced pay stub data from plain text")

        // Use the same extraction logic
        let employerName = extractEmployerName(from: text)
        let employeeName = extractEmployeeName(from: text)
        let payPeriod = extractPayPeriod(from: text)
        let payRate = extractPayRate(from: text)
        let hoursWorked = extractHoursWorked(from: text)

        let grossPay = extractGrossPay(from: text)
        let netPay = extractNetPay(from: text)
        let deductions = extractPayrollDeductions(from: text)
        let taxes = extractPayrollTaxes(from: text)
        let ytdTotals = extractYearToDateTotals(from: text)

        let confidence = calculatePayStubExtractionConfidence(
            employerName: employerName,
            grossPay: grossPay,
            netPay: netPay,
            deductions: deductions,
            taxes: taxes
        )

        return EnhancedPayStubData(
            extractionConfidence: confidence,
            employerName: employerName,
            employeeName: employeeName,
            payPeriod: payPeriod,
            grossPay: grossPay,
            netPay: netPay,
            deductions: deductions,
            taxes: taxes,
            yearToDateTotals: ytdTotals,
            payRate: payRate,
            hoursWorked: hoursWorked
        )
    }
}