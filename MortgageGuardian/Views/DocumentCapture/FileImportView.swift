import SwiftUI
import UniformTypeIdentifiers

/// Dedicated view for importing files with drag & drop support and file validation
struct FileImportView: View {

    // MARK: - Properties

    @ObservedObject var viewModel: DocumentCaptureViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var draggedOver = false
    @State private var showingFileImporter = false
    @State private var importProgress: Double = 0.0
    @State private var isImporting = false

    private let supportedTypes: [UTType] = [.pdf, .jpeg, .png, .heic]
    private let maxFileSize = 50 * 1024 * 1024 // 50MB

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView

                // Main content
                ZStack {
                    backgroundColor
                        .ignoresSafeArea()

                    if isImporting {
                        importingView
                    } else {
                        mainContentView
                    }
                }
            }
            .navigationBarHidden(true)
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: supportedTypes,
                allowsMultipleSelection: true
            ) { result in
                Task {
                    await handleFileImport(result)
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
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.primary)

            Spacer()

            Text("Import Files")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            Button("Browse") {
                showingFileImporter = true
            }
            .foregroundColor(.blue)
            .fontWeight(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
    }

    private var mainContentView: some View {
        VStack(spacing: 30) {
            Spacer()

            // Drag and drop area
            dragAndDropArea

            // Alternative import methods
            importMethodsSection

            // Supported formats info
            supportedFormatsSection

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var dragAndDropArea: some View {
        VStack(spacing: 20) {
            // Drop zone
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    draggedOver ? Color.blue : Color.gray.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [10, 5])
                )
                .frame(height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(draggedOver ? Color.blue.opacity(0.1) : Color.clear)
                )
                .overlay(
                    VStack(spacing: 16) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(draggedOver ? .blue : .gray)

                        Text(draggedOver ? "Drop files here" : "Drag & Drop Files")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(draggedOver ? .blue : .primary)

                        Text("Or tap to browse")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                )
                .onTapGesture {
                    showingFileImporter = true
                }
                .onDrop(of: supportedTypes, delegate: FileDropDelegate(
                    viewModel: viewModel,
                    onDragEntered: { draggedOver = true },
                    onDragExited: { draggedOver = false },
                    onFilesDropped: { files in
                        draggedOver = false
                        Task {
                            isImporting = true
                            await handleDroppedFiles(files)
                            isImporting = false
                        }
                    }
                ))

            // Quick instructions
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)

                Text("Supports PDF, JPEG, PNG, and HEIC files up to 50MB")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var importMethodsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Methods")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                importMethodRow(
                    icon: "folder",
                    title: "Files App",
                    subtitle: "Browse and select files",
                    color: .blue
                ) {
                    showingFileImporter = true
                }

                importMethodRow(
                    icon: "icloud.and.arrow.down",
                    title: "iCloud Drive",
                    subtitle: "Access cloud documents",
                    color: .cyan
                ) {
                    showingFileImporter = true
                }

                importMethodRow(
                    icon: "externaldrive",
                    title: "External Drive",
                    subtitle: "Import from USB or external storage",
                    color: .orange
                ) {
                    showingFileImporter = true
                }
            }
        }
    }

    private func importMethodRow(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.body)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var supportedFormatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supported Formats")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                formatCard(icon: "doc.richtext", title: "PDF", subtitle: "Documents")
                formatCard(icon: "photo", title: "JPEG", subtitle: "Images")
                formatCard(icon: "photo.stack", title: "PNG", subtitle: "Images")
                formatCard(icon: "camera", title: "HEIC", subtitle: "iPhone Photos")
            }
        }
    }

    private func formatCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)

            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }

    private var importingView: some View {
        VStack(spacing: 30) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Importing Files...")
                .font(.headline)
                .fontWeight(.medium)

            if importProgress > 0 {
                ProgressView(value: importProgress)
                    .frame(width: 200)
            }

            Text("Processing and validating files")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Methods

    private func handleFileImport(_ result: Result<[URL], Error>) async {
        isImporting = true

        switch result {
        case .success(let urls):
            await processImportedFiles(urls)
        case .failure(let error):
            await MainActor.run {
                viewModel.errorMessage = "File import failed: \(error.localizedDescription)"
            }
        }

        isImporting = false
    }

    private func handleDroppedFiles(_ providers: [NSItemProvider]) async {
        await viewModel.handleDroppedFiles(providers)
    }

    private func processImportedFiles(_ urls: [URL]) async {
        let totalFiles = urls.count

        for (index, url) in urls.enumerated() {
            await MainActor.run {
                importProgress = Double(index) / Double(totalFiles)
            }

            do {
                try await processFile(url)
            } catch {
                await MainActor.run {
                    viewModel.errorMessage = "Failed to process \(url.lastPathComponent): \(error.localizedDescription)"
                }
            }
        }

        await MainActor.run {
            importProgress = 1.0
        }

        // Dismiss after successful import
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }

    private func processFile(_ url: URL) async throws {
        // Validate file
        try validateFile(url)

        // Security scoped access
        guard url.startAccessingSecurityScopedResource() else {
            throw FileImportError.securityAccessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Process based on file type
        let fileExtension = url.pathExtension.lowercased()
        if fileExtension == "pdf" {
            try await processPDFFile(url)
        } else {
            try await processImageFile(url)
        }
    }

    private func validateFile(_ url: URL) throws {
        // Check file existence
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileImportError.fileNotFound
        }

        // Check file size
        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard fileSize <= maxFileSize else {
            throw FileImportError.fileTooLarge
        }

        // Check file type
        let fileExtension = url.pathExtension.lowercased()
        let supportedExtensions = ["pdf", "jpg", "jpeg", "png", "heic"]
        guard supportedExtensions.contains(fileExtension) else {
            throw FileImportError.unsupportedFormat
        }
    }

    private func processPDFFile(_ url: URL) async throws {
        let fileName = url.lastPathComponent
        await MainActor.run {
            // Create a captured document for the PDF
            // In a real implementation, you might want to show PDF preview first
            let pdfData = try? Data(contentsOf: url)
            let thumbnail = createPDFThumbnail(from: pdfData ?? Data())

            let capturedDoc = DocumentCaptureViewModel.CapturedDocument(
                originalImage: thumbnail ?? UIImage(),
                enhancedImage: nil,
                fileName: fileName,
                captureDate: Date(),
                captureMode: .fileImport
            )

            viewModel.capturedDocuments.append(capturedDoc)
        }
    }

    private func processImageFile(_ url: URL) async throws {
        let imageData = try Data(contentsOf: url)
        guard let image = UIImage(data: imageData) else {
            throw FileImportError.invalidImageData
        }

        let fileName = url.lastPathComponent

        await MainActor.run {
            let capturedDoc = DocumentCaptureViewModel.CapturedDocument(
                originalImage: image,
                enhancedImage: nil,
                fileName: fileName,
                captureDate: Date(),
                captureMode: .fileImport
            )

            viewModel.capturedDocuments.append(capturedDoc)
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
}

// MARK: - File Drop Delegate

struct FileDropDelegate: DropDelegate {
    let viewModel: DocumentCaptureViewModel
    let onDragEntered: () -> Void
    let onDragExited: () -> Void
    let onFilesDropped: ([NSItemProvider]) -> Void

    func dropEntered(info: DropInfo) {
        onDragEntered()
    }

    func dropExited(info: DropInfo) {
        onDragExited()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .copy)
    }

    func performDrop(info: DropInfo) -> Bool {
        onFilesDropped(info.itemProviders(for: [.pdf, .jpeg, .png, .heic]))
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.pdf, .jpeg, .png, .heic])
    }
}

// MARK: - Errors

enum FileImportError: LocalizedError {
    case fileNotFound
    case fileTooLarge
    case unsupportedFormat
    case securityAccessDenied
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .fileTooLarge:
            return "File size exceeds 50MB limit"
        case .unsupportedFormat:
            return "Unsupported file format"
        case .securityAccessDenied:
            return "Security access denied"
        case .invalidImageData:
            return "Invalid image data"
        }
    }
}

// MARK: - Preview

struct FileImportView_Previews: PreviewProvider {
    static var previews: some View {
        FileImportView(
            viewModel: DocumentCaptureViewModel(
                documentProcessor: DocumentProcessor(securityService: SecurityService.shared),
                securityService: SecurityService.shared,
                userStore: UserStore()
            )
        )
        .preferredColorScheme(.light)

        FileImportView(
            viewModel: DocumentCaptureViewModel(
                documentProcessor: DocumentProcessor(securityService: SecurityService.shared),
                securityService: SecurityService.shared,
                userStore: UserStore()
            )
        )
        .preferredColorScheme(.dark)
    }
}