import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct DocumentPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userStore: UserStore
    @StateObject private var documentStorageService = DocumentStorageService.shared

    @State private var selectedItem: PhotosPickerItem?
    @State private var documentType: MortgageDocument.DocumentType = .mortgageStatement
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    @State private var showingCamera = false
    @State private var showingFileImporter = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var fileName = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)

                        Text("Upload Document")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Choose how you'd like to add your mortgage document")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)

                    // Upload Options
                    VStack(spacing: 16) {
                        // Photo Library
                        Button {
                            // PhotosPicker will be triggered by the sheet
                        } label: {
                            UploadOptionCard(
                                icon: "photo.on.rectangle",
                                title: "Photo Library",
                                description: "Select from your photos"
                            )
                        }
                        .photosPicker(isPresented: .constant(true), selection: $selectedItem, matching: .images)

                        // Camera
                        Button {
                            showingCamera = true
                        } label: {
                            UploadOptionCard(
                                icon: "camera",
                                title: "Take Photo",
                                description: "Capture document with camera"
                            )
                        }

                        // File Import
                        Button {
                            showingFileImporter = true
                        } label: {
                            UploadOptionCard(
                                icon: "folder",
                                title: "Browse Files",
                                description: "Import PDF or image files"
                            )
                        }
                    }

                    // Document Type Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Document Type")
                            .font(.headline)
                            .fontWeight(.semibold)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(MortgageDocument.DocumentType.allCases, id: \.self) { type in
                                DocumentTypeCard(
                                    type: type,
                                    isSelected: documentType == type
                                ) {
                                    documentType = type
                                }
                            }
                        }
                    }

                    // Custom File Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("File Name (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("Enter custom name...", text: $fileName)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    // Upload Progress
                    if isUploading {
                        VStack(spacing: 12) {
                            ProgressView(value: uploadProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))

                            Text("Uploading document...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView { image in
                    processImage(image, fileName: "Camera_\(Date().timeIntervalSince1970)")
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .onChange(of: selectedItem) { newItem in
                if let newItem = newItem {
                    loadSelectedPhoto(newItem)
                }
            }
            .alert("Upload Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    // MARK: - Private Methods

    private func loadSelectedPhoto(_ item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                showError("Failed to load selected image")
                return
            }

            let name = fileName.isEmpty ? "Photo_\(Date().timeIntervalSince1970)" : fileName
            await processImage(image, fileName: name)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let name = fileName.isEmpty ? url.lastPathComponent : fileName
            processFile(at: url, fileName: name)

        case .failure(let error):
            showError("Failed to import file: \(error.localizedDescription)")
        }
    }

    private func processImage(_ image: UIImage, fileName: String) async {
        isUploading = true
        uploadProgress = 0.1

        do {
            // Convert image to text using OCR (placeholder - you'd use actual OCR service)
            let extractedText = await extractTextFromImage(image)
            uploadProgress = 0.5

            // Create mortgage document
            let document = MortgageDocument(
                fileName: fileName,
                originalText: extractedText,
                documentType: documentType
            )

            uploadProgress = 0.8

            // Add to user store
            await MainActor.run {
                userStore.addDocument(document)
                uploadProgress = 1.0

                // Small delay to show completion
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }

        } catch {
            await MainActor.run {
                showError("Failed to process image: \(error.localizedDescription)")
                isUploading = false
            }
        }
    }

    private func processFile(at url: URL, fileName: String) {
        isUploading = true
        uploadProgress = 0.1

        Task {
            do {
                // Read file content
                let data = try Data(contentsOf: url)
                uploadProgress = 0.3

                // Extract text based on file type
                let extractedText: String
                if url.pathExtension.lowercased() == "pdf" {
                    extractedText = await extractTextFromPDF(data)
                } else {
                    // Assume it's an image
                    guard let image = UIImage(data: data) else {
                        throw DocumentError.unsupportedFormat
                    }
                    extractedText = await extractTextFromImage(image)
                }

                uploadProgress = 0.7

                // Create mortgage document
                let document = MortgageDocument(
                    fileName: fileName,
                    originalText: extractedText,
                    documentType: documentType
                )

                uploadProgress = 0.9

                // Add to user store
                await MainActor.run {
                    userStore.addDocument(document)
                    uploadProgress = 1.0

                    // Small delay to show completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }

            } catch {
                await MainActor.run {
                    showError("Failed to process file: \(error.localizedDescription)")
                    isUploading = false
                }
            }
        }
    }

    private func extractTextFromImage(_ image: UIImage) async -> String {
        // Placeholder for OCR implementation
        // In real implementation, you'd use Google Cloud Vision or Apple's Vision framework
        return """
        [Extracted text from image would appear here]

        MORTGAGE STATEMENT
        Account Number: 1234567890
        Payment Due Date: \(DateFormatter.mediumDateFormatter.string(from: Date()))
        Principal Balance: $250,000.00
        Monthly Payment: $1,847.32

        This is a sample extracted text for demonstration purposes.
        In a real implementation, this would contain the actual OCR results.
        """
    }

    private func extractTextFromPDF(_ data: Data) async -> String {
        // Placeholder for PDF text extraction
        // In real implementation, you'd use PDFKit or similar
        return """
        [Extracted text from PDF would appear here]

        ANNUAL ESCROW ANALYSIS
        Property Address: 123 Main St, Anytown, USA
        Escrow Account Number: ESC-9876543210
        Analysis Period: \(DateFormatter.mediumDateFormatter.string(from: Date()))

        This is a sample extracted text for demonstration purposes.
        In a real implementation, this would contain the actual PDF content.
        """
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
        isUploading = false
        uploadProgress = 0.0
    }
}

// MARK: - Supporting Views

struct UploadOptionCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct DocumentTypeCard: View {
    let type: MortgageDocument.DocumentType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)

                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Supporting Types

enum DocumentError: LocalizedError {
    case unsupportedFormat
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported file format"
        case .processingFailed:
            return "Failed to process document"
        }
    }
}

extension DateFormatter {
    static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

#Preview {
    DocumentPickerView()
        .environmentObject(UserStore())
}