import SwiftUI

struct StorageConsentView: View {
    @StateObject private var storageService = DocumentStorageService.shared
    @State private var showingPrivacyPolicy = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Cloud Storage")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Securely store your mortgage documents and analysis history")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)

                    Divider()

                    // Benefits
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Benefits")
                            .font(.headline)

                        FeatureRow(
                            icon: "checkmark.circle.fill",
                            title: "Access Anywhere",
                            description: "View your documents on any device"
                        )

                        FeatureRow(
                            icon: "clock.fill",
                            title: "Analysis History",
                            description: "Keep track of all your mortgage audits"
                        )

                        FeatureRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Auto Backup",
                            description: "Never lose important documents"
                        )

                        FeatureRow(
                            icon: "lock.shield.fill",
                            title: "Bank-Grade Security",
                            description: "End-to-end encryption and secure storage"
                        )
                    }
                    .padding(.horizontal)

                    Divider()

                    // Privacy Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Privacy & Security")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 12) {
                            SecurityFeature(
                                icon: "key.fill",
                                text: "Documents encrypted with AES-256"
                            )

                            SecurityFeature(
                                icon: "timer",
                                text: "Auto-deleted after 30 days"
                            )

                            SecurityFeature(
                                icon: "eye.slash.fill",
                                text: "We cannot access your document content"
                            )

                            SecurityFeature(
                                icon: "trash.fill",
                                text: "Delete anytime from Settings"
                            )

                            SecurityFeature(
                                icon: "hand.raised.fill",
                                text: "Never shared with third parties"
                            )
                        }

                        Button("View Privacy Policy") {
                            showingPrivacyPolicy = true
                        }
                        .foregroundColor(.blue)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)

                    Divider()

                    // Storage Options
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Choice")
                            .font(.headline)

                        VStack(spacing: 12) {
                            StorageOptionView(
                                title: "Enable Cloud Storage",
                                description: "Recommended for best experience",
                                isRecommended: true
                            ) {
                                Task {
                                    await enableStorage()
                                }
                            }

                            StorageOptionView(
                                title: "Local Only",
                                description: "Documents stay on this device",
                                isRecommended: false
                            ) {
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
            .navigationTitle("Storage Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    private func enableStorage() async {
        let success = await storageService.requestStorageConsent()
        if success {
            dismiss()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct SecurityFeature: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

struct StorageOptionView: View {
    let title: String
    let description: String
    let isRecommended: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }

                        Spacer()
                    }

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Group {
                        PolicySection(
                            title: "Data Collection",
                            content: """
                            We collect only the mortgage documents you choose to upload and the analysis results we generate. No personal financial information is stored without your explicit consent.
                            """
                        )

                        PolicySection(
                            title: "Data Security",
                            content: """
                            All documents are encrypted using AES-256 encryption before storage. Your data is stored in secure AWS data centers with bank-grade security measures.
                            """
                        )

                        PolicySection(
                            title: "Data Retention",
                            content: """
                            Documents are automatically deleted after 30 days. You can delete your documents at any time from the app settings.
                            """
                        )

                        PolicySection(
                            title: "Data Sharing",
                            content: """
                            We never share your documents or personal information with third parties. Your data remains private and secure.
                            """
                        )

                        PolicySection(
                            title: "Your Rights",
                            content: """
                            You have the right to access, modify, or delete your data at any time. You can revoke storage consent and all data will be permanently deleted.
                            """
                        )
                    }

                    Text("Last updated: \(DateFormatter.mediumDateFormatter.string(from: Date()))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
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
}

struct PolicySection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            Text(content)
                .font(.body)
                .foregroundColor(.primary)
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

struct StorageConsentView_Previews: PreviewProvider {
    static var previews: some View {
        StorageConsentView()
    }
}