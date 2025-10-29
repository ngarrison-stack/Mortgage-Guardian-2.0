import SwiftUI
import Foundation
import Combine
import os.log
import UIKit
import UniformTypeIdentifiers

// MARK: - Dark Mode Color Extensions
extension Color {
    static let adaptiveBackground = Color(UIColor.systemBackground)
    static let adaptiveSecondaryBackground = Color(UIColor.secondarySystemBackground)
    static let adaptiveTertiaryBackground = Color(UIColor.tertiarySystemBackground)
    static let adaptiveText = Color(UIColor.label)
    static let adaptiveSecondaryText = Color(UIColor.secondaryLabel)

    static let adaptiveWhite = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.white
    })

    static let adaptiveCardBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor.secondarySystemBackground : UIColor.systemBackground
    })
}


// MARK: - Logger Extension
extension Logger {
    init(subsystem: String, category: String) {
        self.init(OSLog(subsystem: subsystem, category: category))
    }
}


struct ContentView: View {
    @State private var selectedTab = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Dark mode compatible background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.05),
                    Color.adaptiveBackground
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Dashboard")
                }
                .tag(0)

            SimpleDocumentsView()
                .tabItem {
                    Image(systemName: "doc.text.fill")
                    Text("Documents")
                }
                .tag(1)

            AnalysisView()
                .tabItem {
                    Image(systemName: "magnifyingglass.circle.fill")
                    Text("Analysis")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
            }
        }
    }
}

struct DashboardView: View {
    @StateObject private var plaidService = PlaidLinkService.shared
    @State private var showingPlaidConnection = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            ZStack {
                // Dark mode compatible background with subtle pattern
                Color.clear
                    .background(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.adaptiveBackground,
                                Color.blue.opacity(0.05)
                            ]),
                            center: .topTrailing,
                            startRadius: 50,
                            endRadius: 400
                        )
                    )

                ScrollView {
                    VStack(spacing: 24) {
                        // Header with enhanced styling
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)

                                Image(systemName: "shield.checkered")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }

                            VStack(spacing: 8) {
                                Text("Mortgage Guardian")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )

                                Text("Protecting your mortgage interests")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 20)

                        // Quick Actions with enhanced styling
                        VStack(spacing: 20) {
                            HStack {
                                Text("Quick Actions")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                Spacer()
                            }

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 20) {
                                EnhancedQuickActionCard(
                                    icon: "doc.text.fill",
                                    title: "Upload Document",
                                    subtitle: "Add mortgage statement",
                                    color: .blue,
                                    accentColor: .cyan
                                )

                                EnhancedQuickActionCard(
                                    icon: "building.columns.fill",
                                    title: plaidService.accountCount == 0 ? "Connect Bank" : "Bank Connected",
                                    subtitle: plaidService.accountCount == 0 ? "Link your account" : "\(plaidService.accountCount) account(s)",
                                    color: .green,
                                    accentColor: .mint
                                ) {
                                    if plaidService.accountCount == 0 {
                                        showingPlaidConnection = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Getting Started with enhanced styling
                        if plaidService.accountCount == 0 {
                            VStack(spacing: 20) {
                                HStack {
                                    Text("Getting Started")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    Spacer()
                                }

                                EnhancedGettingStartedCard()
                            }
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 50)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingPlaidConnection) {
                RealPlaidConnectionView()
            }
        }
    }
}

// MARK: - Enhanced UI Components
struct EnhancedQuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let accentColor: Color
    let action: (() -> Void)?

    init(icon: String, title: String, subtitle: String, color: Color, accentColor: Color, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.accentColor = accentColor
        self.action = action
    }

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [color, accentColor]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.white)
                }

                VStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [color.opacity(0.3), accentColor.opacity(0.3)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EnhancedGettingStartedCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.cyan]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "hand.wave.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                Text("Welcome to Mortgage Guardian!")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()
            }

            VStack(alignment: .leading, spacing: 16) {
                StepRow(
                    number: "1",
                    text: "Connect your bank account for payment verification",
                    icon: "building.columns.fill",
                    color: .green
                )

                StepRow(
                    number: "2",
                    text: "Upload mortgage documents for analysis",
                    icon: "doc.text.fill",
                    color: .blue
                )

                StepRow(
                    number: "3",
                    text: "Review findings and generate dispute letters",
                    icon: "magnifyingglass.circle.fill",
                    color: .purple
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct StepRow: View {
    let number: String
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 32, height: 32)

                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 20)

                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: (() -> Void)?

    init(icon: String, title: String, subtitle: String, color: Color, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.action = action
    }

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Temporarily commented out - requires PlaidAccount
/*
struct AccountSummaryCard: View {
    let account: PlaidAccount

    var body: some View {
        HStack {
            Image(systemName: "building.columns.fill")
                .foregroundColor(.green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(account.institutionName) •••• \(account.mask)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Connected")
                    .font(.caption)
                    .foregroundColor(.green)

                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}
*/

struct GettingStartedCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to Mortgage Guardian!")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("1.")
                        .fontWeight(.bold)
                        .frame(width: 20)
                    Text("Connect your bank account for payment verification")
                }

                HStack {
                    Text("2.")
                        .fontWeight(.bold)
                        .frame(width: 20)
                    Text("Upload mortgage documents for analysis")
                }

                HStack {
                    Text("3.")
                        .fontWeight(.bold)
                        .frame(width: 20)
                    Text("Review findings and generate dispute letters")
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBlue).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue, lineWidth: 1)
                )
        )
    }
}

struct SimpleDocumentsView: View {
    @State private var showingDocumentPicker = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            ZStack {
                // Dark mode compatible background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.cyan.opacity(0.1),
                        Color.blue.opacity(0.05),
                        Color.adaptiveBackground
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 30) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.cyan]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 8)

                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 12) {
                        Text("Mortgage Documents")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.cyan]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("Upload your mortgage statements, escrow analyses, and other documents to detect potential servicing errors")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button {
                        showingDocumentPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                            Text("Upload Document")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.cyan]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 40)

                VStack(spacing: 16) {
                    Text("What we check for:")
                        .font(.headline)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 8) {
                        FeatureItem(icon: "dollarsign.circle", text: "Payment allocation errors")
                        FeatureItem(icon: "house.circle", text: "Escrow account discrepancies")
                        FeatureItem(icon: "percent", text: "Interest rate miscalculations")
                        FeatureItem(icon: "exclamationmark.triangle", text: "RESPA/TILA violations")
                        FeatureItem(icon: "banknote", text: "Unauthorized fees")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Documents")
            .sheet(isPresented: $showingDocumentPicker) {
                SimpleDocumentPicker()
            }
        }
    }
}

struct FeatureItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

struct SimpleDocumentPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingFileImporter = false
    @State private var showingSuccessAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
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

                VStack(spacing: 16) {
                    Button {
                        showingCamera = true
                    } label: {
                        UploadOption(
                            icon: "camera",
                            title: "Take Photo",
                            description: "Capture document with camera"
                        )
                    }

                    Button {
                        showingPhotoLibrary = true
                    } label: {
                        UploadOption(
                            icon: "photo",
                            title: "Photo Library",
                            description: "Select from your photos"
                        )
                    }

                    Button {
                        showingFileImporter = true
                    } label: {
                        UploadOption(
                            icon: "folder",
                            title: "Browse Files",
                            description: "Import PDF or image files"
                        )
                    }
                }

                Spacer()
            }
            .padding()
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
                CameraView { result in
                    handleDocumentCapture(result)
                }
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                PhotoLibraryView { result in
                    handleDocumentCapture(result)
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Document Uploaded", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your document has been successfully uploaded and will be analyzed.")
            }
        }
    }

    private func handleDocumentCapture(_ result: DocumentCaptureResult) {
        switch result {
        case .success(_):
            // In a real app, this would save the image and process it
            print("Document captured successfully")
            showingSuccessAlert = true
        case .cancelled:
            print("Document capture cancelled")
        case .failure(let error):
            print("Document capture failed: \(error.localizedDescription)")
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // In a real app, this would process the selected file
            print("File selected: \(url.lastPathComponent)")
            showingSuccessAlert = true
        case .failure(let error):
            print("File import failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Document Capture Support
enum DocumentCaptureResult {
    case success(UIImage)
    case cancelled
    case failure(Error)
}

struct CameraView: UIViewControllerRepresentable {
    let completion: (DocumentCaptureResult) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator

        // Check if camera is available
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.cameraDevice = .rear
        } else {
            // Camera not available, return error through delegate
            DispatchQueue.main.async {
                self.completion(.failure(CameraError.cameraNotAvailable))
            }
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (DocumentCaptureResult) -> Void

        init(completion: @escaping (DocumentCaptureResult) -> Void) {
            self.completion = completion
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                completion(.success(image))
            } else {
                completion(.failure(CameraError.imageNotFound))
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            completion(.cancelled)
            picker.dismiss(animated: true)
        }
    }

    enum CameraError: Error, LocalizedError {
        case imageNotFound
        case cameraNotAvailable

        var errorDescription: String? {
            switch self {
            case .imageNotFound:
                return "Could not capture image"
            case .cameraNotAvailable:
                return "Camera is not available on this device"
            }
        }
    }
}

struct PhotoLibraryView: UIViewControllerRepresentable {
    let completion: (DocumentCaptureResult) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator

        // Check if photo library is available
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            picker.sourceType = .photoLibrary
            picker.mediaTypes = ["public.image"]
        } else {
            // Photo library not available, return error through delegate
            DispatchQueue.main.async {
                self.completion(.failure(PhotoLibraryError.photoLibraryNotAvailable))
            }
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (DocumentCaptureResult) -> Void

        init(completion: @escaping (DocumentCaptureResult) -> Void) {
            self.completion = completion
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                completion(.success(image))
            } else {
                completion(.failure(PhotoLibraryError.imageNotFound))
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            completion(.cancelled)
            picker.dismiss(animated: true)
        }
    }

    enum PhotoLibraryError: Error, LocalizedError {
        case imageNotFound
        case photoLibraryNotAvailable

        var errorDescription: String? {
            switch self {
            case .imageNotFound:
                return "Could not load image from photo library"
            case .photoLibraryNotAvailable:
                return "Photo library is not available on this device"
            }
        }
    }
}

struct UploadOption: View {
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

struct AnalysisView: View {
    @State private var analysisResults: [SimpleAuditResult] = []
    @State private var isLoading = false
    @State private var selectedSeverity: SimpleAuditResult.Severity? = nil

    var filteredResults: [SimpleAuditResult] {
        guard let selectedSeverity = selectedSeverity else {
            return analysisResults
        }
        return analysisResults.filter { $0.severity == selectedSeverity }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if analysisResults.isEmpty && !isLoading {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        VStack(spacing: 8) {
                            Text("No Analysis Results")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Upload mortgage documents to see AI-powered analysis and error detection")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        Button("Load Sample Analysis") {
                            loadSampleAnalysis()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Analysis results
                    VStack(spacing: 16) {
                        // Summary cards
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                SeverityCard(
                                    severity: .critical,
                                    count: analysisResults.filter { $0.severity == .critical }.count,
                                    isSelected: selectedSeverity == .critical
                                ) {
                                    selectedSeverity = selectedSeverity == .critical ? nil : .critical
                                }

                                SeverityCard(
                                    severity: .high,
                                    count: analysisResults.filter { $0.severity == .high }.count,
                                    isSelected: selectedSeverity == .high
                                ) {
                                    selectedSeverity = selectedSeverity == .high ? nil : .high
                                }

                                SeverityCard(
                                    severity: .medium,
                                    count: analysisResults.filter { $0.severity == .medium }.count,
                                    isSelected: selectedSeverity == .medium
                                ) {
                                    selectedSeverity = selectedSeverity == .medium ? nil : .medium
                                }

                                SeverityCard(
                                    severity: .low,
                                    count: analysisResults.filter { $0.severity == .low }.count,
                                    isSelected: selectedSeverity == .low
                                ) {
                                    selectedSeverity = selectedSeverity == .low ? nil : .low
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Results list
                        List(filteredResults) { result in
                            AnalysisResultRow(result: result)
                        }
                        .listStyle(PlainListStyle())
                    }
                }

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Analyzing documents...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Analysis")
            .toolbar {
                if !analysisResults.isEmpty {
                    Button("Clear") {
                        analysisResults.removeAll()
                        selectedSeverity = nil
                    }
                }
            }
        }
    }

    private func loadSampleAnalysis() {
        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            analysisResults = SimpleAuditResult.sampleResults
            isLoading = false
        }
    }
}

// MARK: - Simple Models for Analysis
struct SimpleAuditResult: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let severity: Severity
    let category: String
    let amount: Double?
    let dateFound: Date

    enum Severity: String, CaseIterable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var color: Color {
            switch self {
            case .critical: return .red
            case .high: return .orange
            case .medium: return .yellow
            case .low: return .blue
            }
        }

        var icon: String {
            switch self {
            case .critical: return "exclamationmark.triangle.fill"
            case .high: return "exclamationmark.circle.fill"
            case .medium: return "exclamationmark.circle"
            case .low: return "info.circle"
            }
        }
    }

    static let sampleResults: [SimpleAuditResult] = [
        SimpleAuditResult(
            title: "Payment Allocation Error",
            description: "Principal payment was incorrectly allocated to interest on March 2024 statement",
            severity: .critical,
            category: "Payment Processing",
            amount: 450.32,
            dateFound: Date().addingTimeInterval(-86400 * 5)
        ),
        SimpleAuditResult(
            title: "Escrow Analysis Discrepancy",
            description: "Property tax increase not properly reflected in escrow calculations",
            severity: .high,
            category: "Escrow Management",
            amount: 1200.00,
            dateFound: Date().addingTimeInterval(-86400 * 12)
        ),
        SimpleAuditResult(
            title: "Late Fee Overcharge",
            description: "Late fee charged despite payment received within grace period",
            severity: .medium,
            category: "Fee Assessment",
            amount: 75.00,
            dateFound: Date().addingTimeInterval(-86400 * 8)
        ),
        SimpleAuditResult(
            title: "RESPA Notice Timing",
            description: "Escrow analysis notice sent 25 days before effective date instead of required 30 days",
            severity: .medium,
            category: "RESPA Compliance",
            amount: nil,
            dateFound: Date().addingTimeInterval(-86400 * 15)
        ),
        SimpleAuditResult(
            title: "Interest Rate Documentation",
            description: "ARM adjustment notice references incorrect index value",
            severity: .low,
            category: "Documentation",
            amount: nil,
            dateFound: Date().addingTimeInterval(-86400 * 3)
        )
    ]
}

struct SeverityCard: View {
    let severity: SimpleAuditResult.Severity
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: severity.icon)
                    .font(.title2)
                    .foregroundColor(severity.color)

                Text("\(count)")
                    .font(.title3)
                    .fontWeight(.bold)

                Text(severity.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? severity.color.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? severity.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AnalysisResultRow: View {
    let result: SimpleAuditResult

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: result.severity.icon)
                .font(.title3)
                .foregroundColor(result.severity.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(result.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text(result.category)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)

                    if let amount = result.amount {
                        Text("$\(amount, specifier: "%.2f")")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(result.severity.color)
                    }

                    Spacer()

                    Text(RelativeDateTimeFormatter().localizedString(for: result.dateFound, relativeTo: Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct SettingsView: View {
    @State private var showingBankAccounts = false
    @State private var showingStorageSettings = false
    @StateObject private var plaidService = PlaidLinkService.shared

    var body: some View {
        NavigationView {
            List {
                Section("Bank Connections") {
                    HStack {
                        Image(systemName: "building.columns.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bank Accounts")
                            Text("\(plaidService.accountCount) connected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("Coming Soon")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                Section("Data & Privacy") {
                    NavigationLink {
                        StorageConsentView()
                    } label: {
                        HStack {
                            Image(systemName: "cloud.fill")
                                .foregroundColor(.blue)
                            Text("Cloud Storage")
                        }
                    }

                    NavigationLink {
                        APISettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.gray)
                            Text("API Configuration")
                        }
                    }
                }

                Section("Support") {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.blue)
                        Text("Help & Support")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.blue)
                        Text("Contact Us")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("App Information") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.gray)
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                        Text("Terms of Service")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Missing Views (Placeholders)
struct SimplePlaidConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var plaidService = PlaidLinkService.shared
    @State private var isConnecting = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Connect Your Bank")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Demo version - connecting a mock account")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    connectToBank()
                } label: {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Connecting...")
                        } else {
                            Image(systemName: "plus.circle.fill")
                            Text("Connect Demo Bank Account")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .disabled(isConnecting)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Bank Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func connectToBank() {
        isConnecting = true

        Task {
            do {
                try await plaidService.startLinkFlow()
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                }
            }
        }
    }
}

struct StorageConsentView: View {
    var body: some View {
        VStack {
            Text("Cloud Storage Settings")
                .font(.title)
            Text("Configure your cloud storage preferences here.")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
        .navigationTitle("Cloud Storage")
    }
}

struct APISettingsView: View {
    var body: some View {
        VStack {
            Text("API Configuration")
                .font(.title)
            Text("Configure API settings here.")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
        .navigationTitle("API Settings")
    }
}

#Preview {
    ContentView()
}