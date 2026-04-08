import Foundation
import SwiftUI
import UIKit
import AVFoundation
import PhotosUI
import UniformTypeIdentifiers
import Combine
import os.log

/// ViewModel for managing document capture, import, and processing operations
@MainActor
class DocumentCaptureViewModel: ObservableObject {

    // MARK: - Types

    enum CaptureMode {
        case camera
        case photoLibrary
        case fileImport
        case dragAndDrop
    }

    enum ProcessingState {
        case idle
        case capturing
        case importing
        case processing
        case enhancing
        case completed
        case failed(Error)
    }

    enum UploadProgress {
        case idle
        case uploading
        case uploaded(serverDocumentId: String)
        case uploadFailed(Error)
    }

    enum CaptureError: LocalizedError {
        case cameraNotAvailable
        case cameraPermissionDenied
        case photoLibraryPermissionDenied
        case fileImportFailed(String)
        case unsupportedFileType
        case fileSizeExceeded
        case processingFailed(Error)
        case noImageSelected
        case invalidImageData

        var errorDescription: String? {
            switch self {
            case .cameraNotAvailable:
                return "Camera is not available on this device"
            case .cameraPermissionDenied:
                return "Camera permission is required to capture documents"
            case .photoLibraryPermissionDenied:
                return "Photo library access is required to import images"
            case .fileImportFailed(let reason):
                return "File import failed: \(reason)"
            case .unsupportedFileType:
                return "File type not supported. Please use PDF, JPEG, PNG, or HEIC files"
            case .fileSizeExceeded:
                return "File size exceeds 50MB limit"
            case .processingFailed(let error):
                return "Document processing failed: \(error.localizedDescription)"
            case .noImageSelected:
                return "No image was selected"
            case .invalidImageData:
                return "Invalid image data"
            }
        }
    }

    struct CapturedDocument {
        let id = UUID()
        let originalImage: UIImage
        let enhancedImage: UIImage?
        let fileName: String
        let captureDate: Date
        let captureMode: CaptureMode
        var documentType: MortgageDocument.DocumentType = .other
        var customName: String?

        var displayName: String {
            return customName ?? fileName
        }
    }

    // MARK: - Published Properties

    @Published var uploadProgress: UploadProgress = .idle
    @Published var processingState: ProcessingState = .idle
    @Published var capturedDocuments: [CapturedDocument] = []
    @Published var selectedDocument: CapturedDocument?
    @Published var processingProgress: Double = 0.0
    @Published var processingMessage: String = ""
    @Published var errorMessage: String?
    @Published var showingCamera = false
    @Published var showingPhotoLibrary = false
    @Published var showingFilePicker = false
    @Published var showingDocumentPreview = false

    // Photo picker configuration
    @Published var photoPickerItems: [PhotosPickerItem] = []

    // Camera configuration
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var photoLibraryPermissionStatus: PHAuthorizationStatus = .notDetermined

    // Processing configuration
    @Published var batchProcessingEnabled = false
    @Published var autoEnhanceEnabled = true
    @Published var ocrEnabled = true
    @Published var autoDocumentTypeDetection = true

    // MARK: - Private Properties

    private let documentProcessor: DocumentProcessor
    private let securityService: SecurityService
    private let userStore: UserStore
    private let permissionsManager: PermissionsManager
    private let logger = Logger(subsystem: "com.mortgageguardian", category: "DocumentCapture")
    private var cancellables = Set<AnyCancellable>()

    private let maxFileSize: Int = 50 * 1024 * 1024 // 50MB
    private let supportedFileTypes: [UTType] = [.jpeg, .png, .heic, .pdf]
    private let supportedMimeTypes = ["image/jpeg", "image/png", "image/heic", "application/pdf"]

    // MARK: - Initialization

    init(documentProcessor: DocumentProcessor, securityService: SecurityService, userStore: UserStore, permissionsManager: PermissionsManager = .shared) {
        self.documentProcessor = documentProcessor
        self.securityService = securityService
        self.userStore = userStore
        self.permissionsManager = permissionsManager

        setupBindings()
        syncPermissions()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Monitor document processor progress
        documentProcessor.$currentProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                if let progress = progress {
                    self?.processingProgress = progress.percentComplete / 100.0
                    self?.processingMessage = progress.message
                }
            }
            .store(in: &cancellables)

        // Monitor photo picker selections
        $photoPickerItems
            .sink { [weak self] items in
                Task {
                    await self?.handlePhotoPickerSelection(items)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Permission Management

    private func syncPermissions() {
        // Sync with permissions manager
        permissionsManager.$cameraPermission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.cameraPermissionStatus = self?.mapPermissionStatus(status) ?? .notDetermined
            }
            .store(in: &cancellables)

        permissionsManager.$photoLibraryPermission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.photoLibraryPermissionStatus = self?.mapPermissionStatusToPH(status) ?? .notDetermined
            }
            .store(in: &cancellables)

        permissionsManager.checkAllPermissions()
    }

    private func mapPermissionStatus(_ status: PermissionsManager.PermissionStatus) -> AVAuthorizationStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized, .limited: return .authorized
        }
    }

    private func mapPermissionStatusToPH(_ status: PermissionsManager.PermissionStatus) -> PHAuthorizationStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        case .limited: return .limited
        }
    }

    func requestCameraPermission() async -> Bool {
        let status = await permissionsManager.requestCameraPermission()
        return status == .authorized
    }

    func requestPhotoLibraryPermission() async -> Bool {
        let status = await permissionsManager.requestPhotoLibraryPermission()
        return status == .authorized || status == .limited
    }

    // MARK: - Camera Capture

    func startCameraCapture() async {
        do {
            // Check camera availability
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                throw CaptureError.cameraNotAvailable
            }

            // Request permission if needed
            if cameraPermissionStatus != .authorized {
                let granted = await requestCameraPermission()
                guard granted else {
                    throw CaptureError.cameraPermissionDenied
                }
            }

            showingCamera = true

        } catch {
            errorMessage = error.localizedDescription
            logger.error("Camera capture failed: \(error.localizedDescription)")
        }
    }

    func handleCameraCapture(_ image: UIImage) async {
        processingState = .capturing

        do {
            let fileName = generateFileName(for: .camera)
            let capturedDoc = CapturedDocument(
                originalImage: image,
                enhancedImage: nil,
                fileName: fileName,
                captureDate: Date(),
                captureMode: .camera
            )

            // Auto-enhance if enabled
            var finalDoc = capturedDoc
            if autoEnhanceEnabled {
                processingState = .enhancing
                processingMessage = "Enhancing image quality..."

                if let enhancedImage = await enhanceImageForOCR(image) {
                    finalDoc = CapturedDocument(
                        originalImage: image,
                        enhancedImage: enhancedImage,
                        fileName: fileName,
                        captureDate: capturedDoc.captureDate,
                        captureMode: .camera,
                        documentType: capturedDoc.documentType,
                        customName: capturedDoc.customName
                    )
                }
            }

            capturedDocuments.append(finalDoc)
            selectedDocument = finalDoc

            // Auto-detect document type if enabled
            if autoDocumentTypeDetection && ocrEnabled {
                await detectDocumentType(for: finalDoc)
            }

            processingState = .completed
            showingDocumentPreview = true

            logger.info("Document captured successfully: \(fileName)")

        } catch {
            processingState = .failed(error)
            errorMessage = error.localizedDescription
            logger.error("Document capture processing failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Photo Library Import

    func startPhotoLibraryImport() async {
        do {
            // Request permission if needed
            if photoLibraryPermissionStatus != .authorized && photoLibraryPermissionStatus != .limited {
                let granted = await requestPhotoLibraryPermission()
                guard granted else {
                    throw CaptureError.photoLibraryPermissionDenied
                }
            }

            showingPhotoLibrary = true

        } catch {
            errorMessage = error.localizedDescription
            logger.error("Photo library import failed: \(error.localizedDescription)")
        }
    }

    private func handlePhotoPickerSelection(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        processingState = .importing

        for item in items {
            do {
                guard let imageData = try await item.loadTransferable(type: Data.self) else {
                    throw CaptureError.invalidImageData
                }

                guard let image = UIImage(data: imageData) else {
                    throw CaptureError.invalidImageData
                }

                let fileName = generateFileName(for: .photoLibrary, item: item)
                await processImportedImage(image, fileName: fileName, mode: .photoLibrary)

            } catch {
                logger.error("Failed to process photo picker item: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }

        processingState = .completed
        photoPickerItems.removeAll()
    }

    // MARK: - File Import

    func startFileImport() {
        showingFilePicker = true
    }

    func handleFileImport(_ result: Result<[URL], Error>) async {
        processingState = .importing

        switch result {
        case .success(let urls):
            for url in urls {
                do {
                    try await processFileURL(url)
                } catch {
                    logger.error("Failed to process file: \(url.lastPathComponent) - \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                }
            }
            processingState = .completed

        case .failure(let error):
            processingState = .failed(error)
            errorMessage = error.localizedDescription
            logger.error("File import failed: \(error.localizedDescription)")
        }
    }

    private func processFileURL(_ url: URL) async throws {
        // Security check
        guard url.startAccessingSecurityScopedResource() else {
            throw CaptureError.fileImportFailed("Security access denied")
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Validate file type
        let fileExtension = url.pathExtension.lowercased()
        guard ["pdf", "jpg", "jpeg", "png", "heic"].contains(fileExtension) else {
            throw CaptureError.unsupportedFileType
        }

        // Check file size
        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard fileSize <= maxFileSize else {
            throw CaptureError.fileSizeExceeded
        }

        let fileName = url.lastPathComponent

        if fileExtension == "pdf" {
            try await processPDFFile(url, fileName: fileName)
        } else {
            let imageData = try Data(contentsOf: url)
            guard let image = UIImage(data: imageData) else {
                throw CaptureError.invalidImageData
            }
            await processImportedImage(image, fileName: fileName, mode: .fileImport)
        }
    }

    private func processPDFFile(_ url: URL, fileName: String) async throws {
        // For PDFs, we'll let the DocumentProcessor handle the conversion
        // This is a simplified implementation - in production you might want to
        // show PDF preview and let users select specific pages

        let pdfData = try Data(contentsOf: url)

        // Create a placeholder document for PDF processing
        // The actual processing will happen when user confirms
        let capturedDoc = CapturedDocument(
            originalImage: createPDFThumbnail(from: pdfData) ?? UIImage(),
            enhancedImage: nil,
            fileName: fileName,
            captureDate: Date(),
            captureMode: .fileImport
        )

        capturedDocuments.append(capturedDoc)
        selectedDocument = capturedDoc
        showingDocumentPreview = true
    }

    private func processImportedImage(_ image: UIImage, fileName: String, mode: CaptureMode) async {
        var capturedDoc = CapturedDocument(
            originalImage: image,
            enhancedImage: nil,
            fileName: fileName,
            captureDate: Date(),
            captureMode: mode
        )

        // Auto-enhance if enabled
        if autoEnhanceEnabled {
            processingState = .enhancing
            processingMessage = "Enhancing image quality..."

            if let enhancedImage = await enhanceImageForOCR(image) {
                capturedDoc = CapturedDocument(
                    originalImage: image,
                    enhancedImage: enhancedImage,
                    fileName: fileName,
                    captureDate: capturedDoc.captureDate,
                    captureMode: mode,
                    documentType: capturedDoc.documentType,
                    customName: capturedDoc.customName
                )
            }
        }

        capturedDocuments.append(capturedDoc)
        selectedDocument = capturedDoc

        // Auto-detect document type if enabled
        if autoDocumentTypeDetection && ocrEnabled {
            await detectDocumentType(for: capturedDoc)
        }

        showingDocumentPreview = true
    }

    // MARK: - Drag and Drop

    func handleDroppedFiles(_ providers: [NSItemProvider]) async {
        processingState = .importing

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                await handleDroppedImage(provider)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                await handleDroppedPDF(provider)
            }
        }

        processingState = .completed
    }

    private func handleDroppedImage(_ provider: NSItemProvider) async {
        do {
            let data = try await provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier)
            guard let image = UIImage(data: data) else {
                throw CaptureError.invalidImageData
            }

            let fileName = generateFileName(for: .dragAndDrop)
            await processImportedImage(image, fileName: fileName, mode: .dragAndDrop)

        } catch {
            logger.error("Failed to process dropped image: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    private func handleDroppedPDF(_ provider: NSItemProvider) async {
        do {
            let data = try await provider.loadDataRepresentation(forTypeIdentifier: UTType.pdf.identifier)
            let fileName = "dropped_document_\(Date().timeIntervalSince1970).pdf"

            // Create placeholder for PDF
            let capturedDoc = CapturedDocument(
                originalImage: createPDFThumbnail(from: data) ?? UIImage(),
                enhancedImage: nil,
                fileName: fileName,
                captureDate: Date(),
                captureMode: .dragAndDrop
            )

            capturedDocuments.append(capturedDoc)
            selectedDocument = capturedDoc
            showingDocumentPreview = true

        } catch {
            logger.error("Failed to process dropped PDF: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Document Processing

    func processSelectedDocument() async {
        guard let document = selectedDocument else { return }

        processingState = .processing

        do {
            // Convert image to data
            let imageToProcess = document.enhancedImage ?? document.originalImage
            guard let imageData = imageToProcess.jpegData(compressionQuality: 0.9) else {
                throw CaptureError.invalidImageData
            }

            // Process with DocumentProcessor (local OCR via Vision Framework)
            let processedDocument = try await documentProcessor.processDocument(
                from: imageData,
                fileName: document.fileName
            )

            // Add to user store
            userStore.addDocument(processedDocument)

            processingState = .completed
            processingMessage = "Document processed successfully"

            logger.info("Document processing completed for: \(document.fileName)")

            // Upload to Express backend
            await uploadDocumentToBackend(
                processedDocument: processedDocument,
                imageData: imageData
            )

        } catch {
            processingState = .failed(error)
            errorMessage = error.localizedDescription
            logger.error("Document processing failed: \(error.localizedDescription)")
        }
    }

    /// Uploads a locally processed document to the Express backend.
    private func uploadDocumentToBackend(
        processedDocument: MortgageDocument,
        imageData: Data
    ) async {
        let documentId = UUID().uuidString
        let base64Content = imageData.base64EncodedString()
        let documentType = processedDocument.documentType.rawValue

        uploadProgress = .uploading
        processingMessage = "Uploading document to server..."

        do {
            let metadata: [String: AnyCodable] = [
                "ocr_text": AnyCodable(processedDocument.originalText),
                "ocr_method": AnyCodable("vision_framework")
            ]

            let response = try await APIClient.shared.uploadDocument(
                documentId: documentId,
                fileName: processedDocument.fileName,
                documentType: documentType,
                content: base64Content,
                metadata: metadata
            )

            let serverDocumentId = response.documentId ?? documentId
            uploadProgress = .uploaded(serverDocumentId: serverDocumentId)
            processingMessage = "Document uploaded — analysis in progress"

            logger.info("Document uploaded to backend: \(serverDocumentId)")

            // Trigger backend processing pipeline (fire-and-forget)
            do {
                try await APIClient.shared.processDocument(
                    documentId: serverDocumentId,
                    documentText: processedDocument.originalText,
                    documentType: documentType
                )
                logger.info("Backend processing triggered for: \(serverDocumentId)")
            } catch {
                logger.error("Backend processing trigger failed: \(error.localizedDescription)")
            }

        } catch {
            uploadProgress = .uploadFailed(error)
            logger.error("Document upload failed: \(error.localizedDescription)")
        }
    }

    func processBatchDocuments() async {
        guard !capturedDocuments.isEmpty else { return }

        processingState = .processing
        batchProcessingEnabled = true

        var documentsToProcess: [(data: Data, fileName: String)] = []

        for document in capturedDocuments {
            let imageToProcess = document.enhancedImage ?? document.originalImage
            if let imageData = imageToProcess.jpegData(compressionQuality: 0.9) {
                documentsToProcess.append((data: imageData, fileName: document.fileName))
            }
        }

        do {
            let processedDocuments = try await documentProcessor.processBatch(documents: documentsToProcess)

            // Add all processed documents to user store
            for document in processedDocuments {
                userStore.addDocument(document)
            }

            processingState = .completed
            processingMessage = "Batch processing completed"
            batchProcessingEnabled = false

            logger.info("Batch processing completed for \(processedDocuments.count) documents")

            // Upload each processed document to backend
            for (index, processedDocument) in processedDocuments.enumerated() {
                // Find matching image data from the original batch
                if index < documentsToProcess.count {
                    let imageData = documentsToProcess[index].data
                    await uploadDocumentToBackend(
                        processedDocument: processedDocument,
                        imageData: imageData
                    )
                }
            }

        } catch {
            processingState = .failed(error)
            errorMessage = error.localizedDescription
            batchProcessingEnabled = false
            logger.error("Batch processing failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Backend Upload

    /// Upload the processed document to the Express backend for server-side analysis.
    func uploadDocumentToBackend(_ document: MortgageDocument) async {
        processingMessage = "Uploading to server..."

        do {
            try await APIClient.shared.processDocument(
                documentId: document.serverDocumentId ?? document.id.uuidString,
                documentText: document.originalText.isEmpty ? nil : document.originalText,
                documentType: document.documentType.rawValue
            )
            processingMessage = "Upload complete"
            logger.info("Document uploaded to backend: \(document.fileName)")
        } catch {
            if let apiError = error as? APIError {
                switch apiError {
                case .networkError:
                    processingMessage = "No internet connection. Document saved locally."
                case .authenticationError:
                    processingMessage = "Session expired. Please sign in again."
                default:
                    processingMessage = "Upload failed. Please try again."
                }
            } else {
                processingMessage = "Upload failed. Please try again."
            }
            logger.error("Document upload failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Image Enhancement

    private func enhanceImageForOCR(_ image: UIImage) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let cgImage = image.cgImage else {
                    continuation.resume(returning: nil)
                    return
                }

                let context = CIContext()
                let ciImage = CIImage(cgImage: cgImage)

                var enhancedImage = ciImage

                // Convert to grayscale
                if let grayscaleFilter = CIFilter(name: "CIColorControls") {
                    grayscaleFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
                    grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey)
                    if let output = grayscaleFilter.outputImage {
                        enhancedImage = output
                    }
                }

                // Enhance contrast
                if let contrastFilter = CIFilter(name: "CIColorControls") {
                    contrastFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
                    contrastFilter.setValue(1.4, forKey: kCIInputContrastKey)
                    contrastFilter.setValue(0.1, forKey: kCIInputBrightnessKey)
                    if let output = contrastFilter.outputImage {
                        enhancedImage = output
                    }
                }

                // Sharpen
                if let sharpenFilter = CIFilter(name: "CIUnsharpMask") {
                    sharpenFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
                    sharpenFilter.setValue(0.5, forKey: kCIInputIntensityKey)
                    sharpenFilter.setValue(2.5, forKey: kCIInputRadiusKey)
                    if let output = sharpenFilter.outputImage {
                        enhancedImage = output
                    }
                }

                if let processedCGImage = context.createCGImage(enhancedImage, from: enhancedImage.extent) {
                    let processedUIImage = UIImage(cgImage: processedCGImage)
                    continuation.resume(returning: processedUIImage)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Document Type Detection

    private func detectDocumentType(for document: CapturedDocument) async {
        // Simple OCR for document type detection
        // This is a lightweight version - full processing happens later
        guard let imageData = document.originalImage.jpegData(compressionQuality: 0.8) else { return }

        do {
            let config = DocumentProcessor.OCRConfiguration.fast
            let tempDocument = try await documentProcessor.processDocument(
                from: imageData,
                fileName: document.fileName,
                configuration: config
            )

            // Update the captured document with detected type
            if let index = capturedDocuments.firstIndex(where: { $0.id == document.id }) {
                capturedDocuments[index] = CapturedDocument(
                    originalImage: document.originalImage,
                    enhancedImage: document.enhancedImage,
                    fileName: document.fileName,
                    captureDate: document.captureDate,
                    captureMode: document.captureMode,
                    documentType: tempDocument.documentType,
                    customName: document.customName
                )
            }

        } catch {
            logger.error("Document type detection failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Utility Methods

    private func generateFileName(for mode: CaptureMode, item: PhotosPickerItem? = nil) -> String {
        let timestamp = DateFormatter.fileTimestamp.string(from: Date())

        switch mode {
        case .camera:
            return "camera_capture_\(timestamp).jpg"
        case .photoLibrary:
            if let item = item,
               let identifier = item.itemIdentifier {
                return "photo_\(identifier)_\(timestamp).jpg"
            }
            return "photo_import_\(timestamp).jpg"
        case .fileImport:
            return "file_import_\(timestamp).jpg"
        case .dragAndDrop:
            return "dropped_document_\(timestamp).jpg"
        }
    }

    private func createPDFThumbnail(from data: Data) -> UIImage? {
        guard let document = CGPDFDocument(CGDataProvider(data: data as CFData)!),
              let page = document.page(at: 1) else {
            return nil
        }

        let pageRect = page.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)

        return renderer.image { context in
            UIColor.white.set()
            context.fill(pageRect)

            context.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            context.cgContext.drawPDFPage(page)
        }
    }

    // MARK: - Actions

    func clearCapturedDocuments() {
        capturedDocuments.removeAll()
        selectedDocument = nil
        processingState = .idle
        errorMessage = nil
    }

    func removeDocument(_ document: CapturedDocument) {
        capturedDocuments.removeAll { $0.id == document.id }
        if selectedDocument?.id == document.id {
            selectedDocument = nil
        }
    }

    func updateDocumentName(_ document: CapturedDocument, name: String) {
        if let index = capturedDocuments.firstIndex(where: { $0.id == document.id }) {
            capturedDocuments[index] = CapturedDocument(
                originalImage: document.originalImage,
                enhancedImage: document.enhancedImage,
                fileName: document.fileName,
                captureDate: document.captureDate,
                captureMode: document.captureMode,
                documentType: document.documentType,
                customName: name
            )
        }
    }

    func updateDocumentType(_ document: CapturedDocument, type: MortgageDocument.DocumentType) {
        if let index = capturedDocuments.firstIndex(where: { $0.id == document.id }) {
            capturedDocuments[index] = CapturedDocument(
                originalImage: document.originalImage,
                enhancedImage: document.enhancedImage,
                fileName: document.fileName,
                captureDate: document.captureDate,
                captureMode: document.captureMode,
                documentType: type,
                customName: document.customName
            )
        }
    }

    func dismissError() {
        errorMessage = nil
        if case .failed = processingState {
            processingState = .idle
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}

extension NSItemProvider {
    func loadDataRepresentation(forTypeIdentifier typeIdentifier: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: DocumentCaptureViewModel.CaptureError.invalidImageData)
                }
            }
        }
    }
}