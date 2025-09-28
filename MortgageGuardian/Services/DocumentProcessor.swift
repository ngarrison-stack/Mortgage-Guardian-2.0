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

    // MARK: - Properties

    private let securityService: SecurityService
    private let logger = Logger(subsystem: "com.mortgageguardian", category: "DocumentProcessor")
    private let processingQueue = DispatchQueue(label: "document.processing", qos: .userInitiated)
    private let maxDocumentSize: Int = 50 * 1024 * 1024 // 50MB
    private let processingTimeout: TimeInterval = 120 // 2 minutes

    @Published public var currentProgress: ProcessingProgress?
    @Published public var isProcessing = false

    // Pattern matchers for document types
    private let documentTypePatterns: [MortgageDocument.DocumentType: [NSRegularExpression]] = {
        var patterns: [MortgageDocument.DocumentType: [NSRegularExpression]] = [:]

        // Mortgage Statement patterns
        patterns[.mortgageStatement] = [
            try! NSRegularExpression(pattern: "mortgage\\s+statement", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "principal\\s+balance", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "monthly\\s+payment", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "servicer", options: .caseInsensitive)
        ]

        // Escrow Statement patterns
        patterns[.escrowStatement] = [
            try! NSRegularExpression(pattern: "escrow\\s+(statement|analysis)", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "property\\s+tax", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "homeowner.?s?\\s+insurance", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "escrow\\s+balance", options: .caseInsensitive)
        ]

        // Payment History patterns
        patterns[.paymentHistory] = [
            try! NSRegularExpression(pattern: "payment\\s+history", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "payment\\s+date", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "late\\s+fee", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "principal\\s+applied", options: .caseInsensitive)
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

                    let extractedData = try self.parseMortgageDocument(text: ocrResult.text)
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
            "mortgage\\s+company\\s*:?\\s*([A-Za-z\\s&.,]+?)(?:\\n|\\s{3,})"
        ]

        return extractFirstMatch(from: text, patterns: patterns)?.trimmingCharacters(in: .whitespacesAndNewlines)
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

        // Look for payment table patterns
        let lines = text.components(separatedBy: .newlines)
        var inPaymentSection = false

        for line in lines {
            let normalizedLine = line.lowercased().trimmingCharacters(in: .whitespaces)

            // Detect payment history section
            if normalizedLine.contains("payment") && (normalizedLine.contains("history") || normalizedLine.contains("date")) {
                inPaymentSection = true
                continue
            }

            if inPaymentSection {
                // Parse payment record line
                if let record = parsePaymentRecord(from: line) {
                    paymentRecords.append(record)
                }

                // Exit payment section if we hit a different section
                if normalizedLine.contains("escrow") || normalizedLine.contains("fee") || normalizedLine.isEmpty {
                    if paymentRecords.count > 0 && normalizedLine.isEmpty {
                        continue // Allow empty lines in payment section
                    }
                    inPaymentSection = false
                }
            }
        }

        return paymentRecords
    }

    private func parsePaymentRecord(from line: String) -> ExtractedData.PaymentRecord? {
        // Pattern for payment record: Date Amount Principal Interest Escrow LateFee
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