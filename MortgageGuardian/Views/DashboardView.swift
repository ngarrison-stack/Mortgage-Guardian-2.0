import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var userStore: UserStore
    @State private var showingDocumentPicker = false
    @State private var showingAllIssues = false

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Welcome Section
                    welcomeSection

                    // Summary Cards
                    summaryCardsSection

                    // Quick Actions
                    quickActionsSection

                    // Recent Issues
                    recentIssuesSection

                    // Recent Documents
                    recentDocumentsSection
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .refreshable {
                userStore.refreshData()
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView()
            }
            .sheet(isPresented: $showingAllIssues) {
                NavigationView {
                    AnalysisView()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingAllIssues = false
                                }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Welcome Section
    @ViewBuilder
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back,")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(userStore.user.firstName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                // Notification badge
                if userStore.criticalIssuesCount() > 0 {
                    Button(action: { showingAllIssues = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 24, height: 24)

                            Text("\(userStore.criticalIssuesCount())")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                }
            }

            if userStore.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Updating data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }

    // MARK: - Summary Cards
    @ViewBuilder
    private var summaryCardsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            SummaryCard(
                title: "Critical Issues",
                value: "\(userStore.criticalIssuesCount())",
                subtitle: "Require immediate attention",
                icon: "exclamationmark.triangle.fill",
                color: .red,
                action: { showingAllIssues = true }
            )

            SummaryCard(
                title: "High Priority",
                value: "\(userStore.highIssuesCount())",
                subtitle: "Should be addressed soon",
                icon: "exclamationmark.circle.fill",
                color: .orange,
                action: { showingAllIssues = true }
            )

            SummaryCard(
                title: "Potential Savings",
                value: formatCurrency(userStore.totalPotentialSavings()),
                subtitle: "From identified errors",
                icon: "dollarsign.circle.fill",
                color: .green,
                action: { showingAllIssues = true }
            )

            SummaryCard(
                title: "Documents",
                value: "\(userStore.documents.count)",
                subtitle: "\(analyzedDocumentsCount()) analyzed",
                icon: "doc.text.fill",
                color: .blue,
                action: { showingDocumentPicker = true }
            )
        }
    }

    // MARK: - Quick Actions
    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickActionButton(
                    icon: "camera.fill",
                    title: "Scan Document",
                    subtitle: "Camera",
                    color: .blue
                ) {
                    showingDocumentPicker = true
                }

                QuickActionButton(
                    icon: "folder.fill",
                    title: "Upload Files",
                    subtitle: "From Files",
                    color: .green
                ) {
                    showingDocumentPicker = true
                }

                QuickActionButton(
                    icon: "link",
                    title: "Connect Bank",
                    subtitle: userStore.user.isPlaidConnected ? "Connected" : "Plaid",
                    color: userStore.user.isPlaidConnected ? .green : .purple
                ) {
                    // TODO: Implement Plaid connection
                }

                QuickActionButton(
                    icon: "doc.plaintext.fill",
                    title: "Generate Letter",
                    subtitle: "Notice of Error",
                    color: .orange
                ) {
                    // TODO: Navigate to letter generation
                }
            }
        }
    }

    // MARK: - Recent Issues
    @ViewBuilder
    private var recentIssuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Issues")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if !userStore.auditResults.isEmpty {
                    Button("View All") {
                        showingAllIssues = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }

            if userStore.auditResults.isEmpty {
                EmptyStateView(
                    icon: "checkmark.shield.fill",
                    title: "No Issues Found",
                    message: "Upload documents to start analyzing for potential errors",
                    actionTitle: "Upload Document",
                    action: { showingDocumentPicker = true }
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(userStore.auditResults.prefix(3))) { issue in
                        IssueRow(auditResult: issue) {
                            showingAllIssues = true
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemBackground))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Recent Documents
    @ViewBuilder
    private var recentDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Documents")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if !userStore.documents.isEmpty {
                    NavigationLink("View All") {
                        DocumentsView()
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }

            if userStore.documents.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Documents",
                    message: "Upload your first mortgage document to get started",
                    actionTitle: "Upload Document",
                    action: { showingDocumentPicker = true }
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(userStore.documents.prefix(3))) { document in
                        DocumentRow(document: document) {
                            // TODO: Navigate to document detail
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemBackground))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func analyzedDocumentsCount() -> Int {
        return userStore.documents.filter { $0.isAnalyzed }.count
    }
}

// MARK: - Quick Action Button Component
struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Document Picker View (Placeholder)
struct DocumentPickerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                Text("Document Upload")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Select how you'd like to add your mortgage documents")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Button("Take Photo") {
                        // TODO: Implement camera capture
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button("Choose from Files") {
                        // TODO: Implement file picker
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(UserStore())
}