import SwiftUI
import UIKit

/// Preview and editing interface for captured documents
struct DocumentPreviewView: View {

    // MARK: - Properties

    let document: DocumentCaptureViewModel.CapturedDocument
    @ObservedObject var viewModel: DocumentCaptureViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedImage: UIImage
    @State private var showingImageEditor = false
    @State private var customDocumentName = ""
    @State private var selectedDocumentType: MortgageDocument.DocumentType
    @State private var showingNameEditor = false
    @State private var showingTypeSelector = false
    @State private var rotationAngle: Double = 0
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero

    // MARK: - Initialization

    init(document: DocumentCaptureViewModel.CapturedDocument, viewModel: DocumentCaptureViewModel) {
        self.document = document
        self.viewModel = viewModel
        self._selectedImage = State(initialValue: document.enhancedImage ?? document.originalImage)
        self._selectedDocumentType = State(initialValue: document.documentType)
        self._customDocumentName = State(initialValue: document.customName ?? "")
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Image preview
                    imagePreviewView(geometry: geometry)

                    // Controls
                    controlsView
                }
            }
            .background(backgroundColor)
            .navigationBarHidden(true)
            .sheet(isPresented: $showingImageEditor) {
                DocumentImageEditor(
                    image: selectedImage,
                    onImageEdited: { editedImage in
                        selectedImage = editedImage
                    }
                )
            }
            .sheet(isPresented: $showingNameEditor) {
                documentNameEditor
            }
            .actionSheet(isPresented: $showingTypeSelector) {
                documentTypeSelector
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
                .accessibilityLabel("Cancel document preview")
                .accessibilityHint("Discards changes and returns to document capture")

                Spacer()

                Text("Document Preview")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button("Done") {
                    saveChanges()
                    dismiss()
                }
                .foregroundColor(.blue)
                .fontWeight(.medium)
                .accessibilityLabel("Done with preview")
                .accessibilityHint("Saves changes and returns to document capture")
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // Document info
            VStack(spacing: 8) {
                HStack {
                    Text(document.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    Button {
                        showingNameEditor = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: selectedDocumentType.icon)
                            .foregroundColor(.blue)
                            .font(.caption)

                        Text(selectedDocumentType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        showingTypeSelector = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Change")
                                .font(.caption)
                                .foregroundColor(.blue)

                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .background(
            Rectangle()
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
    }

    private func imagePreviewView(geometry: GeometryProxy) -> some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color.black)

            // Image
            Image(uiImage: selectedImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(imageScale)
                .rotationEffect(.degrees(rotationAngle))
                .offset(imageOffset)
                .clipped()
                .accessibilityLabel("Document preview image")
                .accessibilityHint("Document image with zoom and rotation controls. Use pinch gesture to zoom, drag to pan.")
                .accessibilityAddTraits(.isImage)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                imageScale = max(0.5, min(3.0, value))
                            },
                        DragGesture()
                            .onChanged { value in
                                imageOffset = value.translation
                            }
                            .onEnded { _ in
                                withAnimation(.spring()) {
                                    imageOffset = .zero
                                }
                            }
                    )
                )

            // Image quality indicator
            VStack {
                HStack {
                    Spacer()

                    qualityIndicator
                        .padding(12)
                }

                Spacer()
            }

            // Zoom controls overlay
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    zoomControls
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var qualityIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(qualityColor)
                .frame(width: 8, height: 8)

            Text(qualityText)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
        )
    }

    private var qualityColor: Color {
        // Simple quality assessment based on image size and clarity
        let imageSize = selectedImage.size.width * selectedImage.size.height
        if imageSize > 1000000 { // > 1MP
            return .green
        } else if imageSize > 500000 { // > 0.5MP
            return .orange
        } else {
            return .red
        }
    }

    private var qualityText: String {
        let imageSize = selectedImage.size.width * selectedImage.size.height
        if imageSize > 1000000 {
            return "High Quality"
        } else if imageSize > 500000 {
            return "Medium Quality"
        } else {
            return "Low Quality"
        }
    }

    private var zoomControls: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    imageScale = min(3.0, imageScale + 0.5)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    imageScale = max(0.5, imageScale - 0.5)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    imageScale = 1.0
                    imageOffset = .zero
                    rotationAngle = 0
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }
        }
    }

    private var controlsView: some View {
        VStack(spacing: 16) {
            // Enhancement options
            enhancementSection

            // Editing tools
            editingToolsSection

            // Action buttons
            actionButtonsSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(backgroundColor)
    }

    private var enhancementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Image Quality")
                .font(.headline)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                enhancementButton(
                    title: "Original",
                    isSelected: selectedImage == document.originalImage
                ) {
                    selectedImage = document.originalImage
                }

                if let enhancedImage = document.enhancedImage {
                    enhancementButton(
                        title: "Enhanced",
                        isSelected: selectedImage == enhancedImage
                    ) {
                        selectedImage = enhancedImage
                    }
                }

                enhancementButton(
                    title: "Auto Fix",
                    isSelected: false
                ) {
                    applyAutoEnhancement()
                }
            }
        }
    }

    private func enhancementButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                )
        }
    }

    private var editingToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Editing Tools")
                .font(.headline)
                .fontWeight(.medium)

            HStack(spacing: 16) {
                editingToolButton(
                    icon: "rotate.right",
                    title: "Rotate"
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        rotationAngle += 90
                    }
                }

                editingToolButton(
                    icon: "crop",
                    title: "Crop"
                ) {
                    showingImageEditor = true
                }

                editingToolButton(
                    icon: "slider.horizontal.3",
                    title: "Adjust"
                ) {
                    showingImageEditor = true
                }

                editingToolButton(
                    icon: "wand.and.rays",
                    title: "Filters"
                ) {
                    showingImageEditor = true
                }
            }
        }
    }

    private func editingToolButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Process button
            Button {
                Task {
                    // Update the document with current changes before processing
                    saveChanges()
                    await viewModel.processSelectedDocument()
                    dismiss()
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

            // Secondary actions
            HStack(spacing: 12) {
                Button("Share") {
                    shareDocument()
                }
                .foregroundColor(.blue)
                .font(.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

                Button("Save to Photos") {
                    saveToPhotos()
                }
                .foregroundColor(.green)
                .font(.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Sheets and Action Sheets

    private var documentNameEditor: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Document Name")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                TextField("Enter document name", text: $customDocumentName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 20)

                Text("Examples: \"Mortgage Statement Jan 2025\", \"Property Tax Bill\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)

                Spacer()
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingNameEditor = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        showingNameEditor = false
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }

    private var documentTypeSelector: ActionSheet {
        ActionSheet(
            title: Text("Document Type"),
            message: Text("Select the type of document"),
            buttons: MortgageDocument.DocumentType.allCases.map { type in
                .default(Text(type.displayName)) {
                    selectedDocumentType = type
                }
            } + [.cancel()]
        )
    }

    // MARK: - Methods

    private func saveChanges() {
        // Update document name if changed
        if !customDocumentName.isEmpty && customDocumentName != document.customName {
            viewModel.updateDocumentName(document, name: customDocumentName)
        }

        // Update document type if changed
        if selectedDocumentType != document.documentType {
            viewModel.updateDocumentType(document, type: selectedDocumentType)
        }
    }

    private func applyAutoEnhancement() {
        Task {
            if let enhancedImage = await enhanceImage(selectedImage) {
                await MainActor.run {
                    selectedImage = enhancedImage
                }
            }
        }
    }

    private func enhanceImage(_ image: UIImage) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let cgImage = image.cgImage else {
                    continuation.resume(returning: nil)
                    return
                }

                let context = CIContext()
                let ciImage = CIImage(cgImage: cgImage)
                var enhancedImage = ciImage

                // Auto-enhance filters
                if let autoAdjustmentFilters = ciImage.autoAdjustmentFilters() {
                    for filter in autoAdjustmentFilters {
                        filter.setValue(enhancedImage, forKey: kCIInputImageKey)
                        if let output = filter.outputImage {
                            enhancedImage = output
                        }
                    }
                }

                // Additional sharpening for documents
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

    private func shareDocument() {
        let activityViewController = UIActivityViewController(
            activityItems: [selectedImage],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }

    private func saveToPhotos() {
        UIImageWriteToSavedPhotosAlbum(selectedImage, nil, nil, nil)
    }
}

// MARK: - Document Image Editor

struct DocumentImageEditor: View {
    let image: UIImage
    let onImageEdited: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var brightness: Double = 0
    @State private var contrast: Double = 1
    @State private var saturation: Double = 1
    @State private var sharpness: Double = 0

    var body: some View {
        NavigationView {
            VStack {
                // Image preview
                Image(uiImage: processedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)

                // Controls
                VStack(spacing: 20) {
                    adjustmentSlider(title: "Brightness", value: $brightness, range: -0.5...0.5)
                    adjustmentSlider(title: "Contrast", value: $contrast, range: 0.5...2.0)
                    adjustmentSlider(title: "Saturation", value: $saturation, range: 0...2.0)
                    adjustmentSlider(title: "Sharpness", value: $sharpness, range: 0...2.0)
                }
                .padding()

                Spacer()
            }
            .navigationTitle("Edit Image")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onImageEdited(processedImage)
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }

    private func adjustmentSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)

                Spacer()

                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Slider(value: value, in: range)
        }
    }

    private var processedImage: UIImage {
        guard let cgImage = image.cgImage else { return image }

        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        var processedImage = ciImage

        // Apply adjustments
        if let colorControls = CIFilter(name: "CIColorControls") {
            colorControls.setValue(processedImage, forKey: kCIInputImageKey)
            colorControls.setValue(brightness, forKey: kCIInputBrightnessKey)
            colorControls.setValue(contrast, forKey: kCIInputContrastKey)
            colorControls.setValue(saturation, forKey: kCIInputSaturationKey)
            if let output = colorControls.outputImage {
                processedImage = output
            }
        }

        // Apply sharpening
        if sharpness > 0, let sharpenFilter = CIFilter(name: "CIUnsharpMask") {
            sharpenFilter.setValue(processedImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(sharpness, forKey: kCIInputIntensityKey)
            sharpenFilter.setValue(2.5, forKey: kCIInputRadiusKey)
            if let output = sharpenFilter.outputImage {
                processedImage = output
            }
        }

        if let finalCGImage = context.createCGImage(processedImage, from: processedImage.extent) {
            return UIImage(cgImage: finalCGImage)
        }

        return image
    }
}

// MARK: - Preview

struct DocumentPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleImage = UIImage(systemName: "doc.text") ?? UIImage()
        let sampleDocument = DocumentCaptureViewModel.CapturedDocument(
            originalImage: sampleImage,
            enhancedImage: nil,
            fileName: "sample_document.jpg",
            captureDate: Date(),
            captureMode: .camera,
            documentType: .mortgageStatement,
            customName: "January Mortgage Statement"
        )

        DocumentPreviewView(
            document: sampleDocument,
            viewModel: DocumentCaptureViewModel(
                documentProcessor: DocumentProcessor(securityService: SecurityService.shared),
                securityService: SecurityService.shared,
                userStore: UserStore()
            )
        )
    }
}