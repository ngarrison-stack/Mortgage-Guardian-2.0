import Foundation
import SwiftUI
import Security
import Combine
import os.log
#if canImport(UIKit)
import UIKit
#else
import ImageIO
import MobileCoreServices
#endif

/// Enhanced AWS Textract Service with Zero-Tolerance OCR Validation
/// Implements multiple OCR passes with confidence validation and backup services
@MainActor
@Observable
class AWSTextractService: ObservableObject {

    // MARK: - Enhanced Error Types

    enum TextractError: Error {
        case missingCredentials
        case encodingFailed
        case networkError(Error)
        case invalidResponse
        case signatureError
        case invalidAWSCredentials
        case lowConfidenceExtraction
        case multipleOCRFailure
        case validationFailed
        case backupServiceUnavailable
    }

    /// OCR confidence validation result
    struct OCRValidationResult {
        let extractedText: String
        let confidence: Double
        let service: OCRService
        let wordLevelConfidences: [WordConfidence]
        let validationPassed: Bool
        let processingTime: TimeInterval
        let metadata: [String: Any]

        struct WordConfidence {
            let text: String
            let confidence: Double
            let boundingBox: CGRect
            let requiresManualReview: Bool
        }
    }

    /// Multi-pass OCR result with cross-validation
    struct MultiPassOCRResult {
        let primaryResult: OCRValidationResult
        let backupResults: [OCRValidationResult]
        let consensusText: String
        let overallConfidence: Double
        let crossValidated: Bool
        let discrepancies: [TextDiscrepancy]
        let recommendManualReview: Bool
        let auditTrail: [OCRAuditEntry]

        struct TextDiscrepancy {
            let position: Range<String.Index>
            let primaryValue: String
            let alternativeValues: [String]
            let confidenceSpread: Double
            let severity: DiscrepancySeverity

            enum DiscrepancySeverity: String {
                case critical = "critical"   // Numbers, dates, amounts
                case high = "high"          // Names, addresses
                case medium = "medium"      // Common words
                case low = "low"           // Articles, prepositions
            }
        }

        struct OCRAuditEntry {
            let service: OCRService
            let timestamp: Date
            let confidence: Double
            let processingTime: TimeInterval
            let errorCount: Int
            let warnings: [String]
        }
    }

    /// Available OCR services for redundancy
    enum OCRService: String, CaseIterable {
        case awsTextract = "aws_textract"
        case googleVision = "google_vision"
        case azureComputerVision = "azure_computer_vision"
        case tesseract = "tesseract"
        case appleVision = "apple_vision"

        var description: String {
            switch self {
            case .awsTextract: return "AWS Textract (Primary)"
            case .googleVision: return "Google Cloud Vision (Backup)"
            case .azureComputerVision: return "Azure Computer Vision (Backup)"
            case .tesseract: return "Tesseract OCR (Offline Backup)"
            case .appleVision: return "Apple Vision Framework (Local)"
            }
        }

        var isCloudBased: Bool {
            switch self {
            case .awsTextract, .googleVision, .azureComputerVision:
                return true
            case .tesseract, .appleVision:
                return false
            }
        }
    }

    /// Configuration for zero-tolerance OCR
    struct ZeroToleranceOCRConfiguration {
        let minimumConfidenceThreshold: Double
        let requireMultipleOCRPasses: Bool
        let enableBackupServices: Bool
        let maxProcessingTime: TimeInterval
        let enableManualReviewPrompts: Bool
        let criticalFieldValidation: Bool
        let crossValidationThreshold: Double

        static let strict = ZeroToleranceOCRConfiguration(
            minimumConfidenceThreshold: 0.95,
            requireMultipleOCRPasses: true,
            enableBackupServices: true,
            maxProcessingTime: 120.0, // 2 minutes
            enableManualReviewPrompts: true,
            criticalFieldValidation: true,
            crossValidationThreshold: 0.9
        )

        static let balanced = ZeroToleranceOCRConfiguration(
            minimumConfidenceThreshold: 0.85,
            requireMultipleOCRPasses: true,
            enableBackupServices: true,
            maxProcessingTime: 90.0, // 1.5 minutes
            enableManualReviewPrompts: false,
            criticalFieldValidation: true,
            crossValidationThreshold: 0.8
        )
    }

    // MARK: - Properties

    @Published var isProcessing = false
    @Published var currentOCRService: OCRService?
    @Published var processingProgress: Double = 0.0
    @Published var lastOCRResult: MultiPassOCRResult?

    private let configuration: ZeroToleranceOCRConfiguration
    private let logger = Logger(subsystem: "MortgageGuardian", category: "ZeroToleranceOCR")

    // Service providers
    private let googleVisionService: GoogleCloudOCRService
    private let azureVisionService: AzureComputerVisionService
    private let tesseractService: TesseractOCRService
    private let appleVisionService: AppleVisionOCRService

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        configuration: ZeroToleranceOCRConfiguration = .strict,
        googleVisionService: GoogleCloudOCRService = GoogleCloudOCRService.shared,
        azureVisionService: AzureComputerVisionService = AzureComputerVisionService.shared,
        tesseractService: TesseractOCRService = TesseractOCRService.shared,
        appleVisionService: AppleVisionOCRService = AppleVisionOCRService.shared
    ) {
        self.configuration = configuration
        self.googleVisionService = googleVisionService
        self.azureVisionService = azureVisionService
        self.tesseractService = tesseractService
        self.appleVisionService = appleVisionService
    }

    // MARK: - Enhanced Public Methods

    /// Perform zero-tolerance OCR with multiple validation passes
    func performZeroToleranceOCR(_ image: CGImage) async throws -> MultiPassOCRResult {
        guard !isProcessing else {
            throw TextractError.multipleOCRFailure
        }

        await updateProgress(0.0, service: nil)
        isProcessing = true

        let startTime = Date()
        var auditTrail: [MultiPassOCRResult.OCRAuditEntry] = []

        defer {
            Task { @MainActor in
                isProcessing = false
                processingProgress = 0.0
                currentOCRService = nil
            }
        }

        do {
            logger.info("Starting zero-tolerance OCR with multiple validation passes")

            // PASS 1: Primary AWS Textract extraction (0-40% progress)
            await updateProgress(0.1, service: .awsTextract)

            let primaryResult = try await performOCRWithService(
                image: image,
                service: .awsTextract,
                isPrimary: true
            )

            auditTrail.append(createAuditEntry(from: primaryResult))
            await updateProgress(0.4, service: .awsTextract)

            // Check if primary result meets confidence threshold
            if primaryResult.confidence >= configuration.minimumConfidenceThreshold &&
               !configuration.requireMultipleOCRPasses {

                let result = MultiPassOCRResult(
                    primaryResult: primaryResult,
                    backupResults: [],
                    consensusText: primaryResult.extractedText,
                    overallConfidence: primaryResult.confidence,
                    crossValidated: false,
                    discrepancies: [],
                    recommendManualReview: false,
                    auditTrail: auditTrail
                )

                lastOCRResult = result
                return result
            }

            // PASS 2: Backup OCR services for validation (40-80% progress)
            var backupResults: [OCRValidationResult] = []

            if configuration.enableBackupServices {
                let backupServices: [OCRService] = [.googleVision, .azureComputerVision, .appleVision]
                let progressIncrement = 0.4 / Double(backupServices.count)
                var currentProgress = 0.4

                for service in backupServices {
                    await updateProgress(currentProgress, service: service)

                    do {
                        let backupResult = try await performOCRWithService(
                            image: image,
                            service: service,
                            isPrimary: false
                        )

                        backupResults.append(backupResult)
                        auditTrail.append(createAuditEntry(from: backupResult))

                        currentProgress += progressIncrement

                    } catch {
                        logger.warning("Backup OCR service \(service.rawValue) failed: \(error.localizedDescription)")
                        // Continue with other services
                    }
                }
            }

            await updateProgress(0.8, service: nil)

            // PASS 3: Cross-validation and consensus analysis (80-95% progress)
            await updateProgress(0.85, service: nil)

            let (consensusText, discrepancies) = try performCrossValidation(
                primary: primaryResult,
                backups: backupResults
            )

            // Calculate overall confidence based on consensus
            let overallConfidence = calculateOverallConfidence(
                primary: primaryResult,
                backups: backupResults,
                discrepancies: discrepancies
            )

            // Determine if manual review is recommended
            let recommendManualReview = shouldRecommendManualReview(
                primaryResult: primaryResult,
                backupResults: backupResults,
                discrepancies: discrepancies,
                overallConfidence: overallConfidence
            )

            await updateProgress(0.95, service: nil)

            // PASS 4: Final validation and audit trail completion
            let crossValidated = backupResults.count >= 2 &&
                                overallConfidence >= configuration.crossValidationThreshold

            let result = MultiPassOCRResult(
                primaryResult: primaryResult,
                backupResults: backupResults,
                consensusText: consensusText,
                overallConfidence: overallConfidence,
                crossValidated: crossValidated,
                discrepancies: discrepancies,
                recommendManualReview: recommendManualReview,
                auditTrail: auditTrail
            )

            await updateProgress(1.0, service: nil)
            lastOCRResult = result

            let processingTime = Date().timeIntervalSince(startTime)
            logger.info("Zero-tolerance OCR completed in \(String(format: "%.1f", processingTime))s with \(String(format: "%.1f", overallConfidence * 100))% confidence")

            // Trigger manual review prompt if needed
            if recommendManualReview && configuration.enableManualReviewPrompts {
                await promptForManualReview(result: result)
            }

            return result

        } catch {
            logger.error("Zero-tolerance OCR failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Legacy method for backward compatibility - now uses zero-tolerance OCR
    func analyzeDocument(_ image: CGImage) async throws -> String {
        let result = try await performZeroToleranceOCR(image)
        return result.consensusText
    }

    // MARK: - Private OCR Methods

    private func performOCRWithService(
        image: CGImage,
        service: OCRService,
        isPrimary: Bool
    ) async throws -> OCRValidationResult {

        let startTime = Date()

        switch service {
        case .awsTextract:
            return try await performAWSTextractOCR(image: image, startTime: startTime)

        case .googleVision:
            return try await performGoogleVisionOCR(image: image, startTime: startTime)

        case .azureComputerVision:
            return try await performAzureVisionOCR(image: image, startTime: startTime)

        case .tesseract:
            return try await performTesseractOCR(image: image, startTime: startTime)

        case .appleVision:
            return try await performAppleVisionOCR(image: image, startTime: startTime)
        }
    }

    private func performAWSTextractOCR(image: CGImage, startTime: Date) async throws -> OCRValidationResult {
        // Enhanced AWS Textract with detailed confidence analysis
        let jpegData = try convertImageToJPEG(image)
        let credentials = try getAWSCredentials()

        // Perform AWS Textract analysis with enhanced confidence tracking
        let textractResponse = try await callAWSTextractAPI(jpegData: jpegData, credentials: credentials)

        // Parse response and extract confidence data
        let (extractedText, wordConfidences) = try parseTextractResponse(textractResponse)

        // Calculate overall confidence
        let averageConfidence = calculateAverageConfidence(wordConfidences)

        // Validate critical fields if enabled
        let validationPassed = configuration.criticalFieldValidation ?
            validateCriticalFields(wordConfidences) : true

        let processingTime = Date().timeIntervalSince(startTime)

        return OCRValidationResult(
            extractedText: extractedText,
            confidence: averageConfidence,
            service: .awsTextract,
            wordLevelConfidences: wordConfidences,
            validationPassed: validationPassed,
            processingTime: processingTime,
            metadata: ["responseLength": textractResponse.count]
        )
    }

    private func performGoogleVisionOCR(image: CGImage, startTime: Date) async throws -> OCRValidationResult {
        let result = try await googleVisionService.analyzeDocument(image)
        let processingTime = Date().timeIntervalSince(startTime)

        return OCRValidationResult(
            extractedText: result.text,
            confidence: result.confidence,
            service: .googleVision,
            wordLevelConfidences: result.wordConfidences.map {
                OCRValidationResult.WordConfidence(
                    text: $0.text,
                    confidence: $0.confidence,
                    boundingBox: $0.boundingBox,
                    requiresManualReview: $0.confidence < 0.8
                )
            },
            validationPassed: result.confidence >= 0.8,
            processingTime: processingTime,
            metadata: result.metadata
        )
    }

    private func performAzureVisionOCR(image: CGImage, startTime: Date) async throws -> OCRValidationResult {
        let result = try await azureVisionService.analyzeDocument(image)
        let processingTime = Date().timeIntervalSince(startTime)

        return OCRValidationResult(
            extractedText: result.text,
            confidence: result.confidence,
            service: .azureComputerVision,
            wordLevelConfidences: result.wordConfidences.map {
                OCRValidationResult.WordConfidence(
                    text: $0.text,
                    confidence: $0.confidence,
                    boundingBox: $0.boundingBox,
                    requiresManualReview: $0.confidence < 0.75
                )
            },
            validationPassed: result.confidence >= 0.75,
            processingTime: processingTime,
            metadata: result.metadata
        )
    }

    private func performTesseractOCR(image: CGImage, startTime: Date) async throws -> OCRValidationResult {
        let result = try await tesseractService.analyzeDocument(image)
        let processingTime = Date().timeIntervalSince(startTime)

        return OCRValidationResult(
            extractedText: result.text,
            confidence: result.confidence,
            service: .tesseract,
            wordLevelConfidences: result.wordConfidences.map {
                OCRValidationResult.WordConfidence(
                    text: $0.text,
                    confidence: $0.confidence,
                    boundingBox: $0.boundingBox,
                    requiresManualReview: $0.confidence < 0.7
                )
            },
            validationPassed: result.confidence >= 0.7,
            processingTime: processingTime,
            metadata: result.metadata
        )
    }

    private func performAppleVisionOCR(image: CGImage, startTime: Date) async throws -> OCRValidationResult {
        let result = try await appleVisionService.analyzeDocument(image)
        let processingTime = Date().timeIntervalSince(startTime)

        return OCRValidationResult(
            extractedText: result.text,
            confidence: result.confidence,
            service: .appleVision,
            wordLevelConfidences: result.wordConfidences.map {
                OCRValidationResult.WordConfidence(
                    text: $0.text,
                    confidence: $0.confidence,
                    boundingBox: $0.boundingBox,
                    requiresManualReview: $0.confidence < 0.8
                )
            },
            validationPassed: result.confidence >= 0.8,
            processingTime: processingTime,
            metadata: result.metadata
        )
    }

    // MARK: - Cross-Validation Methods

    private func performCrossValidation(
        primary: OCRValidationResult,
        backups: [OCRValidationResult]
    ) throws -> (consensusText: String, discrepancies: [MultiPassOCRResult.TextDiscrepancy]) {

        guard !backups.isEmpty else {
            return (primary.extractedText, [])
        }

        // Compare primary result with backup results word by word
        let primaryWords = primary.extractedText.components(separatedBy: .whitespacesAndNewlines)
        var consensusWords: [String] = []
        var discrepancies: [MultiPassOCRResult.TextDiscrepancy] = []

        for (index, primaryWord) in primaryWords.enumerated() {
            var alternativeWords: [String] = []
            var confidences: [Double] = [getWordConfidence(word: primaryWord, in: primary)]

            // Collect alternatives from backup services
            for backup in backups {
                let backupWords = backup.extractedText.components(separatedBy: .whitespacesAndNewlines)
                if index < backupWords.count {
                    let backupWord = backupWords[index]
                    alternativeWords.append(backupWord)
                    confidences.append(getWordConfidence(word: backupWord, in: backup))
                }
            }

            // Determine consensus word
            let (consensusWord, hasDiscrepancy) = determineConsensusWord(
                primary: primaryWord,
                alternatives: alternativeWords,
                confidences: confidences
            )

            consensusWords.append(consensusWord)

            // Record discrepancy if found
            if hasDiscrepancy {
                let discrepancy = createDiscrepancy(
                    position: index,
                    primaryWord: primaryWord,
                    alternatives: alternativeWords,
                    confidences: confidences
                )
                discrepancies.append(discrepancy)
            }
        }

        let consensusText = consensusWords.joined(separator: " ")
        return (consensusText, discrepancies)
    }

    private func determineConsensusWord(
        primary: String,
        alternatives: [String],
        confidences: [Double]
    ) -> (word: String, hasDiscrepancy: Bool) {

        // Count occurrences of each word variant
        var wordCounts: [String: Int] = [primary: 1]

        for alternative in alternatives {
            wordCounts[alternative, default: 0] += 1
        }

        // Find most common word
        let mostCommon = wordCounts.max { $0.value < $1.value }?.key ?? primary

        // Check for discrepancy
        let hasDiscrepancy = wordCounts.count > 1 ||
                           confidences.max()! - confidences.min()! > 0.2

        return (mostCommon, hasDiscrepancy)
    }

    private func createDiscrepancy(
        position: Int,
        primaryWord: String,
        alternatives: [String],
        confidences: [Double]
    ) -> MultiPassOCRResult.TextDiscrepancy {

        let confidenceSpread = (confidences.max() ?? 0) - (confidences.min() ?? 0)
        let severity = classifyDiscrepancySeverity(word: primaryWord)

        // This is a simplified implementation - would need proper string indexing
        let startIndex = primaryWord.startIndex
        let endIndex = primaryWord.endIndex

        return MultiPassOCRResult.TextDiscrepancy(
            position: startIndex..<endIndex,
            primaryValue: primaryWord,
            alternativeValues: alternatives,
            confidenceSpread: confidenceSpread,
            severity: severity
        )
    }

    private func classifyDiscrepancySeverity(word: String) -> MultiPassOCRResult.TextDiscrepancy.DiscrepancySeverity {
        // Check if word contains numbers or financial information
        if word.rangeOfCharacter(from: .decimalDigits) != nil {
            return .critical
        }

        // Check if word looks like a name or address
        if word.first?.isUppercase == true && word.count > 2 {
            return .high
        }

        // Check if word is common
        let commonWords = ["the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by"]
        if commonWords.contains(word.lowercased()) {
            return .low
        }

        return .medium
    }

    // MARK: - Utility Methods

    @MainActor
    private func updateProgress(_ progress: Double, service: OCRService?) {
        processingProgress = progress
        currentOCRService = service
    }

    private func calculateOverallConfidence(
        primary: OCRValidationResult,
        backups: [OCRValidationResult],
        discrepancies: [MultiPassOCRResult.TextDiscrepancy]
    ) -> Double {

        var allConfidences = [primary.confidence]
        allConfidences.append(contentsOf: backups.map { $0.confidence })

        let averageConfidence = allConfidences.reduce(0, +) / Double(allConfidences.count)

        // Reduce confidence based on discrepancies
        let discrepancyPenalty = Double(discrepancies.count) * 0.02 // 2% per discrepancy

        return max(averageConfidence - discrepancyPenalty, 0.0)
    }

    private func shouldRecommendManualReview(
        primaryResult: OCRValidationResult,
        backupResults: [OCRValidationResult],
        discrepancies: [MultiPassOCRResult.TextDiscrepancy],
        overallConfidence: Double
    ) -> Bool {

        // Recommend manual review if:
        // 1. Overall confidence is below threshold
        if overallConfidence < configuration.minimumConfidenceThreshold {
            return true
        }

        // 2. Critical discrepancies found
        let criticalDiscrepancies = discrepancies.filter { $0.severity == .critical }
        if !criticalDiscrepancies.isEmpty {
            return true
        }

        // 3. Primary validation failed
        if !primaryResult.validationPassed {
            return true
        }

        // 4. Too many total discrepancies
        if discrepancies.count > 10 {
            return true
        }

        return false
    }

    private func createAuditEntry(from result: OCRValidationResult) -> MultiPassOCRResult.OCRAuditEntry {
        let warnings = result.wordLevelConfidences
            .filter { $0.requiresManualReview }
            .map { "Low confidence word: \($0.text) (\(String(format: "%.1f", $0.confidence * 100))%)" }

        return MultiPassOCRResult.OCRAuditEntry(
            service: result.service,
            timestamp: Date(),
            confidence: result.confidence,
            processingTime: result.processingTime,
            errorCount: warnings.count,
            warnings: warnings
        )
    }

    private func promptForManualReview(result: MultiPassOCRResult) async {
        logger.warning("Manual review recommended for OCR result with \(String(format: "%.1f", result.overallConfidence * 100))% confidence")

        // This would trigger UI notification for manual review
        // Implementation would depend on UI framework
    }

    // MARK: - Helper Methods (preserved from original)

    private func convertImageToJPEG(_ image: CGImage) throws -> Data {
        #if canImport(UIKit)
        guard let uiImage = UIImage(cgImage: image),
              let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
            throw TextractError.encodingFailed
        }
        return jpegData
        #else
        guard let data = CFDataCreateMutable(nil, 0) else { throw TextractError.encodingFailed }
        guard let dest = CGImageDestinationCreateWithData(data, kUTTypeJPEG, 1, nil) else { throw TextractError.encodingFailed }
        CGImageDestinationAddImage(dest, image, nil)
        if !CGImageDestinationFinalize(dest) { throw TextractError.encodingFailed }
        return data as Data
        #endif
    }

    private func getWordConfidence(word: String, in result: OCRValidationResult) -> Double {
        return result.wordLevelConfidences
            .first { $0.text == word }?.confidence ?? result.confidence
    }

    private func calculateAverageConfidence(_ wordConfidences: [OCRValidationResult.WordConfidence]) -> Double {
        guard !wordConfidences.isEmpty else { return 0.0 }
        return wordConfidences.reduce(0) { $0 + $1.confidence } / Double(wordConfidences.count)
    }

    private func validateCriticalFields(_ wordConfidences: [OCRValidationResult.WordConfidence]) -> Bool {
        // Validate that critical fields (numbers, dates, amounts) have high confidence
        let criticalWords = wordConfidences.filter { word in
            word.text.rangeOfCharacter(from: .decimalDigits) != nil
        }

        return criticalWords.allSatisfy { $0.confidence >= 0.9 }
    }

    private func parseTextractResponse(_ response: String) throws -> (text: String, wordConfidences: [OCRValidationResult.WordConfidence]) {
        // Parse the JSON response string
        guard let data = response.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let blocks = json["Blocks"] as? [[String: Any]] else {
            throw TextractError.invalidResponse
        }

        var extractedText = ""
        var wordConfidences: [OCRValidationResult.WordConfidence] = []

        for block in blocks {
            guard let blockType = block["BlockType"] as? String else { continue }

            if blockType == "WORD" {
                if let text = block["Text"] as? String,
                   let confidence = block["Confidence"] as? Double,
                   let geometry = block["Geometry"] as? [String: Any],
                   let boundingBox = geometry["BoundingBox"] as? [String: Double] {

                    let rect = CGRect(
                        x: boundingBox["Left"] ?? 0,
                        y: boundingBox["Top"] ?? 0,
                        width: boundingBox["Width"] ?? 0,
                        height: boundingBox["Height"] ?? 0
                    )

                    let wordConfidence = OCRValidationResult.WordConfidence(
                        text: text,
                        confidence: confidence / 100.0, // Convert percentage to decimal
                        boundingBox: rect,
                        requiresManualReview: confidence < 90.0 // Require review if < 90%
                    )

                    wordConfidences.append(wordConfidence)
                }
            } else if blockType == "LINE" {
                if let text = block["Text"] as? String {
                    if !extractedText.isEmpty {
                        extractedText += "\n"
                    }
                    extractedText += text
                }
            }
        }

        return (extractedText, wordConfidences)
    }

    private func callAWSTextractAPI(jpegData: Data, credentials: AWSCredentials) async throws -> String {
        // Create request payload for Textract DetectDocumentText
        let payload = [
            "Document": [
                "Bytes": jpegData.base64EncodedString()
            ]
        ]

        let payloadData = try JSONSerialization.data(withJSONObject: payload)

        // Create AWS request
        let responseData = try await makeAWSRequest(
            service: "textract",
            action: "DetectDocumentText",
            payload: payloadData,
            credentials: credentials
        )

        // Convert response data to string
        guard let responseString = String(data: responseData, encoding: .utf8) else {
            throw TextractError.invalidResponse
        }

        return responseString
    }

    private let credentialsService = "com.mortgageguardian.api.aws_textract"
    private let regionService = "com.mortgageguardian.api.aws_region"

    private struct AWSCredentials {
        let accessKeyId: String
        let secretAccessKey: String
        let region: String
    }

    // MARK: - AWS API Methods (preserved from original implementation)

    func analyzeDocument(_ image: CGImage) async throws -> String {
        // Convert CGImage to JPEG data
        let jpegData: Data
        #if canImport(UIKit)
        guard let uiImage = UIImage(cgImage: image),
              let d = uiImage.jpegData(compressionQuality: 0.8) else {
            throw TextractError.encodingFailed
        }
        jpegData = d
        #else
        guard let data = CFDataCreateMutable(nil, 0) else { throw TextractError.encodingFailed }
        guard let dest = CGImageDestinationCreateWithData(data, kUTTypeJPEG, 1, nil) else { throw TextractError.encodingFailed }
        CGImageDestinationAddImage(dest, image, nil)
        if !CGImageDestinationFinalize(dest) { throw TextractError.encodingFailed }
        jpegData = data as Data
        #endif

        // Get AWS credentials
        let credentials = try getAWSCredentials()

        // Create request payload for Textract DetectDocumentText
        let payload = [
            "Document": [
                "Bytes": jpegData.base64EncodedString()
            ]
        ]

        let payloadData = try JSONSerialization.data(withJSONObject: payload)

        // Create AWS request
        let response = try await makeAWSRequest(
            service: "textract",
            action: "DetectDocumentText",
            payload: payloadData,
            credentials: credentials
        )

        // Parse Textract response
        return try parseTextractResponse(response)
    }

    private func getAWSCredentials() throws -> AWSCredentials {
        guard let credentialsString = try? SecureKeyManager.shared.getAPIKey(forService: credentialsService),
              let regionString = try? SecureKeyManager.shared.getAPIKey(forService: regionService) else {
            throw TextractError.missingCredentials
        }

        // Parse credentials (format: "accessKeyId:secretAccessKey")
        let components = credentialsString.components(separatedBy: ":")
        guard components.count == 2 else {
            throw TextractError.invalidAWSCredentials
        }

        return AWSCredentials(
            accessKeyId: components[0],
            secretAccessKey: components[1],
            region: regionString
        )
    }

    private func makeAWSRequest(
        service: String,
        action: String,
        payload: Data,
        credentials: AWSCredentials
    ) async throws -> Data {
        let endpoint = "https://textract.\(credentials.region).amazonaws.com/"
        guard let url = URL(string: endpoint) else {
            throw TextractError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload

        // AWS headers
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("Textract_20180630.\(action)", forHTTPHeaderField: "X-Amz-Target")

        // Add AWS signature v4 headers
        try addAWSSignature(
            to: &request,
            payload: payload,
            credentials: credentials,
            service: service
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw TextractError.invalidResponse
            }

            if !(200...299).contains(http.statusCode) {
                // Log error response for debugging
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("AWS Textract error (\(http.statusCode)): \(errorString)")
                throw TextractError.invalidResponse
            }

            return data
        } catch {
            throw TextractError.networkError(error)
        }
    }

    private func addAWSSignature(
        to request: inout URLRequest,
        payload: Data,
        credentials: AWSCredentials,
        service: String
    ) throws {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: now)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateStamp = dateFormatter.format(now)

        // Add required headers
        request.setValue(timestamp, forHTTPHeaderField: "X-Amz-Date")
        request.setValue("host;x-amz-date;x-amz-target", forHTTPHeaderField: "Signed-Headers")

        // Create canonical request
        let host = request.url?.host ?? ""
        let canonicalHeaders = "host:\(host)\nx-amz-date:\(timestamp)\nx-amz-target:\(request.value(forHTTPHeaderField: "X-Amz-Target") ?? "")\n"
        let payloadHash = sha256Hash(payload)

        let canonicalRequest = """
        \(request.httpMethod ?? "POST")
        /

        \(canonicalHeaders)
        host;x-amz-date;x-amz-target
        \(payloadHash)
        """

        // Create string to sign
        let credentialScope = "\(dateStamp)/\(credentials.region)/\(service)/aws4_request"
        let stringToSign = """
        AWS4-HMAC-SHA256
        \(timestamp)
        \(credentialScope)
        \(sha256Hash(canonicalRequest.data(using: .utf8) ?? Data()))
        """

        // Calculate signature
        let signature = try calculateAWSSignature(
            stringToSign: stringToSign,
            dateStamp: dateStamp,
            region: credentials.region,
            service: service,
            secretKey: credentials.secretAccessKey
        )

        // Add authorization header
        let authorization = "AWS4-HMAC-SHA256 Credential=\(credentials.accessKeyId)/\(credentialScope), SignedHeaders=host;x-amz-date;x-amz-target, Signature=\(signature)"
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
    }

    private func calculateAWSSignature(
        stringToSign: String,
        dateStamp: String,
        region: String,
        service: String,
        secretKey: String
    ) throws -> String {
        let kDate = try hmacSHA256(key: "AWS4\(secretKey)".data(using: .utf8)!, data: dateStamp.data(using: .utf8)!)
        let kRegion = try hmacSHA256(key: kDate, data: region.data(using: .utf8)!)
        let kService = try hmacSHA256(key: kRegion, data: service.data(using: .utf8)!)
        let kSigning = try hmacSHA256(key: kService, data: "aws4_request".data(using: .utf8)!)
        let signature = try hmacSHA256(key: kSigning, data: stringToSign.data(using: .utf8)!)

        return signature.map { String(format: "%02x", $0) }.joined()
    }

    private func hmacSHA256(key: Data, data: Data) throws -> Data {
        let keyPtr = key.withUnsafeBytes { $0.baseAddress }
        let dataPtr = data.withUnsafeBytes { $0.baseAddress }

        var result = Data(count: Int(CC_SHA256_DIGEST_LENGTH))

        result.withUnsafeMutableBytes { resultPtr in
            CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyPtr, key.count, dataPtr, data.count, resultPtr.baseAddress)
        }

        return result
    }

    private func sha256Hash(_ data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func parseTextractResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let blocks = json["Blocks"] as? [[String: Any]] else {
            throw TextractError.invalidResponse
        }

        var lines: [String] = []

        for block in blocks {
            if let blockType = block["BlockType"] as? String,
               blockType == "LINE",
               let text = block["Text"] as? String {
                lines.append(text)
            }
        }

        return lines.joined(separator: "\n")
    }
}

// Helper extension for CC_SHA256 and CCHmac
import CommonCrypto

private extension DateFormatter {
    func format(_ date: Date) -> String {
        return string(from: date)
    }
}