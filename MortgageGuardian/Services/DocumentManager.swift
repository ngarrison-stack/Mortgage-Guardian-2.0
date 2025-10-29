// DocumentManager.swift
import Foundation
import UIKit
import Vision
import Clerk

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

        // Create multipart form data
        var request = URLRequest(url: URL(string: "\(APIClient.shared.baseURL)/documents/upload")!)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()

        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"document.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // Add OCR data if available
        if let ocrText = ocrText {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"ocr_text\"\r\n\r\n".data(using: .utf8)!)
            body.append(ocrText.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"ocr_confidence\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(ocrConfidence ?? 0)".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"ocr_method\"\r\n\r\n".data(using: .utf8)!)
            body.append(ocrMethod.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder().decode(DocumentUploadResult.self, from: data)

        return result
    }

    func fetchDocuments() async throws {
        let response: DocumentListResponse = try await APIClient.shared.request(
            endpoint: "/documents",
            responseType: DocumentListResponse.self
        )
        self.documents = response.documents
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

    private func getAuthToken() async -> String? {
        try? await Clerk.shared.session?.getToken()?.jwt
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

struct DocumentListResponse: Decodable {
    let documents: [Document]
}

enum DocumentError: Error {
    case invalidImage
    case compressionFailed
    case uploadFailed
}