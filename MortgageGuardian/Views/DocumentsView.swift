import SwiftUI

struct DocumentsView: View {
    @EnvironmentObject var userStore: UserStore
    @State private var searchText = ""
    @State private var selectedDocumentType: MortgageDocument.DocumentType? = nil
    @State private var showingDocumentPicker = false
    @State private var showingFilterSheet = false
    @State private var selectedDocument: MortgageDocument?
    @State private var documentToDelete: MortgageDocument?
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showingError = false

    private var filteredDocuments: [MortgageDocument] {
        var documents = userStore.documents

        // Filter by document type
        if let selectedType = selectedDocumentType {
            documents = documents.filter { $0.documentType == selectedType }
        }

        // Filter by search text
        if !searchText.isEmpty {
            documents = documents.filter { document in
                document.fileName.localizedCaseInsensitiveContains(searchText) ||
                document.documentType.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort by upload date (newest first)
        return documents.sorted { $0.uploadDate > $1.uploadDate }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterBar

                if userStore.isLoading {
                    LoadingView(message: "Loading documents...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredDocuments.isEmpty {
                    emptyStateView
                } else {
                    documentsListView
                }
            }
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView()
            }
            .sheet(isPresented: $showingFilterSheet) {
                DocumentFilterSheet(
                    selectedType: $selectedDocumentType,
                    isPresented: $showingFilterSheet
                )
            }
            .sheet(item: $selectedDocument) { document in
                DocumentDetailView(document: document)
            }
            .refreshable {
                userStore.refreshData()
            }
            .task {
                await userStore.fetchDocumentsFromBackend()
                userStore.startPollingIfNeeded()
            }
            .onDisappear {
                userStore.stopPolling()
            }
            .confirmationDialog(
                "Delete Document?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    confirmDelete()
                }
                Button("Cancel", role: .cancel) {
                    documentToDelete = nil
                }
            } message: {
                Text("Delete \"\(documentToDelete?.fileName ?? "this document")\"? This cannot be undone.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unexpected error occurred")
            }
        }
    }

    // MARK: - Search and Filter Bar
    @ViewBuilder
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search documents...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())

                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )

            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedDocumentType == nil
                        ) {
                            selectedDocumentType = nil
                        }

                        ForEach(MortgageDocument.DocumentType.allCases, id: \.self) { type in
                            FilterChip(
                                title: type.displayName,
                                isSelected: selectedDocumentType == type
                            ) {
                                selectedDocumentType = type
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Button {
                    showingFilterSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Empty State
    @ViewBuilder
    private var emptyStateView: some View {
        VStack {
            Spacer()

            if searchText.isEmpty && selectedDocumentType == nil {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Documents",
                    message: "Upload your mortgage documents to start analyzing for potential errors and discrepancies",
                    actionTitle: "Upload First Document",
                    action: { showingDocumentPicker = true }
                )
            } else {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Results",
                    message: "No documents match your search criteria. Try adjusting your filters or search terms.",
                    actionTitle: "Clear Filters",
                    action: {
                        searchText = ""
                        selectedDocumentType = nil
                    }
                )
            }

            Spacer()
        }
    }

    // MARK: - Documents List
    @ViewBuilder
    private var documentsListView: some View {
        List {
            // Summary Section
            Section {
                DocumentsSummaryView(
                    totalDocuments: userStore.documents.count,
                    analyzedDocuments: userStore.documents.filter { $0.isAnalyzed }.count,
                    pendingDocuments: userStore.documents.filter { !$0.isAnalyzed }.count,
                    issuesFound: userStore.documents.flatMap { $0.analysisResults }.count
                )
            }

            // Documents by Type
            let groupedDocuments = Dictionary(grouping: filteredDocuments) { $0.documentType }
            let sortedGroups = groupedDocuments.sorted { first, second in
                first.key.displayName < second.key.displayName
            }

            ForEach(sortedGroups, id: \.key) { documentType, documents in
                Section(header: DocumentTypeSectionHeader(documentType: documentType, count: documents.count)) {
                    ForEach(documents) { document in
                        VStack(alignment: .leading, spacing: 4) {
                            DocumentRow(document: document) {
                                selectedDocument = document
                            }
                            pipelineStatusView(for: document)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                deleteDocument(document)
                            }

                            if !document.isAnalyzed {
                                Button("Analyze") {
                                    analyzeDocument(document)
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }

    // MARK: - Pipeline Status Indicator

    @ViewBuilder
    private func pipelineStatusView(for document: MortgageDocument) -> some View {
        if document.isAnalyzed && document.pipelineStatus != nil {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Analysis complete")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        } else if let status = document.pipelineStatus,
                  !["complete", "analyzed"].contains(status) {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text(pipelineStatusLabel(status))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .transition(.opacity)
        }
    }

    private func pipelineStatusLabel(_ status: String) -> String {
        switch status {
        case "uploaded":
            return "Queued for processing..."
        case "ocr":
            return "Extracting text..."
        case "classifying":
            return "Identifying document type..."
        case "analyzing":
            return "Analyzing for issues..."
        case "analyzed":
            return "Analysis complete"
        case "review":
            return "Ready for review"
        case "complete":
            return "Complete"
        default:
            return "Processing..."
        }
    }

    // MARK: - Actions
    private func deleteDocument(_ document: MortgageDocument) {
        documentToDelete = document
        showingDeleteConfirmation = true
    }

    private func confirmDelete() {
        guard let document = documentToDelete else { return }
        isDeleting = true
        Task {
            do {
                try await userStore.deleteDocumentFromBackend(document)
                withAnimation {
                    isDeleting = false
                    documentToDelete = nil
                }
            } catch {
                isDeleting = false
                errorMessage = "Couldn't delete document. Please try again."
                showingError = true
            }
        }
    }

    private func analyzeDocument(_ document: MortgageDocument) {
        guard let serverId = document.serverDocumentId else {
            errorMessage = "Document hasn't been uploaded yet."
            showingError = true
            return
        }
        Task {
            do {
                try await APIClient.shared.processDocument(
                    documentId: serverId,
                    documentText: document.originalText.isEmpty ? nil : document.originalText,
                    documentType: document.documentType.rawValue
                )
                // Pipeline triggered -- polling will pick up status changes
            } catch {
                errorMessage = "Couldn't start analysis. Tap Analyze to try again."
                showingError = true
            }
        }
    }
}

// MARK: - Filter Chip Component
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Documents Summary View
struct DocumentsSummaryView: View {
    let totalDocuments: Int
    let analyzedDocuments: Int
    let pendingDocuments: Int
    let issuesFound: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Documents")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(totalDocuments)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Analyzed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(analyzedDocuments)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Pending")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(pendingDocuments)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Issues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(issuesFound)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
            }

            if totalDocuments > 0 {
                ProgressView(value: Double(analyzedDocuments), total: Double(totalDocuments))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Document Type Section Header
struct DocumentTypeSectionHeader: View {
    let documentType: MortgageDocument.DocumentType
    let count: Int

    var body: some View {
        HStack {
            Image(systemName: documentType.icon)
                .foregroundColor(.blue)
                .font(.subheadline)

            Text(documentType.displayName)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Text("\(count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Document Filter Sheet
struct DocumentFilterSheet: View {
    @Binding var selectedType: MortgageDocument.DocumentType?
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                Section("Document Type") {
                    Button("All Documents") {
                        selectedType = nil
                        isPresented = false
                    }
                    .foregroundColor(selectedType == nil ? .blue : .primary)

                    ForEach(MortgageDocument.DocumentType.allCases, id: \.self) { type in
                        Button(type.displayName) {
                            selectedType = type
                            isPresented = false
                        }
                        .foregroundColor(selectedType == type ? .blue : .primary)
                    }
                }
            }
            .navigationTitle("Filter Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Document Detail View (Placeholder)
struct DocumentDetailView: View {
    let document: MortgageDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Document Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Document Information")
                            .font(.headline)
                            .fontWeight(.semibold)

                        VStack(spacing: 8) {
                            InfoRow(label: "File Name", value: document.fileName)
                            InfoRow(label: "Type", value: document.documentType.displayName)
                            InfoRow(label: "Upload Date", value: formatDate(document.uploadDate))
                            InfoRow(label: "Status", value: document.isAnalyzed ? "Analyzed" : "Pending Analysis")
                        }
                    }

                    // Analysis Results
                    if !document.analysisResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Analysis Results")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text("\(document.analysisResults.count) issues found")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            // TODO: Add detailed analysis results
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle(document.documentType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DocumentsView()
        .environmentObject(UserStore())
}