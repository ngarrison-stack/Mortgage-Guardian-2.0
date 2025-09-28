import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Main document capture interface with multiple input methods
struct DocumentCaptureView: View {

    // MARK: - Properties

    @StateObject private var viewModel: DocumentCaptureViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Initialization

    init(documentProcessor: DocumentProcessor, securityService: SecurityService, userStore: UserStore, permissionsManager: PermissionsManager = .shared) {
        self._viewModel = StateObject(wrappedValue: DocumentCaptureViewModel(
            documentProcessor: documentProcessor,
            securityService: securityService,
            userStore: userStore,
            permissionsManager: permissionsManager
        ))
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundColor
                    .ignoresSafeArea()

                // Main content
                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Content based on state
                    contentView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $viewModel.showingCamera) {
                cameraSheet
            }
            .sheet(isPresented: $viewModel.showingPhotoLibrary) {
                photoLibrarySheet
            }
            .fileImporter(
                isPresented: $viewModel.showingFilePicker,
                allowedContentTypes: [.pdf, .jpeg, .png, .heic],
                allowsMultipleSelection: true
            ) { result in
                Task {
                    await viewModel.handleFileImport(result)
                }
            }
            .sheet(isPresented: $viewModel.showingDocumentPreview) {
                if let document = viewModel.selectedDocument {
                    DocumentPreviewView(
                        document: document,
                        viewModel: viewModel
                    )
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.dismissError()
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Views

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(.systemGroupedBackground)
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.primary)
                .accessibilityLabel("Cancel document capture")
                .accessibilityHint("Closes the document capture interface")

                Spacer()

                Text("Capture Document")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if !viewModel.capturedDocuments.isEmpty {
                    Button("Clear") {
                        viewModel.clearCapturedDocuments()
                    }
                    .foregroundColor(.red)
                    .accessibilityLabel("Clear all captured documents")
                    .accessibilityHint("Removes all documents from the current capture session")
                } else {
                    Button("Clear") {
                        // Placeholder for spacing
                    }
                    .hidden()
                    .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // Progress indicator
            if viewModel.processingState != .idle {
                progressIndicatorView
                    .transition(.opacity)
            }
        }
        .background(
            Rectangle()
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
    }

    private var contentView: some View {
        Group {
            switch viewModel.processingState {
            case .idle:
                if viewModel.capturedDocuments.isEmpty {
                    captureOptionsView
                } else {
                    capturedDocumentsView
                }

            case .capturing, .importing, .processing, .enhancing:
                processingView

            case .completed:
                if viewModel.capturedDocuments.isEmpty {
                    captureOptionsView
                } else {
                    capturedDocumentsView
                }

            case .failed(let error):
                errorView(error)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.processingState)
    }

    private var captureOptionsView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Instructions
                instructionsCard

                // Capture methods
                VStack(spacing: 16) {
                    cameraButton
                    photoLibraryButton
                    fileImportButton
                }
                .padding(.horizontal, 20)

                // Configuration options
                configurationSection

                Spacer(minLength: 50)
            }
            .padding(.top, 20)
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.viewfinder")
                    .foregroundColor(.blue)
                    .font(.title2)

                Text("Document Capture Tips")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                instructionItem(icon: "lightbulb", text: "Ensure good lighting for best results")
                instructionItem(icon: "rectangle.dashed", text: "Position document within the frame")
                instructionItem(icon: "doc.plaintext", text: "Keep text clear and readable")
                instructionItem(icon: "hand.raised", text: "Hold device steady during capture")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
    }

    private func instructionItem(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.body)
                .frame(width: 20)

            Text(text)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }

    private var cameraButton: some View {
        Button {
            Task {
                await viewModel.startCameraCapture()
            }
        } label: {
            captureMethodCard(
                icon: "camera.fill",
                title: "Camera",
                subtitle: "Capture with device camera",
                color: .blue
            )
        }
        .disabled(viewModel.processingState != .idle && viewModel.processingState != .completed)
        .accessibilityLabel("Camera capture")
        .accessibilityHint("Opens camera to capture document photos")
    }

    private var photoLibraryButton: some View {
        Button {
            Task {
                await viewModel.startPhotoLibraryImport()
            }
        } label: {
            captureMethodCard(
                icon: "photo.on.rectangle",
                title: "Photo Library",
                subtitle: "Select from photos",
                color: .green
            )
        }
        .disabled(viewModel.processingState != .idle && viewModel.processingState != .completed)
        .accessibilityLabel("Photo library import")
        .accessibilityHint("Opens photo library to select document images")
    }

    private var fileImportButton: some View {
        Button {
            viewModel.startFileImport()
        } label: {
            captureMethodCard(
                icon: "folder",
                title: "Files",
                subtitle: "Import PDF or images",
                color: .orange
            )
        }
        .disabled(viewModel.processingState != .idle && viewModel.processingState != .completed)
        .accessibilityLabel("File import")
        .accessibilityHint("Opens file browser to import PDF documents and images")
    }

    private func captureMethodCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.body)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                configurationToggle(
                    title: "Auto Enhance",
                    subtitle: "Automatically improve image quality",
                    isOn: $viewModel.autoEnhanceEnabled
                )

                configurationToggle(
                    title: "OCR Processing",
                    subtitle: "Extract text from documents",
                    isOn: $viewModel.ocrEnabled
                )

                configurationToggle(
                    title: "Auto Document Type",
                    subtitle: "Automatically detect document type",
                    isOn: $viewModel.autoDocumentTypeDetection
                )

                configurationToggle(
                    title: "Batch Processing",
                    subtitle: "Process multiple documents at once",
                    isOn: $viewModel.batchProcessingEnabled
                )
            }
            .padding(.horizontal, 20)
        }
    }

    private func configurationToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .accessibilityLabel(title)
                .accessibilityHint(subtitle)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var capturedDocumentsView: some View {
        VStack(spacing: 0) {
            // Documents list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.capturedDocuments, id: \.id) { document in
                        capturedDocumentRow(document)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }

            // Action buttons
            actionButtonsView
        }
    }

    private func capturedDocumentRow(_ document: DocumentCaptureViewModel.CapturedDocument) -> some View {
        Button {
            viewModel.selectedDocument = document
            viewModel.showingDocumentPreview = true
        } label: {
            HStack(spacing: 16) {
                // Thumbnail
                AsyncImage(url: nil) { _ in
                    Image(uiImage: document.originalImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 80)
                        .clipped()
                        .cornerRadius(8)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 80)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                        )
                }

                // Document info
                VStack(alignment: .leading, spacing: 6) {
                    Text(document.displayName)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(document.documentType.displayName)
                        .font(.body)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: document.documentType.icon)
                            .foregroundColor(.blue)
                            .font(.caption)

                        Text(DateFormatter.relative.string(from: document.captureDate))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(document.captureMode == .camera ? "Camera" : "Import")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                Spacer()

                // Actions
                VStack(spacing: 8) {
                    Button {
                        viewModel.selectedDocument = document
                        viewModel.showingDocumentPreview = true
                    } label: {
                        Image(systemName: "eye")
                            .font(.body)
                            .foregroundColor(.blue)
                    }

                    Button {
                        viewModel.removeDocument(document)
                    } label: {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            if viewModel.capturedDocuments.count > 1 && viewModel.batchProcessingEnabled {
                Button {
                    Task {
                        await viewModel.processBatchDocuments()
                    }
                } label: {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Process All Documents")
                    }
                    .foregroundColor(.white)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(viewModel.processingState == .processing)
            } else if let selectedDocument = viewModel.selectedDocument {
                Button {
                    Task {
                        await viewModel.processSelectedDocument()
                    }
                } label: {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Process Document")
                    }
                    .foregroundColor(.white)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(viewModel.processingState == .processing)
            }

            HStack(spacing: 12) {
                Button("Add More") {
                    // Reset to capture options
                    viewModel.selectedDocument = nil
                }
                .foregroundColor(.blue)
                .font(.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.white)
                .font(.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(backgroundColor)
    }

    private var processingView: some View {
        VStack(spacing: 30) {
            Spacer()

            // Processing indicator
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle())

                Text(viewModel.processingMessage)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                if viewModel.processingProgress > 0 {
                    ProgressView(value: viewModel.processingProgress)
                        .frame(width: 200)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var progressIndicatorView: some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.processingProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 4)

            Text(viewModel.processingMessage)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Processing Failed")
                .font(.title2)
                .fontWeight(.semibold)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Try Again") {
                viewModel.dismissError()
            }
            .foregroundColor(.white)
            .font(.headline)
            .frame(width: 200)
            .padding(.vertical, 16)
            .background(Color.blue)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sheets

    private var cameraSheet: some View {
        CameraView(
            configuration: .default,
            onImageCaptured: { image in
                Task {
                    await viewModel.handleCameraCapture(image)
                }
                viewModel.showingCamera = false
            },
            onImagesCaptured: { images in
                Task {
                    for image in images {
                        await viewModel.handleCameraCapture(image)
                    }
                }
                viewModel.showingCamera = false
            },
            onError: { error in
                viewModel.errorMessage = error.localizedDescription
                viewModel.showingCamera = false
            },
            onCancel: {
                viewModel.showingCamera = false
            }
        )
    }

    private var photoLibrarySheet: some View {
        NavigationView {
            PhotosPicker(
                selection: $viewModel.photoPickerItems,
                maxSelectionCount: 10,
                matching: .images
            ) {
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Select Photos")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Choose document photos from your library")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundColor)
            }
            .navigationTitle("Photo Library")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.showingPhotoLibrary = false
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let relative: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
}

// MARK: - Preview

struct DocumentCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentCaptureView(
            documentProcessor: DocumentProcessor(securityService: SecurityService.shared),
            securityService: SecurityService.shared,
            userStore: UserStore()
        )
        .preferredColorScheme(.light)

        DocumentCaptureView(
            documentProcessor: DocumentProcessor(securityService: SecurityService.shared),
            securityService: SecurityService.shared,
            userStore: UserStore()
        )
        .preferredColorScheme(.dark)
    }
}