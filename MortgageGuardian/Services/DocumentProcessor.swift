import Foundation
import Vision
import UIKit
import CoreImage
import PDFKit
import Combine
import os.log

/// Comprehensive document processor for mortgage documents with Vision Framework OCR
/// Handles image preprocessing, text extraction, and structured data parsing
@MainActor
public final class DocumentProcessor: ObservableObject {

    // MARK: - Types

    /// Document processing errors
    public enum ProcessingError: LocalizedError {
        case invalidImageData
        case unsupportedFileFormat
        case ocrProcessingFailed(Error)
        case imagePreprocessingFailed(String)
        case documentParsingFailed(String)
        case insufficientTextConfidence
        case memoryLimitExceeded
        case processingTimeout
        case documentTooLarge
        case securityValidationFailed

        public var errorDescription: String? {
            switch self {
            case .invalidImageData:
                return "Invalid or corrupted image data"
            case .unsupportedFileFormat:
                return "Unsupported file format. Please use JPEG, PNG, HEIC, or PDF"
            case .ocrProcessingFailed(let error):
                return "Text recognition failed: \(error.localizedDescription)"
            case .imagePreprocessingFailed(let reason):
                return "Image preprocessing failed: \(reason)"
            case .documentParsingFailed(let reason):
                return "Document parsing failed: \(reason)"
            case .insufficientTextConfidence:
                return "Text recognition confidence too low. Please ensure document is clear and well-lit"
            case .memoryLimitExceeded:
                return "Document too large to process in available memory"
            case .processingTimeout:
                return "Document processing timed out. Please try again"
            case .documentTooLarge:
                return "Document size exceeds maximum limit (50MB)"
            case .securityValidationFailed:
                return "Document failed security validation"
            }
        }
    }

    /// Processing progress information
    public struct ProcessingProgress {
        let currentStep: ProcessingStep
        let percentComplete: Double
        let message: String

        public enum ProcessingStep: String, CaseIterable {
            case validation = "Validating document"
            case preprocessing = "Preprocessing image"
            case ocrProcessing = "Extracting text"
            case dataExtraction = "Parsing mortgage data"
            case verification = "Verifying results"
            case completion = "Processing complete"
        }
    }

    /// OCR configuration options
    public struct OCRConfiguration {
        let recognitionLevel: VNRequestTextRecognitionLevel
        let minimumTextHeight: Float
        let usesLanguageCorrection: Bool
        let recognitionLanguages: [String]
        let customWords: [String]

        public static let `default` = OCRConfiguration(
            recognitionLevel: .accurate,
            minimumTextHeight: 0.03,
            usesLanguageCorrection: true,
            recognitionLanguages: ["en-US"],
            customWords: ["escrow", "servicer", "mortgage", "principal", "APR"]
        )

        public static let fast = OCRConfiguration(
            recognitionLevel: .fast,
            minimumTextHeight: 0.04,
            usesLanguageCorrection: false,
            recognitionLanguages: ["en-US"],
            customWords: []
        )
    }

    /// Extracted text with confidence and location
    public struct OCRResult {
        let text: String
        let confidence: Float
        let boundingBox: CGRect
        let recognizedStrings: [RecognizedString]

        public struct RecognizedString {
            let text: String
            let confidence: Float
            let boundingBox: CGRect
        }
    }

    /// Enhanced payment record with RESPA compliance tracking
    public struct EnhancedPaymentRecord {
        let paymentDate: Date
        let amount: Double
        let principalApplied: Double?
        let interestApplied: Double?
        let escrowApplied: Double?
        let lateFeesApplied: Double?
        let unappliedFunds: Double?
        let suspenseAmount: Double?
        let isLate: Bool
        let daysLate: Int?
        let servicerFormat: ServicerFormat
        let confidenceScore: Double
        let respaViolations: [RESPAViolation]
        let allocationErrors: [PaymentAllocationError]

        public enum ServicerFormat: String, CaseIterable {
            case wellsFargo = "Wells Fargo"
            case quickenLoans = "Quicken Loans"
            case rocketMortgage = "Rocket Mortgage"
            case chase = "Chase"
            case bankOfAmerica = "Bank of America"
            case mrCooper = "Mr. Cooper"
            case freedomMortgage = "Freedom Mortgage"
            case caliber = "Caliber Home Loans"
            case pennymac = "PennyMac"
            case ocwen = "Ocwen"
            case generic = "Generic"
        }

        public enum RESPAViolation: String, CaseIterable {
            case improperEscrowAllocation = "Improper escrow allocation"
            case lateFeeMiscalculation = "Late fee miscalculation"
            case principalInterestMisallocation = "Principal/interest misallocation"
            case unappliedFundsDelay = "Delayed application of funds"
            case escrowOverpayment = "Escrow overpayment"
            case escrowUnderpayment = "Escrow underpayment"
        }

        public enum PaymentAllocationError: String, CaseIterable {
            case totalMismatch = "Payment total doesn't match allocation sum"
            case negativeAllocation = "Negative allocation amount"
            case missingEscrowAllocation = "Missing required escrow allocation"
            case excessiveLateFee = "Excessive late fee"
            case incorrectInterestCalculation = "Incorrect interest calculation"
        }
    }

    /// Table structure detection result
    public struct TableStructure {
        let columnHeaders: [String]
        let columnPositions: [CGRect]
        let rowCount: Int
        let confidenceScore: Double
        let tableType: TableType

        public enum TableType {
            case paymentHistory
            case escrowBreakdown
            case feeSchedule
            case amortizationSchedule
        }
    }

    /// Confidence scoring for extracted data
    public struct ConfidenceScore {
        let overallConfidence: Double
        let ocrConfidence: Double
        let formatRecognitionConfidence: Double
        let crossValidationConfidence: Double
        let patternMatchConfidence: Double

        public var isReliable: Bool {
            return overallConfidence >= 0.8
        }

        public var qualityLevel: QualityLevel {
            switch overallConfidence {
            case 0.9...1.0: return .excellent
            case 0.8..<0.9: return .good
            case 0.6..<0.8: return .fair
            case 0.4..<0.6: return .poor
            default: return .unreliable
            }
        }

        public enum QualityLevel: String {
            case excellent = "Excellent"
            case good = "Good"
            case fair = "Fair"
            case poor = "Poor"
            case unreliable = "Unreliable"
        }
    }

    // MARK: - Properties

    private let securityService: SecurityService
    private let logger = Logger(subsystem: "com.mortgageguardian", category: "DocumentProcessor")
    private let processingQueue = DispatchQueue(label: "document.processing", qos: .userInitiated)
    private let maxDocumentSize: Int = 50 * 1024 * 1024 // 50MB
    private let processingTimeout: TimeInterval = 120 // 2 minutes

    @Published public var currentProgress: ProcessingProgress?
    @Published public var isProcessing = false

    // Enhanced pattern matchers with servicer-specific templates
    private let documentTypePatterns: [MortgageDocument.DocumentType: [NSRegularExpression]] = {
        var patterns: [MortgageDocument.DocumentType: [NSRegularExpression]] = [:]

        // Mortgage Statement patterns (enhanced with servicer-specific formats)
        patterns[.mortgageStatement] = [
            try! NSRegularExpression(pattern: "mortgage\\s+statement", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "loan\\s+statement", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "principal\\s+balance", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "unpaid\\s+principal\\s+balance", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "current\\s+balance", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "monthly\\s+payment", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "next\\s+payment\\s+due", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "loan\\s+servicer", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "account\\s+number", options: .caseInsensitive),
            // Servicer-specific patterns
            try! NSRegularExpression(pattern: "wells\\s+fargo\\s+home\\s+mortgage", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "quicken\\s+loans", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "rocket\\s+mortgage", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "chase\\s+home\\s+lending", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "bank\\s+of\\s+america\\s+home\\s+loans", options: .caseInsensitive)
        ]

        // Escrow Statement patterns (enhanced with detailed categories)
        patterns[.escrowStatement] = [
            try! NSRegularExpression(pattern: "escrow\\s+(statement|analysis|account)", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "annual\\s+escrow\\s+analysis", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "escrow\\s+shortage", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "escrow\\s+surplus", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "property\\s+tax", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "real\\s+estate\\s+tax", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "homeowner.?s?\\s+insurance", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "hazard\\s+insurance", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "flood\\s+insurance", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "mortgage\\s+insurance\\s+premium", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "escrow\\s+balance", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "projected\\s+balance", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "cushion\\s+amount", options: .caseInsensitive)
        ]

        // Payment History patterns (enhanced with allocation details)
        patterns[.paymentHistory] = [
            try! NSRegularExpression(pattern: "payment\\s+history", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "transaction\\s+history", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "payment\\s+activity", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "payment\\s+date", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "effective\\s+date", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "late\\s+fee", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "principal\\s+applied", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "interest\\s+applied", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "escrow\\s+applied", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "unapplied\\s+funds", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "suspense\\s+account", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "partial\\s+payment", options: .caseInsensitive)
        ]

        // Add 1098 Mortgage Interest Statement patterns
        patterns[.mortgageInterestStatement] = [
            try! NSRegularExpression(pattern: "form\\s+1098", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "mortgage\\s+interest\\s+statement", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "mortgage\\s+interest\\s+received", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "points\\s+paid", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "outstanding\\s+mortgage\\s+principal", options: .caseInsensitive)
        ]

        return patterns
    }()

    // MARK: - Initialization

    public init(securityService: SecurityService) {
        self.securityService = securityService
    }

    // MARK: - Public API

    /// Process document from image data
    public func processDocument(
        from imageData: Data,
        fileName: String,
        configuration: OCRConfiguration = .default
    ) async throws -> MortgageDocument {
        guard !isProcessing else {
            throw ProcessingError.ocrProcessingFailed(NSError(domain: "DocumentProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Processing already in progress"]))
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            // Validate document
            try await validateDocument(data: imageData, fileName: fileName)

            // Preprocess image
            let preprocessedImage = try await preprocessImage(from: imageData)

            // Perform OCR
            let ocrResult = try await performOCR(on: preprocessedImage, configuration: configuration)

            // Extract structured data
            let extractedData = try await extractMortgageData(from: ocrResult)

            // Detect document type
            let documentType = detectDocumentType(from: ocrResult.text)

            // Create document
            let document = MortgageDocument(
                fileName: fileName,
                documentType: documentType,
                uploadDate: Date(),
                originalText: ocrResult.text,
                extractedData: extractedData,
                analysisResults: [],
                isAnalyzed: false
            )

            updateProgress(.completion, percentComplete: 100, message: "Document processed successfully")

            logger.info("Document processed successfully: \(fileName)")
            return document

        } catch {
            logger.error("Document processing failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Process document from PDF
    public func processDocument(
        from pdfData: Data,
        fileName: String,
        configuration: OCRConfiguration = .default
    ) async throws -> MortgageDocument {
        guard !isProcessing else {
            throw ProcessingError.ocrProcessingFailed(NSError(domain: "DocumentProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Processing already in progress"]))
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            // Validate PDF
            try await validateDocument(data: pdfData, fileName: fileName)

            // Convert PDF to images
            let images = try await convertPDFToImages(pdfData: pdfData)

            var allText = ""
            var allRecognizedStrings: [OCRResult.RecognizedString] = []

            // Process each page
            for (index, image) in images.enumerated() {
                updateProgress(.ocrProcessing, percentComplete: Double(index) / Double(images.count) * 70, message: "Processing page \(index + 1) of \(images.count)")

                let ocrResult = try await performOCR(on: image, configuration: configuration)
                allText += ocrResult.text + "\n"
                allRecognizedStrings.append(contentsOf: ocrResult.recognizedStrings)
            }

            let combinedOCRResult = OCRResult(
                text: allText.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: allRecognizedStrings.isEmpty ? 0 : allRecognizedStrings.map { $0.confidence }.reduce(0, +) / Float(allRecognizedStrings.count),
                boundingBox: CGRect.zero,
                recognizedStrings: allRecognizedStrings
            )

            // Extract structured data
            let extractedData = try await extractMortgageData(from: combinedOCRResult)

            // Detect document type
            let documentType = detectDocumentType(from: combinedOCRResult.text)

            // Create document
            let document = MortgageDocument(
                fileName: fileName,
                documentType: documentType,
                uploadDate: Date(),
                originalText: combinedOCRResult.text,
                extractedData: extractedData,
                analysisResults: [],
                isAnalyzed: false
            )

            updateProgress(.completion, percentComplete: 100, message: "PDF processed successfully")

            logger.info("PDF processed successfully: \(fileName)")
            return document

        } catch {
            logger.error("PDF processing failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Process multiple documents in batch
    public func processBatch(
        documents: [(data: Data, fileName: String)],
        configuration: OCRConfiguration = .default
    ) async throws -> [MortgageDocument] {
        guard !isProcessing else {
            throw ProcessingError.ocrProcessingFailed(NSError(domain: "DocumentProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Processing already in progress"]))
        }

        isProcessing = true
        defer { isProcessing = false }

        var processedDocuments: [MortgageDocument] = []

        for (index, document) in documents.enumerated() {
            updateProgress(.ocrProcessing, percentComplete: Double(index) / Double(documents.count) * 100, message: "Processing document \(index + 1) of \(documents.count)")

            do {
                let processed = try await processDocument(from: document.data, fileName: document.fileName, configuration: configuration)
                processedDocuments.append(processed)
            } catch {
                logger.error("Failed to process document \(document.fileName): \(error.localizedDescription)")
                // Continue with next document instead of failing entire batch
            }
        }

        updateProgress(.completion, percentComplete: 100, message: "Batch processing complete")
        return processedDocuments
    }

    // MARK: - Private Methods

    private func validateDocument(data: Data, fileName: String) async throws {
        updateProgress(.validation, percentComplete: 5, message: "Validating document format")

        // Check file size
        guard data.count <= maxDocumentSize else {
            throw ProcessingError.documentTooLarge
        }

        // Validate file format
        let supportedFormats = ["jpg", "jpeg", "png", "heic", "pdf"]
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()

        guard supportedFormats.contains(fileExtension) else {
            throw ProcessingError.unsupportedFileFormat
        }

        // Basic security validation
        if !securityService.validateFileIntegrity(data: data) {
            throw ProcessingError.securityValidationFailed
        }
    }

    private func preprocessImage(from data: Data) async throws -> UIImage {
        updateProgress(.preprocessing, percentComplete: 15, message: "Enhancing image quality")

        guard let originalImage = UIImage(data: data) else {
            throw ProcessingError.invalidImageData
        }

        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                do {
                    guard let self = self else {
                        continuation.resume(throwing: ProcessingError.imagePreprocessingFailed("Service deallocated"))
                        return
                    }

                    let processedImage = try self.enhanceImageForOCR(originalImage)
                    continuation.resume(returning: processedImage)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func enhanceImageForOCR(_ image: UIImage) throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw ProcessingError.imagePreprocessingFailed("Could not get CGImage")
        }

        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)

        // Apply filters for better OCR
        var enhancedImage = ciImage

        // 1. Convert to grayscale for better text recognition
        if let grayscaleFilter = CIFilter(name: "CIColorControls") {
            grayscaleFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
            grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey) // Remove color
            if let output = grayscaleFilter.outputImage {
                enhancedImage = output
            }
        }

        // 2. Enhance contrast
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.4, forKey: kCIInputContrastKey)
            contrastFilter.setValue(0.1, forKey: kCIInputBrightnessKey)
            if let output = contrastFilter.outputImage {
                enhancedImage = output
            }
        }

        // 3. Sharpen text
        if let sharpenFilter = CIFilter(name: "CIUnsharpMask") {
            sharpenFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.5, forKey: kCIInputIntensityKey)
            sharpenFilter.setValue(2.5, forKey: kCIInputRadiusKey)
            if let output = sharpenFilter.outputImage {
                enhancedImage = output
            }
        }

        // 4. Reduce noise
        if let noiseFilter = CIFilter(name: "CINoiseReduction") {
            noiseFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
            noiseFilter.setValue(0.02, forKey: kCIInputNoiseLevel)
            if let output = noiseFilter.outputImage {
                enhancedImage = output
            }
        }

        // Convert back to UIImage
        guard let processedCGImage = context.createCGImage(enhancedImage, from: enhancedImage.extent) else {
            throw ProcessingError.imagePreprocessingFailed("Could not create processed image")
        }

        return UIImage(cgImage: processedCGImage)
    }

    private func performOCR(on image: UIImage, configuration: OCRConfiguration) async throws -> OCRResult {
        updateProgress(.ocrProcessing, percentComplete: 40, message: "Recognizing text")

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: ProcessingError.ocrProcessingFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ProcessingError.ocrProcessingFailed(NSError(domain: "OCR", code: -1, userInfo: [NSLocalizedDescriptionKey: "No text observations found"])))
                    return
                }

                var recognizedStrings: [OCRResult.RecognizedString] = []
                var fullText = ""
                var totalConfidence: Float = 0

                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }

                    let recognizedString = OCRResult.RecognizedString(
                        text: topCandidate.string,
                        confidence: topCandidate.confidence,
                        boundingBox: observation.boundingBox
                    )

                    recognizedStrings.append(recognizedString)
                    fullText += topCandidate.string + " "
                    totalConfidence += topCandidate.confidence
                }

                let averageConfidence = recognizedStrings.isEmpty ? 0 : totalConfidence / Float(recognizedStrings.count)

                // Check minimum confidence threshold
                if averageConfidence < 0.5 {
                    continuation.resume(throwing: ProcessingError.insufficientTextConfidence)
                    return
                }

                let result = OCRResult(
                    text: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
                    confidence: averageConfidence,
                    boundingBox: CGRect.zero,
                    recognizedStrings: recognizedStrings
                )

                continuation.resume(returning: result)
            }

            // Configure OCR request
            request.recognitionLevel = configuration.recognitionLevel
            request.minimumTextHeight = configuration.minimumTextHeight
            request.usesLanguageCorrection = configuration.usesLanguageCorrection
            request.recognitionLanguages = configuration.recognitionLanguages
            request.customWords = configuration.customWords

            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: ProcessingError.invalidImageData)
                return
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ProcessingError.ocrProcessingFailed(error))
            }
        }
    }

    private func convertPDFToImages(pdfData: Data) async throws -> [UIImage] {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                guard let pdfDocument = PDFDocument(data: pdfData) else {
                    continuation.resume(throwing: ProcessingError.invalidImageData)
                    return
                }

                var images: [UIImage] = []

                for pageIndex in 0..<pdfDocument.pageCount {
                    guard let page = pdfDocument.page(at: pageIndex) else { continue }

                    let pageRect = page.bounds(for: .mediaBox)
                    let renderer = UIGraphicsImageRenderer(size: pageRect.size)

                    let image = renderer.image { context in
                        UIColor.white.set()
                        context.fill(pageRect)

                        context.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                        context.cgContext.scaleBy(x: 1.0, y: -1.0)

                        page.draw(with: .mediaBox, to: context.cgContext)
                    }

                    images.append(image)
                }

                continuation.resume(returning: images)
            }
        }
    }

    private func extractMortgageData(from ocrResult: OCRResult) async throws -> ExtractedData {
        updateProgress(.dataExtraction, percentComplete: 70, message: "Extracting mortgage information")

        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                do {
                    guard let self = self else {
                        continuation.resume(throwing: ProcessingError.documentParsingFailed("Service deallocated"))
                        return
                    }

                    // Parse basic mortgage document data
                    let extractedData = try self.parseMortgageDocument(text: ocrResult.text)

                    // Detect table structures for enhanced parsing
                    let tableStructures = self.detectTableStructure(from: ocrResult)

                    // Generate confidence score
                    let confidenceScore = self.generateConfidenceScore(for: extractedData, ocrResult: ocrResult)

                    // Detect common error patterns
                    let errorPatterns = self.detectCommonErrorPatterns(in: extractedData)

                    // Perform enhanced escrow analysis
                    let escrowIssues = self.performEnhancedEscrowAnalysis(for: extractedData)

                    // Log analysis results
                    self.logger.info("Document processing complete - Confidence: \(String(format: "%.2f", confidenceScore.overallConfidence)), Tables: \(tableStructures.count), Errors: \(errorPatterns.count)")

                    if !errorPatterns.isEmpty {
                        self.logger.warning("Detected error patterns: \(errorPatterns.joined(separator: "; "))")
                    }

                    if !escrowIssues.isEmpty {
                        self.logger.info("Escrow analysis issues: \(escrowIssues.joined(separator: "; "))")
                    }

                    continuation.resume(returning: extractedData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func parseMortgageDocument(text: String) throws -> ExtractedData {
        let normalizedText = text.lowercased()

        // Extract basic loan information
        let loanNumber = extractLoanNumber(from: text)
        let servicerName = extractServicerName(from: text)
        let borrowerName = extractBorrowerName(from: text)
        let propertyAddress = extractPropertyAddress(from: text)

        // Extract financial information
        let principalBalance = extractPrincipalBalance(from: text)
        let interestRate = extractInterestRate(from: text)
        let monthlyPayment = extractMonthlyPayment(from: text)
        let escrowBalance = extractEscrowBalance(from: text)
        let dueDate = extractDueDate(from: text)

        // Extract transaction data
        let paymentHistory = extractPaymentHistory(from: text)
        let escrowActivity = extractEscrowActivity(from: text)
        let fees = extractFees(from: text)

        return ExtractedData(
            loanNumber: loanNumber,
            servicerName: servicerName,
            borrowerName: borrowerName,
            propertyAddress: propertyAddress,
            principalBalance: principalBalance,
            interestRate: interestRate,
            monthlyPayment: monthlyPayment,
            escrowBalance: escrowBalance,
            dueDate: dueDate,
            paymentHistory: paymentHistory,
            escrowActivity: escrowActivity,
            fees: fees
        )
    }

    // MARK: - Data Extraction Methods

    private func extractLoanNumber(from text: String) -> String? {
        let patterns = [
            "loan\\s+(?:number|#)\\s*:?\\s*([A-Z0-9\\-]+)",
            "account\\s+(?:number|#)\\s*:?\\s*([A-Z0-9\\-]+)",
            "(?:loan|account)\\s*:?\\s*([A-Z0-9\\-]{8,})"
        ]

        return extractFirstMatch(from: text, patterns: patterns)
    }

    private func extractServicerName(from text: String) -> String? {
        let patterns = [
            "servicer\\s*:?\\s*([A-Za-z\\s&.,]+?)(?:\\n|\\s{3,})",
            "(?:loan\\s+)?serviced\\s+by\\s*:?\\s*([A-Za-z\\s&.,]+?)(?:\\n|\\s{3,})",
            "mortgage\\s+company\\s*:?\\s*([A-Za-z\\s&.,]+?)(?:\\n|\\s{3,})",
            "(?:your\\s+)?mortgage\\s+servicer\\s*:?\\s*([A-Za-z\\s&.,]+?)(?:\\n|\\s{3,})",
            // Specific servicer patterns for better recognition
            "(wells\\s+fargo\\s+home\\s+mortgage)",
            "(quicken\\s+loans)",
            "(rocket\\s+mortgage)",
            "(chase\\s+home\\s+lending)",
            "(bank\\s+of\\s+america\\s+home\\s+loans)",
            "(mr\\s+cooper)",
            "(freedom\\s+mortgage)",
            "(caliber\\s+home\\s+loans)",
            "(pennymac\\s+loan\\s+services)",
            "(ocwen\\s+loan\\s+servicing)",
            "(select\\s+portfolio\\s+servicing)",
            "(newrez\\s+llc)",
            "(loancare\\s+llc)",
            "(cenlar\\s+fsb)"
        ]

        let servicerName = extractFirstMatch(from: text, patterns: patterns)?.trimmingCharacters(in: .whitespacesAndNewlines)

        // Clean up common OCR artifacts in servicer names
        return cleanServicerName(servicerName)
    }

    private func cleanServicerName(_ name: String?) -> String? {
        guard let name = name else { return nil }

        // Remove common OCR artifacts and standardize names
        var cleaned = name
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Standardize common servicer name variations
        let nameMap: [String: String] = [
            "wells fargo home mortgage": "Wells Fargo Home Mortgage",
            "quicken loans": "Quicken Loans",
            "rocket mortgage": "Rocket Mortgage",
            "chase home lending": "Chase Home Lending",
            "bank of america home loans": "Bank of America Home Loans",
            "mr cooper": "Mr. Cooper",
            "freedom mortgage": "Freedom Mortgage Corporation",
            "caliber home loans": "Caliber Home Loans",
            "pennymac loan services": "PennyMac Loan Services",
            "ocwen loan servicing": "Ocwen Loan Servicing",
            "select portfolio servicing": "Select Portfolio Servicing",
            "newrez llc": "NewRez LLC",
            "loancare llc": "LoanCare LLC",
            "cenlar fsb": "Cenlar FSB"
        ]

        if let standardized = nameMap[cleaned.lowercased()] {
            cleaned = standardized
        }

        return cleaned.isEmpty ? nil : cleaned
    }

    private func extractBorrowerName(from text: String) -> String? {
        let patterns = [
            "borrower\\s*:?\\s*([A-Za-z\\s.,]+?)(?:\\n|\\s{3,})",
            "(?:account\\s+)?holder\\s*:?\\s*([A-Za-z\\s.,]+?)(?:\\n|\\s{3,})",
            "(?:primary\\s+)?borrower\\s+name\\s*:?\\s*([A-Za-z\\s.,]+?)(?:\\n|\\s{3,})"
        ]

        return extractFirstMatch(from: text, patterns: patterns)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractPropertyAddress(from text: String) -> String? {
        let patterns = [
            "property\\s+address\\s*:?\\s*([A-Za-z0-9\\s.,#\\-]+?)(?:\\n|\\s{3,})",
            "(?:loan\\s+)?property\\s*:?\\s*([A-Za-z0-9\\s.,#\\-]+?)(?:\\n|\\s{3,})",
            "collateral\\s+address\\s*:?\\s*([A-Za-z0-9\\s.,#\\-]+?)(?:\\n|\\s{3,})"
        ]

        return extractFirstMatch(from: text, patterns: patterns)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractPrincipalBalance(from text: String) -> Double? {
        let patterns = [
            "principal\\s+balance\\s*:?\\s*\\$?([0-9,]+\\.?[0-9]*)",
            "(?:current\\s+)?principal\\s*:?\\s*\\$?([0-9,]+\\.?[0-9]*)",
            "unpaid\\s+principal\\s+balance\\s*:?\\s*\\$?([0-9,]+\\.?[0-9]*)"
        ]

        return extractCurrencyAmount(from: text, patterns: patterns)
    }

    private func extractInterestRate(from text: String) -> Double? {
        let patterns = [
            "interest\\s+rate\\s*:?\\s*([0-9]+\\.?[0-9]*)\\s*%",
            "(?:current\\s+)?rate\\s*:?\\s*([0-9]+\\.?[0-9]*)\\s*%",
            "apr\\s*:?\\s*([0-9]+\\.?[0-9]*)\\s*%"
        ]

        return extractPercentage(from: text, patterns: patterns)
    }

    private func extractMonthlyPayment(from text: String) -> Double? {
        let patterns = [
            "monthly\\s+payment\\s*:?\\s*\\$?([0-9,]+\\.?[0-9]*)",
            "(?:regular\\s+)?payment\\s+amount\\s*:?\\s*\\$?([0-9,]+\\.?[0-9]*)",
            "scheduled\\s+payment\\s*:?\\s*\\$?([0-9,]+\\.?[0-9]*)"
        ]

        return extractCurrencyAmount(from: text, patterns: patterns)
    }

    private func extractEscrowBalance(from text: String) -> Double? {
        let patterns = [
            "escrow\\s+balance\\s*:?\\s*\\$?([0-9,]+\\.?[0-9]*)",
            "(?:current\\s+)?escrow\\s*:?\\s*\\$?([0-9,]+\\.?[0-9]*)",
            "escrow\\s+account\\s+balance\\s*:?\\s*\\$?([0-9,]+\\.?[0-9]*)"
        ]

        return extractCurrencyAmount(from: text, patterns: patterns)
    }

    private func extractDueDate(from text: String) -> Date? {
        let patterns = [
            "due\\s+date\\s*:?\\s*([0-9]{1,2}[\\/\\-][0-9]{1,2}[\\/\\-][0-9]{2,4})",
            "payment\\s+due\\s*:?\\s*([0-9]{1,2}[\\/\\-][0-9]{1,2}[\\/\\-][0-9]{2,4})",
            "next\\s+payment\\s+due\\s*:?\\s*([0-9]{1,2}[\\/\\-][0-9]{1,2}[\\/\\-][0-9]{2,4})"
        ]

        return extractDate(from: text, patterns: patterns)
    }

    private func extractPaymentHistory(from text: String) -> [ExtractedData.PaymentRecord] {
        var paymentRecords: [ExtractedData.PaymentRecord] = []

        // Enhanced payment section detection with multiple patterns
        let lines = text.components(separatedBy: .newlines)
        var inPaymentSection = false
        var tableHeaderDetected = false

        for line in lines {
            let normalizedLine = line.lowercased().trimmingCharacters(in: .whitespaces)

            // Enhanced section detection
            if isPaymentSectionHeader(normalizedLine) {
                inPaymentSection = true
                tableHeaderDetected = false
                continue
            }

            // Detect table headers for better parsing
            if inPaymentSection && isPaymentTableHeader(normalizedLine) {
                tableHeaderDetected = true
                continue
            }

            if inPaymentSection {
                // Parse payment record line with enhanced patterns
                if let record = parseEnhancedPaymentRecord(from: line) {
                    // Convert enhanced record to basic PaymentRecord for compatibility
                    let basicRecord = ExtractedData.PaymentRecord(
                        paymentDate: record.paymentDate,
                        amount: record.amount,
                        principalApplied: record.principalApplied,
                        interestApplied: record.interestApplied,
                        escrowApplied: record.escrowApplied,
                        lateFeesApplied: record.lateFeesApplied,
                        isLate: record.isLate,
                        dayslate: record.daysLate
                    )
                    paymentRecords.append(basicRecord)
                }

                // Improved section exit detection
                if shouldExitPaymentSection(normalizedLine, hasRecords: !paymentRecords.isEmpty) {
                    inPaymentSection = false
                    tableHeaderDetected = false
                }
            }
        }

        // Sort payment records by date (most recent first)
        return paymentRecords.sorted { $0.paymentDate > $1.paymentDate }
    }

    private func isPaymentSectionHeader(_ line: String) -> Bool {
        let sectionPatterns = [
            "payment\\s+history",
            "transaction\\s+history",
            "payment\\s+activity",
            "recent\\s+payments",
            "payment\\s+details",
            "account\\s+activity"
        ]

        return sectionPatterns.contains { pattern in
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                return regex.numberOfMatches(in: line, options: [], range: NSRange(location: 0, length: line.count)) > 0
            } catch {
                return false
            }
        }
    }

    private func isPaymentTableHeader(_ line: String) -> Bool {
        // Common table headers in payment history
        let headerKeywords = ["date", "amount", "principal", "interest", "escrow", "balance", "effective"]
        let keywordCount = headerKeywords.filter { line.contains($0) }.count
        return keywordCount >= 3 // At least 3 payment-related keywords
    }

    private func shouldExitPaymentSection(_ line: String, hasRecords: Bool) -> Bool {
        // Exit conditions for payment section
        if line.contains("escrow\\s+(analysis|statement)") ||
           line.contains("loan\\s+information") ||
           line.contains("contact\\s+information") {
            return true
        }

        // Allow empty lines within payment section if we have records
        if line.isEmpty && hasRecords {
            return false
        }

        // Exit if we hit a clearly different section
        return line.contains("important\\s+notice") ||
               line.contains("disclosure") ||
               (line.isEmpty && !hasRecords)
    }

    /// Enhanced payment record parsing with multi-servicer support and RESPA compliance
    private func parseEnhancedPaymentRecord(from line: String) -> EnhancedPaymentRecord? {
        let normalizedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLine.isEmpty else { return nil }

        // Detect servicer format
        let servicerFormat = detectServicerFormat(from: line)

        // Apply servicer-specific parsing patterns
        var record: EnhancedPaymentRecord?

        switch servicerFormat {
        case .wellsFargo:
            record = parseWellsFargoPaymentRecord(from: line)
        case .quickenLoans, .rocketMortgage:
            record = parseQuickenRocketPaymentRecord(from: line)
        case .chase:
            record = parseChasePaymentRecord(from: line)
        case .bankOfAmerica:
            record = parseBankOfAmericaPaymentRecord(from: line)
        case .mrCooper:
            record = parseMrCooperPaymentRecord(from: line)
        default:
            record = parseGenericPaymentRecord(from: line, format: servicerFormat)
        }

        // Apply RESPA compliance checks and error detection
        if var validRecord = record {
            validRecord = validateRESPACompliance(record: validRecord)
            validRecord = detectPaymentAllocationErrors(record: validRecord)
            return validRecord
        }

        return nil
    }

    /// Detect servicer format from payment line context
    private func detectServicerFormat(from line: String) -> EnhancedPaymentRecord.ServicerFormat {
        let normalizedLine = line.lowercased()

        // Check for servicer-specific patterns or formatting
        if normalizedLine.contains("wells") || normalizedLine.contains("wf") {
            return .wellsFargo
        } else if normalizedLine.contains("quicken") || normalizedLine.contains("ql") {
            return .quickenLoans
        } else if normalizedLine.contains("rocket") || normalizedLine.contains("rm") {
            return .rocketMortgage
        } else if normalizedLine.contains("chase") || normalizedLine.contains("jpmc") {
            return .chase
        } else if normalizedLine.contains("boa") || normalizedLine.contains("bank of america") {
            return .bankOfAmerica
        } else if normalizedLine.contains("cooper") || normalizedLine.contains("mr.") {
            return .mrCooper
        }

        return .generic
    }

    /// Parse Wells Fargo specific payment format
    private func parseWellsFargoPaymentRecord(from line: String) -> EnhancedPaymentRecord? {
        // Wells Fargo format: MM/DD/YYYY | $Amount | $Principal | $Interest | $Escrow | $Fees
        let wfPattern = #"([0-9]{1,2}\/[0-9]{1,2}\/[0-9]{4})\s*\|?\s*\$?([0-9,]+\.[0-9]{2})\s*\|?\s*\$?([0-9,]+\.[0-9]{2})?\s*\|?\s*\$?([0-9,]+\.[0-9]{2})?\s*\|?\s*\$?([0-9,]+\.[0-9]{2})?\s*\|?\s*\$?([0-9,]+\.[0-9]{2})?"#

        return parseServicerSpecificRecord(from: line, pattern: wfPattern, format: .wellsFargo)
    }

    /// Parse Quicken/Rocket Mortgage specific payment format
    private func parseQuickenRocketPaymentRecord(from line: String) -> EnhancedPaymentRecord? {
        // Quicken/Rocket format: MM/DD/YYYY Amount: $XXX.XX Principal: $XXX.XX Interest: $XXX.XX
        let qrPattern = #"([0-9]{1,2}\/[0-9]{1,2}\/[0-9]{4}).*?Amount:\s*\$?([0-9,]+\.[0-9]{2}).*?Principal:\s*\$?([0-9,]+\.[0-9]{2})?.*?Interest:\s*\$?([0-9,]+\.[0-9]{2})?"#

        return parseServicerSpecificRecord(from: line, pattern: qrPattern, format: .quickenLoans)
    }

    /// Parse Chase specific payment format
    private func parseChasePaymentRecord(from line: String) -> EnhancedPaymentRecord? {
        // Chase format: Date\tAmount\tPrincipal\tInterest\tEscrow\tFees
        let chasePattern = #"([0-9]{1,2}\/[0-9]{1,2}\/[0-9]{4})\s+\$?([0-9,]+\.[0-9]{2})\s+\$?([0-9,]+\.[0-9]{2})?\s+\$?([0-9,]+\.[0-9]{2})?\s+\$?([0-9,]+\.[0-9]{2})?\s+\$?([0-9,]+\.[0-9]{2})?"#

        return parseServicerSpecificRecord(from: line, pattern: chasePattern, format: .chase)
    }

    /// Parse Bank of America specific payment format
    private func parseBankOfAmericaPaymentRecord(from line: String) -> EnhancedPaymentRecord? {
        // Bank of America format varies, use flexible parsing
        let boaPattern = #"([0-9]{1,2}[\/\-][0-9]{1,2}[\/\-][0-9]{2,4}).*?\$?([0-9,]+\.[0-9]{2})"#

        return parseServicerSpecificRecord(from: line, pattern: boaPattern, format: .bankOfAmerica)
    }

    /// Parse Mr. Cooper specific payment format
    private func parseMrCooperPaymentRecord(from line: String) -> EnhancedPaymentRecord? {
        // Mr. Cooper format: similar to generic but with specific field ordering
        let cooperPattern = #"([0-9]{1,2}\/[0-9]{1,2}\/[0-9]{4})\s+\$?([0-9,]+\.[0-9]{2})\s+\$?([0-9,]+\.[0-9]{2})?\s+\$?([0-9,]+\.[0-9]{2})?\s+\$?([0-9,]+\.[0-9]{2})?"#

        return parseServicerSpecificRecord(from: line, pattern: cooperPattern, format: .mrCooper)
    }

    /// Parse generic payment format with best-effort recognition
    private func parseGenericPaymentRecord(from line: String, format: EnhancedPaymentRecord.ServicerFormat) -> EnhancedPaymentRecord? {
        // Generic flexible pattern that handles various formats
        let genericPattern = #"([0-9]{1,2}[\/\-][0-9]{1,2}[\/\-][0-9]{2,4}).*?\$?([0-9,]+\.?[0-9]*)"#

        return parseServicerSpecificRecord(from: line, pattern: genericPattern, format: format)
    }

    /// Core servicer-specific parsing logic
    private func parseServicerSpecificRecord(from line: String, pattern: String, format: EnhancedPaymentRecord.ServicerFormat) -> EnhancedPaymentRecord? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: line.utf16.count)

            guard let match = regex.firstMatch(in: line, options: [], range: range) else {
                return nil
            }

            // Extract date
            guard let dateRange = Range(match.range(at: 1), in: line),
                  let paymentDate = parseDate(from: String(line[dateRange])) else {
                return nil
            }

            // Extract amount
            guard let amountRange = Range(match.range(at: 2), in: line),
                  let amount = parseAmount(String(line[amountRange])) else {
                return nil
            }

            // Extract optional components with enhanced logic
            let principalApplied = match.numberOfRanges > 3 ? extractOptionalAmount(match, at: 3, from: line) : extractCurrencyFromLine(line, afterPattern: "principal")
            let interestApplied = match.numberOfRanges > 4 ? extractOptionalAmount(match, at: 4, from: line) : extractCurrencyFromLine(line, afterPattern: "interest")
            let escrowApplied = match.numberOfRanges > 5 ? extractOptionalAmount(match, at: 5, from: line) : extractCurrencyFromLine(line, afterPattern: "escrow")
            let lateFeesApplied = match.numberOfRanges > 6 ? extractOptionalAmount(match, at: 6, from: line) : extractCurrencyFromLine(line, afterPattern: "late")

            // Extract unapplied funds and suspense amounts
            let unappliedFunds = extractCurrencyFromLine(line, afterPattern: "unapplied")
            let suspenseAmount = extractCurrencyFromLine(line, afterPattern: "suspense")

            // Determine if payment is late
            let isLate = line.lowercased().contains("late") || lateFeesApplied != nil && lateFeesApplied! > 0
            let daysLate = isLate ? extractDaysLate(from: line) : nil

            // Calculate confidence score
            let confidenceScore = calculateConfidenceScore(for: line, amount: amount, servicerFormat: format)

            let record = EnhancedPaymentRecord(
                paymentDate: paymentDate,
                amount: amount,
                principalApplied: principalApplied,
                interestApplied: interestApplied,
                escrowApplied: escrowApplied,
                lateFeesApplied: lateFeesApplied,
                unappliedFunds: unappliedFunds,
                suspenseAmount: suspenseAmount,
                isLate: isLate,
                daysLate: daysLate,
                servicerFormat: format,
                confidenceScore: confidenceScore,
                respaViolations: [],
                allocationErrors: []
            )

            return record

        } catch {
            logger.error("Failed to parse \(format.rawValue) payment record: \(error.localizedDescription)")
            return nil
        }
    }

    /// Extract optional amount from regex match
    private func extractOptionalAmount(_ match: NSTextCheckingResult, at index: Int, from line: String) -> Double? {
        guard index < match.numberOfRanges,
              let range = Range(match.range(at: index), in: line) else {
            return nil
        }

        let amountString = String(line[range])
        return parseAmount(amountString)
    }

    /// Parse amount string to double, handling various formats
    private func parseAmount(_ amountString: String) -> Double? {
        let cleanAmount = amountString
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Double(cleanAmount)
    }

    /// Calculate confidence score for payment record
    private func calculateConfidenceScore(for line: String, amount: Double, servicerFormat: EnhancedPaymentRecord.ServicerFormat) -> Double {
        var score = 0.0
        let factors: [(condition: Bool, weight: Double)] = [
            (amount > 0, 0.3), // Valid amount
            (line.contains("$"), 0.1), // Contains currency symbol
            (servicerFormat != .generic, 0.2), // Specific servicer format detected
            (line.contains("principal") || line.contains("interest"), 0.2), // Contains allocation terms
            (line.contains("escrow"), 0.1), // Contains escrow information
            (line.range(of: #"[0-9]{1,2}[\/\-][0-9]{1,2}[\/\-][0-9]{2,4}"#, options: .regularExpression) != nil, 0.1) // Valid date format
        ]

        for (condition, weight) in factors {
            if condition {
                score += weight
            }
        }

        return min(score, 1.0)
    }

    /// Validate RESPA compliance for payment record
    private func validateRESPACompliance(record: EnhancedPaymentRecord) -> EnhancedPaymentRecord {
        var violations: [EnhancedPaymentRecord.RESPAViolation] = []

        // Check for improper escrow allocation
        if let escrow = record.escrowApplied, let principal = record.principalApplied {
            // RESPA requires escrow to be applied before principal in most cases
            if escrow > 0 && principal > 0 {
                // Check if escrow allocation is reasonable (typically 1/12 of annual escrow)
                let reasonableEscrowMax = record.amount * 0.4 // 40% max for escrow
                if escrow > reasonableEscrowMax {
                    violations.append(.escrowOverpayment)
                }
            }
        }

        // Check for late fee miscalculation
        if let lateFee = record.lateFeesApplied, lateFee > 0 {
            // RESPA limits late fees - typically 4-5% of monthly payment or $15-25
            let maxLateFee = max(record.amount * 0.05, 25.0) // 5% or $25, whichever is greater
            if lateFee > maxLateFee {
                violations.append(.lateFeeMiscalculation)
            }
        }

        // Check for unapplied funds delay (RESPA violation if funds held too long)
        if let unapplied = record.unappliedFunds, unapplied > 0 {
            violations.append(.unappliedFundsDelay)
        }

        // Check principal/interest allocation based on amortization
        if let principal = record.principalApplied, let interest = record.interestApplied {
            let totalPI = principal + interest
            let interestRatio = interest / totalPI

            // Flag if interest ratio seems excessive (>90% typically indicates early loan)
            if interestRatio > 0.95 {
                violations.append(.principalInterestMisallocation)
            }
        }

        return EnhancedPaymentRecord(
            paymentDate: record.paymentDate,
            amount: record.amount,
            principalApplied: record.principalApplied,
            interestApplied: record.interestApplied,
            escrowApplied: record.escrowApplied,
            lateFeesApplied: record.lateFeesApplied,
            unappliedFunds: record.unappliedFunds,
            suspenseAmount: record.suspenseAmount,
            isLate: record.isLate,
            daysLate: record.daysLate,
            servicerFormat: record.servicerFormat,
            confidenceScore: record.confidenceScore,
            respaViolations: violations,
            allocationErrors: record.allocationErrors
        )
    }

    /// Detect payment allocation errors
    private func detectPaymentAllocationErrors(record: EnhancedPaymentRecord) -> EnhancedPaymentRecord {
        var errors: [EnhancedPaymentRecord.PaymentAllocationError] = []

        // Check if payment total matches allocation sum
        var allocationSum = 0.0

        if let principal = record.principalApplied { allocationSum += principal }
        if let interest = record.interestApplied { allocationSum += interest }
        if let escrow = record.escrowApplied { allocationSum += escrow }
        if let lateFees = record.lateFeesApplied { allocationSum += lateFees }

        let tolerance = 0.01 // $0.01 tolerance for rounding
        if abs(record.amount - allocationSum) > tolerance {
            errors.append(.totalMismatch)
        }

        // Check for negative allocations
        let allocations = [record.principalApplied, record.interestApplied, record.escrowApplied, record.lateFeesApplied]
        if allocations.compactMap({ $0 }).contains(where: { $0 < 0 }) {
            errors.append(.negativeAllocation)
        }

        // Check for missing escrow allocation when expected
        if record.escrowApplied == nil && record.amount > 1000 { // Assume loans > $1000 likely have escrow
            errors.append(.missingEscrowAllocation)
        }

        // Check for excessive late fees
        if let lateFee = record.lateFeesApplied, lateFee > record.amount * 0.1 {
            errors.append(.excessiveLateFee)
        }

        return EnhancedPaymentRecord(
            paymentDate: record.paymentDate,
            amount: record.amount,
            principalApplied: record.principalApplied,
            interestApplied: record.interestApplied,
            escrowApplied: record.escrowApplied,
            lateFeesApplied: record.lateFeesApplied,
            unappliedFunds: record.unappliedFunds,
            suspenseAmount: record.suspenseAmount,
            isLate: record.isLate,
            daysLate: record.daysLate,
            servicerFormat: record.servicerFormat,
            confidenceScore: record.confidenceScore,
            respaViolations: record.respaViolations,
            allocationErrors: errors
        )
    }

    /// Detect and analyze table structure in mortgage documents
    private func detectTableStructure(from ocrResult: OCRResult) -> [TableStructure] {
        var tables: [TableStructure] = []

        // Analyze text for table patterns
        let lines = ocrResult.text.components(separatedBy: .newlines)
        var currentTable: [String] = []
        var inTable = false

        for (index, line) in lines.enumerated() {
            let normalizedLine = line.trimmingCharacters(in: .whitespaces)

            // Detect table start by looking for headers
            if isTableHeader(normalizedLine) && !inTable {
                inTable = true
                currentTable = [normalizedLine]
                continue
            }

            if inTable {
                if isTableRow(normalizedLine) || normalizedLine.isEmpty {
                    if !normalizedLine.isEmpty {
                        currentTable.append(normalizedLine)
                    }
                } else {
                    // End of table detected
                    if currentTable.count > 1 {
                        if let table = parseTableStructure(from: currentTable, startingAt: index - currentTable.count) {
                            tables.append(table)
                        }
                    }
                    inTable = false
                    currentTable = []
                }
            }
        }

        // Handle table at end of document
        if inTable && currentTable.count > 1 {
            if let table = parseTableStructure(from: currentTable, startingAt: lines.count - currentTable.count) {
                tables.append(table)
            }
        }

        return tables
    }

    /// Check if line is a table header
    private func isTableHeader(_ line: String) -> Bool {
        let normalizedLine = line.lowercased()

        // Payment history table headers
        let paymentHeaders = ["date", "payment", "principal", "interest", "escrow", "balance", "amount"]
        let paymentHeaderCount = paymentHeaders.filter { normalizedLine.contains($0) }.count

        // Escrow breakdown table headers
        let escrowHeaders = ["description", "payment", "disbursement", "balance", "category", "tax", "insurance"]
        let escrowHeaderCount = escrowHeaders.filter { normalizedLine.contains($0) }.count

        // Fee schedule headers
        let feeHeaders = ["fee", "description", "amount", "date", "type"]
        let feeHeaderCount = feeHeaders.filter { normalizedLine.contains($0) }.count

        // Consider it a header if it has 3+ relevant keywords and contains separators
        return (paymentHeaderCount >= 3 || escrowHeaderCount >= 3 || feeHeaderCount >= 3) &&
               (line.contains("\\t") || line.contains("|") || line.contains("  "))
    }

    /// Check if line is a table row
    private func isTableRow(_ line: String) -> Bool {
        let normalizedLine = line.trimmingCharacters(in: .whitespaces)

        // Look for date pattern (common in all mortgage tables)
        let hasDate = normalizedLine.range(of: #"[0-9]{1,2}[\/\-][0-9]{1,2}[\/\-][0-9]{2,4}"#, options: .regularExpression) != nil

        // Look for currency amounts
        let hasCurrency = normalizedLine.range(of: #"\$[0-9,]+\.?[0-9]*"#, options: .regularExpression) != nil

        // Look for column separators
        let hasColumnseparators = line.contains("\\t") || line.contains("|") ||
                                  line.components(separatedBy: "  ").count > 2

        return hasDate || (hasCurrency && hasColumnseparators)
    }

    /// Parse detected table structure
    private func parseTableStructure(from tableLines: [String], startingAt lineIndex: Int) -> TableStructure? {
        guard !tableLines.isEmpty else { return nil }

        let headerLine = tableLines[0]
        let dataLines = Array(tableLines.dropFirst())

        // Determine table type
        let tableType = determineTableType(from: headerLine)

        // Extract column headers
        let columnHeaders = extractColumnHeaders(from: headerLine)

        // Calculate column positions (simplified - using character positions)
        let columnPositions = calculateColumnPositions(from: headerLine, headers: columnHeaders)

        // Calculate confidence score
        let confidenceScore = calculateTableConfidence(headers: columnHeaders, dataRows: dataLines, type: tableType)

        return TableStructure(
            columnHeaders: columnHeaders,
            columnPositions: columnPositions,
            rowCount: dataLines.count,
            confidenceScore: confidenceScore,
            tableType: tableType
        )
    }

    /// Determine table type from header content
    private func determineTableType(from headerLine: String) -> TableStructure.TableType {
        let normalizedHeader = headerLine.lowercased()

        if normalizedHeader.contains("payment") && (normalizedHeader.contains("principal") || normalizedHeader.contains("interest")) {
            return .paymentHistory
        } else if normalizedHeader.contains("escrow") || (normalizedHeader.contains("tax") && normalizedHeader.contains("insurance")) {
            return .escrowBreakdown
        } else if normalizedHeader.contains("fee") || normalizedHeader.contains("charge") {
            return .feeSchedule
        } else if normalizedHeader.contains("balance") && normalizedHeader.contains("payment") {
            return .amortizationSchedule
        }

        return .paymentHistory // Default
    }

    /// Extract column headers from header line
    private func extractColumnHeaders(from headerLine: String) -> [String] {
        var headers: [String] = []

        // Try different separators
        let separators = ["\\t", "|", "  ", "   "]

        for separator in separators {
            let components = headerLine.components(separatedBy: separator)
            if components.count > 1 {
                headers = components.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                break
            }
        }

        // If no clear separators, try to identify column positions by keywords
        if headers.isEmpty {
            let keywords = ["date", "payment", "amount", "principal", "interest", "escrow", "balance", "fee", "description"]
            for keyword in keywords {
                if headerLine.lowercased().contains(keyword) {
                    // Find keyword position and extract surrounding text
                    if let range = headerLine.lowercased().range(of: keyword) {
                        let start = max(headerLine.startIndex, headerLine.index(range.lowerBound, offsetBy: -5))
                        let end = min(headerLine.endIndex, headerLine.index(range.upperBound, offsetBy: 5))
                        let columnText = String(headerLine[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !headers.contains(columnText) {
                            headers.append(columnText)
                        }
                    }
                }
            }
        }

        return headers
    }

    /// Calculate column positions for text extraction
    private func calculateColumnPositions(from headerLine: String, headers: [String]) -> [CGRect] {
        var positions: [CGRect] = []

        for header in headers {
            if let range = headerLine.range(of: header) {
                let startOffset = headerLine.distance(from: headerLine.startIndex, to: range.lowerBound)
                let width = header.count

                // Convert to normalized coordinates (simplified)
                let normalizedX = Double(startOffset) / Double(headerLine.count)
                let normalizedWidth = Double(width) / Double(headerLine.count)

                let rect = CGRect(x: normalizedX, y: 0, width: normalizedWidth, height: 1.0)
                positions.append(rect)
            }
        }

        return positions
    }

    /// Calculate table detection confidence
    private func calculateTableConfidence(headers: [String], dataRows: [String], type: TableStructure.TableType) -> Double {
        var confidence = 0.0

        // Header quality (30%)
        let headerKeywords = ["date", "payment", "amount", "principal", "interest", "escrow", "balance"]
        let headerMatches = headers.filter { header in
            headerKeywords.contains { header.lowercased().contains($0) }
        }.count

        confidence += min(Double(headerMatches) / Double(headerKeywords.count), 1.0) * 0.3

        // Data row consistency (40%)
        let consistentRows = dataRows.filter { row in
            // Check if row has expected pattern (date + amounts)
            let hasDate = row.range(of: #"[0-9]{1,2}[\/\-][0-9]{1,2}[\/\-][0-9]{2,4}"#, options: .regularExpression) != nil
            let hasCurrency = row.range(of: #"\$[0-9,]+\.?[0-9]*"#, options: .regularExpression) != nil
            return hasDate || hasCurrency
        }.count

        if !dataRows.isEmpty {
            confidence += Double(consistentRows) / Double(dataRows.count) * 0.4
        }

        // Column count consistency (20%)
        let expectedColumns = headers.count
        let rowsWithExpectedColumns = dataRows.filter { row in
            let components = row.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            return abs(components.count - expectedColumns) <= 1 // Allow 1 column difference
        }.count

        if !dataRows.isEmpty {
            confidence += Double(rowsWithExpectedColumns) / Double(dataRows.count) * 0.2
        }

        // Table type appropriateness (10%)
        confidence += 0.1 // Base score for detecting any table

        return min(confidence, 1.0)
    }

    private func parsePaymentRecord(from line: String) -> ExtractedData.PaymentRecord? {
        // Try enhanced parsing first for better accuracy and RESPA compliance
        if let enhancedRecord = parseEnhancedPaymentRecord(from: line) {
            return ExtractedData.PaymentRecord(
                paymentDate: enhancedRecord.paymentDate,
                amount: enhancedRecord.amount,
                principalApplied: enhancedRecord.principalApplied,
                interestApplied: enhancedRecord.interestApplied,
                escrowApplied: enhancedRecord.escrowApplied,
                lateFeesApplied: enhancedRecord.lateFeesApplied,
                isLate: enhancedRecord.isLate,
                dayslate: enhancedRecord.daysLate
            )
        }

        // Fallback to legacy parsing for compatibility
        let pattern = #"([0-9]{1,2}[\\/\\-][0-9]{1,2}[\\/\\-][0-9]{2,4})\s+\$?([0-9,]+\.?[0-9]*)"#

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: line.utf16.count)

            if let match = regex.firstMatch(in: line, options: [], range: range) {
                let dateRange = Range(match.range(at: 1), in: line)
                let amountRange = Range(match.range(at: 2), in: line)

                guard let dateRange = dateRange, let amountRange = amountRange else { return nil }

                let dateString = String(line[dateRange])
                let amountString = String(line[amountRange]).replacingOccurrences(of: ",", with: "")

                guard let paymentDate = parseDate(from: dateString),
                      let amount = Double(amountString) else { return nil }

                // Extract additional payment details if available
                let principalApplied = extractCurrencyFromLine(line, afterPattern: "principal")
                let interestApplied = extractCurrencyFromLine(line, afterPattern: "interest")
                let escrowApplied = extractCurrencyFromLine(line, afterPattern: "escrow")
                let lateFeesApplied = extractCurrencyFromLine(line, afterPattern: "late")

                let isLate = line.lowercased().contains("late") || lateFeesApplied != nil
                let daysLate = isLate ? extractDaysLate(from: line) : nil

                return ExtractedData.PaymentRecord(
                    paymentDate: paymentDate,
                    amount: amount,
                    principalApplied: principalApplied,
                    interestApplied: interestApplied,
                    escrowApplied: escrowApplied,
                    lateFeesApplied: lateFeesApplied,
                    isLate: isLate,
                    dayslate: daysLate
                )
            }
        } catch {
            logger.error("Failed to parse payment record: \(error.localizedDescription)")
        }

        return nil
    }

    private func extractEscrowActivity(from text: String) -> [ExtractedData.EscrowTransaction] {
        var transactions: [ExtractedData.EscrowTransaction] = []

        let lines = text.components(separatedBy: .newlines)
        var inEscrowSection = false

        for line in lines {
            let normalizedLine = line.lowercased().trimmingCharacters(in: .whitespaces)

            // Detect escrow activity section
            if normalizedLine.contains("escrow") && (normalizedLine.contains("activity") || normalizedLine.contains("transaction")) {
                inEscrowSection = true
                continue
            }

            if inEscrowSection {
                if let transaction = parseEscrowTransaction(from: line) {
                    transactions.append(transaction)
                }

                // Exit escrow section
                if normalizedLine.contains("payment") || normalizedLine.contains("loan") || (normalizedLine.isEmpty && transactions.count > 0) {
                    inEscrowSection = false
                }
            }
        }

        return transactions
    }

    private func parseEscrowTransaction(from line: String) -> ExtractedData.EscrowTransaction? {
        // Pattern for escrow transaction: Date Description Amount Type
        let pattern = #"([0-9]{1,2}[\\/\\-][0-9]{1,2}[\\/\\-][0-9]{2,4})\s+(.+?)\s+\$?([0-9,]+\.?[0-9]*)"#

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: line.utf16.count)

            if let match = regex.firstMatch(in: line, options: [], range: range) {
                let dateRange = Range(match.range(at: 1), in: line)
                let descriptionRange = Range(match.range(at: 2), in: line)
                let amountRange = Range(match.range(at: 3), in: line)

                guard let dateRange = dateRange,
                      let descriptionRange = descriptionRange,
                      let amountRange = amountRange else { return nil }

                let dateString = String(line[dateRange])
                let description = String(line[descriptionRange]).trimmingCharacters(in: .whitespaces)
                let amountString = String(line[amountRange]).replacingOccurrences(of: ",", with: "")

                guard let transactionDate = parseDate(from: dateString),
                      let amount = Double(amountString) else { return nil }

                // Determine transaction type and category
                let transactionType: ExtractedData.EscrowTransaction.TransactionType = determineTransactionType(from: description)
                let category: ExtractedData.EscrowTransaction.EscrowCategory = determineEscrowCategory(from: description)

                return ExtractedData.EscrowTransaction(
                    date: transactionDate,
                    description: description,
                    amount: amount,
                    type: transactionType,
                    category: category
                )
            }
        } catch {
            logger.error("Failed to parse escrow transaction: \(error.localizedDescription)")
        }

        return nil
    }

    private func extractFees(from text: String) -> [ExtractedData.Fee] {
        var fees: [ExtractedData.Fee] = []

        let feePatterns = [
            "late\\s+fee\\s*:?\\s*\\$?([0-9,]+\\.?[0-9]*)",
            "inspection\\s+fee\\s*:?\\s*\\$?([0-9,]+\\.?[0-9]*)",
            "attorney\\s+fee\\s*:?\\s*\\$?([0-9,]+\\.?[0-9]*)",
            "processing\\s+fee\\s*:?\\s*\\$?([0-9,]+\\.?[0-9]*)"
        ]

        for pattern in feePatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(location: 0, length: text.utf16.count)

                let matches = regex.matches(in: text, options: [], range: range)

                for match in matches {
                    let fullMatchRange = Range(match.range, in: text)
                    let amountRange = Range(match.range(at: 1), in: text)

                    guard let fullMatchRange = fullMatchRange,
                          let amountRange = amountRange else { continue }

                    let fullMatch = String(text[fullMatchRange])
                    let amountString = String(text[amountRange]).replacingOccurrences(of: ",", with: "")

                    guard let amount = Double(amountString) else { continue }

                    let category = determineFeeCategory(from: fullMatch)

                    let fee = ExtractedData.Fee(
                        date: Date(), // Default to current date; ideally extract from context
                        description: fullMatch.trimmingCharacters(in: .whitespacesAndNewlines),
                        amount: amount,
                        category: category
                    )

                    fees.append(fee)
                }
            } catch {
                logger.error("Failed to extract fees: \(error.localizedDescription)")
            }
        }

        return fees
    }

    // MARK: - Helper Methods

    private func extractFirstMatch(from text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(location: 0, length: text.utf16.count)

                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    let matchRange = Range(match.range(at: 1), in: text)
                    if let matchRange = matchRange {
                        return String(text[matchRange])
                    }
                }
            } catch {
                logger.error("Regex error for pattern \(pattern): \(error.localizedDescription)")
            }
        }
        return nil
    }

    private func extractCurrencyAmount(from text: String, patterns: [String]) -> Double? {
        guard let amountString = extractFirstMatch(from: text, patterns: patterns) else { return nil }
        let cleanAmount = amountString.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "$", with: "")
        return Double(cleanAmount)
    }

    private func extractPercentage(from text: String, patterns: [String]) -> Double? {
        guard let percentString = extractFirstMatch(from: text, patterns: patterns) else { return nil }
        return Double(percentString)
    }

    private func extractDate(from text: String, patterns: [String]) -> Date? {
        guard let dateString = extractFirstMatch(from: text, patterns: patterns) else { return nil }
        return parseDate(from: dateString)
    }

    private func parseDate(from dateString: String) -> Date? {
        let formatters = [
            DateFormatter().apply { $0.dateFormat = "MM/dd/yyyy" },
            DateFormatter().apply { $0.dateFormat = "M/d/yyyy" },
            DateFormatter().apply { $0.dateFormat = "MM-dd-yyyy" },
            DateFormatter().apply { $0.dateFormat = "M-d-yyyy" },
            DateFormatter().apply { $0.dateFormat = "MM/dd/yy" },
            DateFormatter().apply { $0.dateFormat = "M/d/yy" }
        ]

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    private func extractCurrencyFromLine(_ line: String, afterPattern pattern: String) -> Double? {
        let searchPattern = "\(pattern)\\s*:?\\s*\\$?([0-9,]+\\.?[0-9]*)"

        do {
            let regex = try NSRegularExpression(pattern: searchPattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: line.utf16.count)

            if let match = regex.firstMatch(in: line, options: [], range: range) {
                let amountRange = Range(match.range(at: 1), in: line)
                if let amountRange = amountRange {
                    let amountString = String(line[amountRange]).replacingOccurrences(of: ",", with: "")
                    return Double(amountString)
                }
            }
        } catch {
            logger.error("Failed to extract currency from line: \(error.localizedDescription)")
        }

        return nil
    }

    private func extractDaysLate(from line: String) -> Int? {
        let pattern = "(\\d+)\\s*days?\\s*late"

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: line.utf16.count)

            if let match = regex.firstMatch(in: line, options: [], range: range) {
                let daysRange = Range(match.range(at: 1), in: line)
                if let daysRange = daysRange {
                    return Int(String(line[daysRange]))
                }
            }
        } catch {
            logger.error("Failed to extract days late: \(error.localizedDescription)")
        }

        return nil
    }

    private func determineTransactionType(from description: String) -> ExtractedData.EscrowTransaction.TransactionType {
        let normalizedDescription = description.lowercased()

        if normalizedDescription.contains("deposit") || normalizedDescription.contains("payment") {
            return .deposit
        } else if normalizedDescription.contains("withdrawal") || normalizedDescription.contains("disbursement") {
            return .withdrawal
        }

        return .deposit // Default
    }

    private func determineEscrowCategory(from description: String) -> ExtractedData.EscrowTransaction.EscrowCategory {
        let normalizedDescription = description.lowercased()

        if normalizedDescription.contains("tax") || normalizedDescription.contains("property tax") {
            return .propertyTax
        } else if normalizedDescription.contains("insurance") && !normalizedDescription.contains("mortgage insurance") {
            return .homeownerInsurance
        } else if normalizedDescription.contains("mortgage insurance") || normalizedDescription.contains("pmi") {
            return .mortgageInsurance
        }

        return .other
    }

    private func determineFeeCategory(from description: String) -> ExtractedData.Fee.FeeCategory {
        let normalizedDescription = description.lowercased()

        if normalizedDescription.contains("late") {
            return .lateFee
        } else if normalizedDescription.contains("inspection") {
            return .inspectionFee
        } else if normalizedDescription.contains("attorney") {
            return .attorneyFee
        } else if normalizedDescription.contains("processing") {
            return .processingFee
        }

        return .other
    }

    /// Generate comprehensive confidence score for extracted financial data
    private func generateConfidenceScore(for extractedData: ExtractedData, ocrResult: OCRResult) -> ConfidenceScore {
        let ocrConfidence = Double(ocrResult.confidence)

        // Format recognition confidence based on detected patterns
        let formatRecognitionConfidence = calculateFormatRecognitionConfidence(extractedData)

        // Cross-validation confidence by checking data consistency
        let crossValidationConfidence = calculateCrossValidationConfidence(extractedData)

        // Pattern match confidence based on recognized patterns
        let patternMatchConfidence = calculatePatternMatchConfidence(extractedData)

        // Overall confidence as weighted average
        let overallConfidence = (
            ocrConfidence * 0.3 +
            formatRecognitionConfidence * 0.25 +
            crossValidationConfidence * 0.25 +
            patternMatchConfidence * 0.2
        )

        return ConfidenceScore(
            overallConfidence: overallConfidence,
            ocrConfidence: ocrConfidence,
            formatRecognitionConfidence: formatRecognitionConfidence,
            crossValidationConfidence: crossValidationConfidence,
            patternMatchConfidence: patternMatchConfidence
        )
    }

    /// Calculate format recognition confidence
    private func calculateFormatRecognitionConfidence(_ data: ExtractedData) -> Double {
        var score = 0.0
        var factors = 0

        // Check loan number format
        if let loanNumber = data.loanNumber, !loanNumber.isEmpty {
            score += loanNumber.count >= 8 ? 1.0 : 0.5
            factors += 1
        }

        // Check servicer name recognition
        if let servicerName = data.servicerName, !servicerName.isEmpty {
            let knownServicers = ["Wells Fargo", "Quicken Loans", "Chase", "Bank of America", "Mr. Cooper"]
            score += knownServicers.contains { servicerName.contains($0) } ? 1.0 : 0.7
            factors += 1
        }

        // Check financial data validity
        if let principal = data.principalBalance, principal > 0 {
            score += (principal > 1000 && principal < 10000000) ? 1.0 : 0.5 // Reasonable range
            factors += 1
        }

        if let rate = data.interestRate, rate > 0 {
            score += (rate > 0.01 && rate < 20.0) ? 1.0 : 0.3 // Reasonable rate range
            factors += 1
        }

        return factors > 0 ? score / Double(factors) : 0.0
    }

    /// Calculate cross-validation confidence
    private func calculateCrossValidationConfidence(_ data: ExtractedData) -> Double {
        var score = 0.0
        var validations = 0

        // Validate payment history consistency
        if !data.paymentHistory.isEmpty {
            let consistentPayments = data.paymentHistory.filter { payment in
                // Check if payment allocations make sense
                guard let principal = payment.principalApplied,
                      let interest = payment.interestApplied else { return false }

                let totalPI = principal + interest
                return totalPI > 0 && totalPI <= payment.amount * 1.1 // Allow 10% tolerance
            }

            score += Double(consistentPayments.count) / Double(data.paymentHistory.count)
            validations += 1
        }

        // Validate escrow data consistency
        if let escrowBalance = data.escrowBalance, escrowBalance >= 0 {
            score += 1.0
            validations += 1

            // Check escrow activity consistency
            if !data.escrowActivity.isEmpty {
                let validTransactions = data.escrowActivity.filter { $0.amount > 0 }
                score += Double(validTransactions.count) / Double(data.escrowActivity.count)
                validations += 1
            }
        }

        // Validate fee data
        if !data.fees.isEmpty {
            let reasonableFees = data.fees.filter { $0.amount > 0 && $0.amount < 1000 } // Reasonable fee range
            score += Double(reasonableFees.count) / Double(data.fees.count)
            validations += 1
        }

        return validations > 0 ? score / Double(validations) : 0.5
    }

    /// Calculate pattern match confidence
    private func calculatePatternMatchConfidence(_ data: ExtractedData) -> Double {
        var score = 0.0
        var patterns = 0

        // Address pattern validation
        if let address = data.propertyAddress, !address.isEmpty {
            let hasNumber = address.range(of: #"^[0-9]+"#, options: .regularExpression) != nil
            let hasState = address.range(of: #"[A-Z]{2}\\s+[0-9]{5}"#, options: .regularExpression) != nil
            score += (hasNumber && hasState) ? 1.0 : 0.7
            patterns += 1
        }

        // Borrower name pattern
        if let borrower = data.borrowerName, !borrower.isEmpty {
            let hasValidNamePattern = borrower.range(of: #"^[A-Za-z\\s,.]+"#, options: .regularExpression) != nil
            score += hasValidNamePattern ? 1.0 : 0.5
            patterns += 1
        }

        // Due date validation
        if let dueDate = data.dueDate {
            let isFutureDate = dueDate >= Date()
            let isReasonableFuture = dueDate <= Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date()
            score += (isFutureDate && isReasonableFuture) ? 1.0 : 0.6
            patterns += 1
        }

        return patterns > 0 ? score / Double(patterns) : 0.5
    }

    /// Detect common mortgage servicing error patterns
    private func detectCommonErrorPatterns(in extractedData: ExtractedData) -> [String] {
        var errorPatterns: [String] = []

        // Late fee calculation errors
        for payment in extractedData.paymentHistory {
            if let lateFee = payment.lateFeesApplied, lateFee > 0 {
                // Check if late fee exceeds reasonable limits
                let maxReasonableLateFee = payment.amount * 0.05 // 5% of payment
                if lateFee > maxReasonableLateFee {
                    errorPatterns.append("Excessive late fee: $\\(String(format: \"%.2f\", lateFee)) on payment of $\\(String(format: \"%.2f\", payment.amount))")
                }

                // Check for late fees on time payments
                if !payment.isLate && lateFee > 0 {
                    errorPatterns.append("Late fee charged on timely payment dated \\(DateFormatter.shortDate.string(from: payment.paymentDate))")
                }
            }
        }

        // Escrow shortage/surplus calculation errors
        if let escrowBalance = extractedData.escrowBalance {
            // Check for negative escrow balance (should not happen)
            if escrowBalance < 0 {
                errorPatterns.append("Negative escrow balance: $\\(String(format: \"%.2f\", escrowBalance))")
            }

            // Check for excessive escrow balance (possible overpayment)
            if let monthlyPayment = extractedData.monthlyPayment {
                let maxReasonableEscrow = monthlyPayment * 6 // 6 months of payments
                if escrowBalance > maxReasonableEscrow {
                    errorPatterns.append("Potentially excessive escrow balance: $\\(String(format: \"%.2f\", escrowBalance))")
                }
            }
        }

        // Payment allocation errors
        for payment in extractedData.paymentHistory {
            if let principal = payment.principalApplied,
               let interest = payment.interestApplied,
               let escrow = payment.escrowApplied {

                let totalAllocated = principal + interest + (escrow)
                let tolerance = 0.02 // $0.02 tolerance

                if abs(payment.amount - totalAllocated) > tolerance {
                    errorPatterns.append("Payment allocation mismatch on \\(DateFormatter.shortDate.string(from: payment.paymentDate)): Payment $\\(String(format: \"%.2f\", payment.amount)) != Allocated $\\(String(format: \"%.2f\", totalAllocated))")
                }
            }
        }

        // Interest rate validation
        if let interestRate = extractedData.interestRate {
            if interestRate < 0.5 || interestRate > 15.0 {
                errorPatterns.append("Unusual interest rate: \\(String(format: \"%.3f\", interestRate))% - verify accuracy")
            }
        }

        // Principal balance validation
        if let principalBalance = extractedData.principalBalance {
            if principalBalance <= 0 {
                errorPatterns.append("Invalid principal balance: $\\(String(format: \"%.2f\", principalBalance))")
            }
        }

        return errorPatterns
    }

    /// Enhanced escrow analysis with RESPA compliance
    private func performEnhancedEscrowAnalysis(for extractedData: ExtractedData) -> [String] {
        var issues: [String] = []

        guard let escrowBalance = extractedData.escrowBalance else {
            return ["No escrow balance information available"]
        }

        // RESPA cushion analysis (maximum 1/6 of annual disbursements or 2 months)
        let escrowTransactions = extractedData.escrowActivity
        let annualDisbursements = calculateAnnualEscrowDisbursements(from: escrowTransactions)

        if annualDisbursements > 0 {
            let maxAllowedCushion = min(annualDisbursements / 6.0, annualDisbursements / 6.0)
            let projectedShortfall = calculateProjectedEscrowShortfall(
                currentBalance: escrowBalance,
                annualDisbursements: annualDisbursements,
                transactions: escrowTransactions
            )

            if escrowBalance - projectedShortfall > maxAllowedCushion {
                issues.append("Potential RESPA violation: Escrow cushion exceeds maximum allowed ($\\(String(format: \"%.2f\", maxAllowedCushion)))")
            }
        }

        // Check for missing escrow categories
        let requiredCategories: Set<ExtractedData.EscrowTransaction.EscrowCategory> = [.propertyTax, .homeownerInsurance]
        let presentCategories = Set(escrowTransactions.map { $0.category })

        for requiredCategory in requiredCategories {
            if !presentCategories.contains(requiredCategory) {
                issues.append("Missing escrow category: \\(requiredCategory)")
            }
        }

        // Analyze escrow payment frequency
        let escrowPayments = escrowTransactions.filter { $0.type == .deposit }
        if escrowPayments.count > 0 {
            let paymentIntervals = calculatePaymentIntervals(escrowPayments)
            let averageInterval = paymentIntervals.reduce(0, +) / Double(paymentIntervals.count)

            if averageInterval > 32 { // More than monthly
                issues.append("Irregular escrow payment schedule detected (average \\(Int(averageInterval)) days)")
            }
        }

        return issues
    }

    /// Calculate annual escrow disbursements
    private func calculateAnnualEscrowDisbursements(from transactions: [ExtractedData.EscrowTransaction]) -> Double {
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let recentDisbursements = transactions.filter { $0.type == .withdrawal && $0.date >= oneYearAgo }

        return recentDisbursements.reduce(0) { $0 + $1.amount }
    }

    /// Calculate projected escrow shortfall
    private func calculateProjectedEscrowShortfall(currentBalance: Double, annualDisbursements: Double, transactions: [ExtractedData.EscrowTransaction]) -> Double {
        // Simplified calculation - in practice this would be more complex
        let monthlyDisbursements = annualDisbursements / 12.0
        let monthsToAnalyze = 12.0

        return max(0, monthlyDisbursements * monthsToAnalyze - currentBalance)
    }

    /// Calculate payment intervals for escrow analysis
    private func calculatePaymentIntervals(_ payments: [ExtractedData.EscrowTransaction]) -> [Double] {
        guard payments.count > 1 else { return [] }

        let sortedPayments = payments.sorted { $0.date < $1.date }
        var intervals: [Double] = []

        for i in 1..<sortedPayments.count {
            let interval = sortedPayments[i].date.timeIntervalSince(sortedPayments[i-1].date)
            intervals.append(interval / 86400) // Convert to days
        }

        return intervals
    }

    private func detectDocumentType(from text: String) -> MortgageDocument.DocumentType {
        let normalizedText = text.lowercased()

        // Score each document type based on pattern matches
        var scores: [MortgageDocument.DocumentType: Int] = [:]

        for (docType, patterns) in documentTypePatterns {
            var score = 0
            for pattern in patterns {
                let range = NSRange(location: 0, length: normalizedText.utf16.count)
                let matchCount = pattern.numberOfMatches(in: normalizedText, options: [], range: range)
                score += matchCount
            }
            scores[docType] = score
        }

        // Return the document type with the highest score
        let bestMatch = scores.max { $0.value < $1.value }
        return bestMatch?.key ?? .other
    }

    private func updateProgress(_ step: ProcessingProgress.ProcessingStep, percentComplete: Double, message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.currentProgress = ProcessingProgress(
                currentStep: step,
                percentComplete: percentComplete,
                message: message
            )
        }
    }
}

// MARK: - Extensions

private extension DateFormatter {
    func apply(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

// MARK: - SecurityService Extension

extension SecurityService {
    /// Validates file integrity for document processing
    func validateFileIntegrity(data: Data) -> Bool {
        // Basic validation - in production, this could include:
        // - File signature validation
        // - Malware scanning
        // - Size limits
        // - Format verification

        // Check for minimum file size
        guard data.count > 100 else { return false }

        // Basic format validation
        let fileHeaders: [Data] = [
            Data([0xFF, 0xD8, 0xFF]), // JPEG
            Data([0x89, 0x50, 0x4E, 0x47]), // PNG
            Data([0x48, 0x45, 0x49, 0x43]), // HEIC
            Data([0x25, 0x50, 0x44, 0x46]) // PDF
        ]

        let fileStart = data.prefix(4)
        return fileHeaders.contains { header in
            fileStart.starts(with: header)
        }
    }
}