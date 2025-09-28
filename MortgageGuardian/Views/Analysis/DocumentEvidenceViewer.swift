import SwiftUI
import PDFKit
import QuickLook

/// Document evidence viewer with highlighting and annotation capabilities
struct DocumentEvidenceViewer: View {
    let issue: AuditResult
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDocument: MockDocument?
    @State private var highlightedText: String?
    @State private var showingAnnotations = true
    @State private var zoomLevel: Double = 1.0

    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                // Document List Sidebar
                documentListSidebar

                // Document Viewer
                if let selectedDocument = selectedDocument {
                    documentViewerSection(for: selectedDocument)
                } else {
                    emptyDocumentView
                }
            }
            .navigationTitle("Evidence Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
        }
        .onAppear {
            selectedDocument = supportingDocuments.first
        }
    }

    // MARK: - Document List Sidebar
    @ViewBuilder
    private var documentListSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Supporting Documents")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(supportingDocuments.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .padding()
            .background(Color(.systemGray6))

            // Document List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(supportingDocuments, id: \.name) { document in
                        DocumentListItem(
                            document: document,
                            isSelected: selectedDocument?.name == document.name,
                            hasEvidence: documentHasEvidence(document)
                        ) {
                            selectedDocument = document
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 280)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Document Viewer Section
    @ViewBuilder
    private func documentViewerSection(for document: MockDocument) -> some View {
        VStack(spacing: 0) {
            // Viewer Controls
            documentControlsBar(for: document)

            // Document Content
            ZStack {
                if document.type == "PDF" {
                    PDFDocumentView(document: document, zoomLevel: $zoomLevel)
                } else if document.type == "Image" {
                    ImageDocumentView(document: document, zoomLevel: $zoomLevel)
                } else {
                    TextDocumentView(document: document)
                }

                // Evidence Highlights Overlay
                if showingAnnotations {
                    EvidenceHighlightOverlay(issue: issue, document: document)
                }
            }
        }
    }

    // MARK: - Empty Document View
    @ViewBuilder
    private var emptyDocumentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("Select a Document")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Choose a document from the sidebar to view evidence and highlights")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Document Controls Bar
    @ViewBuilder
    private func documentControlsBar(for document: MockDocument) -> some View {
        HStack {
            // Document Info
            HStack(spacing: 8) {
                Image(systemName: documentIcon(for: document))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(document.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text("\(document.type) • \(document.size)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // View Controls
            HStack(spacing: 12) {
                // Zoom Controls
                HStack(spacing: 4) {
                    Button {
                        zoomLevel = max(0.5, zoomLevel - 0.25)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .disabled(zoomLevel <= 0.5)

                    Text("\(Int(zoomLevel * 100))%")
                        .font(.caption)
                        .frame(width: 40)

                    Button {
                        zoomLevel = min(3.0, zoomLevel + 0.25)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .disabled(zoomLevel >= 3.0)
                }

                Divider()
                    .frame(height: 20)

                // Annotations Toggle
                Button {
                    showingAnnotations.toggle()
                } label: {
                    Image(systemName: showingAnnotations ? "highlighter" : "highlighter")
                        .foregroundColor(showingAnnotations ? .orange : .secondary)
                }

                // Share Button
                Button {
                    shareDocument(document)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Close") {
                dismiss()
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button("Export Evidence Report") {
                    exportEvidenceReport()
                }

                Button("Print Documents") {
                    printDocuments()
                }

                Button("Share All Documents") {
                    shareAllDocuments()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Computed Properties
    private var supportingDocuments: [MockDocument] {
        // Mock documents - in real app would come from issue.supportingDocuments
        [
            MockDocument(name: "Mortgage Statement - January 2025.pdf", type: "PDF", size: "2.1 MB"),
            MockDocument(name: "Bank Statement - December 2024.pdf", type: "PDF", size: "1.8 MB"),
            MockDocument(name: "Payment Confirmation.jpg", type: "Image", size: "0.5 MB"),
            MockDocument(name: "Escrow Analysis 2024.pdf", type: "PDF", size: "1.2 MB")
        ]
    }

    // MARK: - Helper Functions
    private func documentIcon(for document: MockDocument) -> String {
        switch document.type {
        case "PDF": return "doc.fill"
        case "Image": return "photo.fill"
        default: return "doc"
        }
    }

    private func documentHasEvidence(_ document: MockDocument) -> Bool {
        // Mock implementation - in real app would check for highlights/annotations
        return document.name.contains("Statement")
    }

    private func shareDocument(_ document: MockDocument) {
        // TODO: Implement document sharing
        print("Sharing document: \(document.name)")
    }

    private func exportEvidenceReport() {
        // TODO: Implement evidence report export
        print("Exporting evidence report")
    }

    private func printDocuments() {
        // TODO: Implement printing
        print("Printing documents")
    }

    private func shareAllDocuments() {
        // TODO: Implement bulk sharing
        print("Sharing all documents")
    }
}

// MARK: - Supporting Views

struct DocumentListItem: View {
    let document: MockDocument
    let isSelected: Bool
    let hasEvidence: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Document Icon with Evidence Indicator
                ZStack(alignment: .topTrailing) {
                    Image(systemName: documentIcon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .blue)
                        .frame(width: 32, height: 32)

                    if hasEvidence {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }

                // Document Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(2)

                    HStack {
                        Text(document.type)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.white.opacity(0.3) : Color.blue.opacity(0.1))
                            )
                            .foregroundColor(isSelected ? .white : .blue)

                        Text(document.size)
                            .font(.caption)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    }

                    if hasEvidence {
                        HStack(spacing: 4) {
                            Image(systemName: "highlighter")
                                .font(.caption2)
                                .foregroundColor(.orange)

                            Text("Contains evidence")
                                .font(.caption2)
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue : Color(.systemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var documentIcon: String {
        switch document.type {
        case "PDF": return "doc.fill"
        case "Image": return "photo.fill"
        default: return "doc"
        }
    }
}

struct PDFDocumentView: View {
    let document: MockDocument
    @Binding var zoomLevel: Double

    var body: some View {
        // Mock PDF viewer - in real app would use PDFKit
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 20) {
                ForEach(0..<3, id: \.self) { pageIndex in
                    MockPDFPage(pageNumber: pageIndex + 1, document: document)
                        .scaleEffect(zoomLevel)
                }
            }
            .padding()
        }
        .background(Color(.systemGray5))
    }
}

struct ImageDocumentView: View {
    let document: MockDocument
    @Binding var zoomLevel: Double

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Image(systemName: "doc.text.image")
                .font(.system(size: 200))
                .foregroundColor(.secondary)
                .scaleEffect(zoomLevel)
                .padding()
        }
        .background(Color(.systemGray5))
    }
}

struct TextDocumentView: View {
    let document: MockDocument

    var body: some View {
        ScrollView {
            Text("Mock document content for \(document.name)")
                .font(.system(.body, design: .monospaced))
                .padding()
        }
        .background(Color(.systemBackground))
    }
}

struct MockPDFPage: View {
    let pageNumber: Int
    let document: MockDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Page Header
            HStack {
                Text("MORTGAGE STATEMENT")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Text("Page \(pageNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Mock Content with Highlighted Text
            VStack(alignment: .leading, spacing: 8) {
                Text("Account Number: 1234567890")
                Text("Statement Period: December 1, 2024 - December 31, 2024")

                if pageNumber == 1 {
                    // Highlighted evidence text
                    HStack {
                        Text("Late Fee Charged:")
                        Text("$25.00")
                            .fontWeight(.bold)
                            .padding(.horizontal, 4)
                            .background(Color.yellow.opacity(0.3))
                            .overlay(
                                Rectangle()
                                    .stroke(Color.orange, lineWidth: 2)
                            )
                    }
                }

                Text("Principal Balance: $245,678.90")
                Text("Interest Rate: 3.25%")
                Text("Next Payment Due: January 1, 2025")
            }
            .font(.subheadline)

            Spacer()
        }
        .padding()
        .frame(width: 400, height: 500)
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(Color.gray, lineWidth: 1)
        )
    }
}

struct EvidenceHighlightOverlay: View {
    let issue: AuditResult
    let document: MockDocument

    var body: some View {
        // Mock evidence highlights - in real app would show actual highlighted regions
        if document.name.contains("Statement") {
            VStack {
                Spacer()
                    .frame(height: 200)

                HStack {
                    Spacer()
                        .frame(width: 100)

                    Rectangle()
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 80, height: 20)
                        .overlay(
                            Rectangle()
                                .stroke(Color.orange, lineWidth: 2)
                        )

                    Spacer()
                }

                Spacer()
            }
        }
    }
}

#Preview {
    DocumentEvidenceViewer(issue: AuditResult.sampleResult())
}