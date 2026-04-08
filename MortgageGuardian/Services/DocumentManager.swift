// DocumentManager.swift
import Foundation
import UIKit
import Vision


@MainActor
class DocumentManager: ObservableObject {
    @Published var documents: [Document] = []
    @Published var isProcessing = false

    // Try Vision Framework OCR first (FREE!)
    func processDocument(_ image: UIImage) async throws -> DocumentUploadResult {
        isProcessing = true
        defer { isProcessing = false }

        // Step 1: Try on-device OCR first
        let visionResult = try await performVisionOCR(on: image)

        if visionResult.confidence > 0.90 {
            // High confidence - use Vision Framework result
            return try await uploadDocument(
                image: image,
                ocrText: visionResult.text,
                ocrConfidence: visionResult.confidence,
                ocrMethod: "vision_framework"
            )
        } else {
            // Low confidence - let backend handle with Google Cloud Vision
            return try await uploadDocument(
                image: image,
                ocrText: nil,
                ocrConfidence: nil,
                ocrMethod: "pending"
            )
        }
    }

    private func performVisionOCR(on image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw DocumentError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            return OCRResult(text: "", confidence: 0)
        }

        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")

        let avgConfidence = observations
            .map { $0.confidence }
            .reduce(0, +) / Float(observations.count)

        return OCRResult(text: text, confidence: avgConfidence)
    }

    private func uploadDocument(
        image: UIImage,
        ocrText: String?,
        ocrConfidence: Float?,
        ocrMethod: String
    ) async throws -> DocumentUploadResult {

        // Convert to JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw DocumentError.compressionFailed
        }

        // Upload via APIClient with base64 content
        let base64Content = imageData.base64EncodedString()
        let documentId = UUID().uuidString
        let fileName = "document.jpg"

        let response = try await APIClient.shared.uploadDocument(
            documentId: documentId,
            fileName: fileName,
            documentType: "mortgage_document",
            content: base64Content,
            metadata: ocrText != nil ? [
                "ocr_text": AnyCodable(ocrText!),
                "ocr_confidence": AnyCodable(ocrConfidence ?? 0),
                "ocr_method": AnyCodable(ocrMethod)
            ] : nil
        )

        return DocumentUploadResult(
            success: response.success,
            document: DocumentInfo(
                id: response.documentId ?? documentId,
                filename: fileName,
                status: "uploaded"
            )
        )
    }

    func fetchDocuments() async throws {
        let response = try await APIClient.shared.fetchDocuments()
        self.documents = response.documents.map { doc in
            Document(
                id: doc.id ?? doc.documentId ?? "",
                filename: doc.fileName ?? "",
                file_size: 0,
                ocr_confidence: nil,
                created_at: doc.createdAt ?? "",
                updated_at: doc.updatedAt ?? ""
            )
        }
    }

    func askQuestion(documentId: String, question: String) async throws -> String {
        struct Request: Encodable {
            let documentId: String
            let question: String
        }

        struct Response: Decodable {
            let answer: String
        }

        let requestData = try JSONEncoder().encode(Request(documentId: documentId, question: question))

        let response: Response = try await APIClient.shared.request(
            endpoint: "/analysis/ask",
            method: .POST,
            body: requestData,
            responseType: Response.self
        )

        return response.answer
    }

}

// Models
struct OCRResult {
    let text: String
    let confidence: Float
}

struct DocumentUploadResult: Decodable {
    let success: Bool
    let document: DocumentInfo
}

struct DocumentInfo: Decodable, Identifiable {
    let id: String
    let filename: String
    let status: String
}

struct Document: Decodable, Identifiable {
    let id: String
    let filename: String
    let file_size: Int
    let ocr_confidence: Float?
    let created_at: String
    let updated_at: String
}

enum DocumentError: Error {
    case invalidImage
    case compressionFailed
    case uploadFailed
}