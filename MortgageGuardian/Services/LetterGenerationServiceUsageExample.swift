import Foundation
import SwiftUI

/// Example usage of LetterGenerationService with integration to existing app services
class LetterGenerationServiceUsageExample: ObservableObject {

    private let letterService = LetterGenerationService.shared
    private let securityService = SecurityService.shared

    @Published var generatedLetters: [GeneratedLetter] = []
    @Published var isGenerating = false
    @Published var error: String?

    // MARK: - Example Usage Methods

    /// Example: Generate Notice of Error letter from audit results
    func generateNoticeOfErrorFromAudit() async {
        do {
            isGenerating = true
            error = nil

            // Get sample user and mortgage account
            let user = User.sampleUser
            guard let mortgageAccount = user.mortgageAccounts.first else {
                throw LetterGenerationService.LetterGenerationError.invalidUserData
            }

            // Create sample audit results
            let auditResults = createSampleAuditResults()

            // Get Notice of Error template
            guard let template = letterService.availableTemplates.first(where: { $0.templateType == .noticeOfError }) else {
                throw LetterGenerationService.LetterGenerationError.templateNotFound
            }

            // Generate letter
            let generatedLetter = try await letterService.generateLetter(
                templateId: template.id,
                user: user,
                mortgageAccount: mortgageAccount,
                auditResults: auditResults,
                customFields: [
                    "issue_description": auditResults.first?.title ?? "Mortgage servicing error",
                    "detailed_explanation": auditResults.first?.detailedExplanation ?? "Detailed explanation of the error"
                ],
                urgencyLevel: .standard
            )

            await MainActor.run {
                generatedLetters.append(generatedLetter)
                isGenerating = false
            }

        } catch let letterError as LetterGenerationService.LetterGenerationError {
            await MainActor.run {
                error = letterError.localizedDescription
                isGenerating = false
            }
        } catch {
            await MainActor.run {
                self.error = "Unexpected error: \(error.localizedDescription)"
                isGenerating = false
            }
        }
    }

    /// Example: Generate progressive letter series for escalation
    func generateProgressiveLetterSeries() async {
        do {
            isGenerating = true
            error = nil

            let user = User.sampleUser
            guard let mortgageAccount = user.mortgageAccounts.first else {
                throw LetterGenerationService.LetterGenerationError.invalidUserData
            }

            let auditResults = createSampleAuditResults()

            // Generate progressive series
            let letters = try await letterService.generateProgressiveLetterSeries(
                user: user,
                mortgageAccount: mortgageAccount,
                auditResults: auditResults,
                customFields: [
                    "issue_description": "Misapplied payment causing incorrect late fees",
                    "detailed_explanation": "Payment made on 12/30/2024 was applied late, resulting in incorrect $25 late fee"
                ]
            )

            await MainActor.run {
                generatedLetters.append(contentsOf: letters)
                isGenerating = false
            }

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isGenerating = false
            }
        }
    }

    /// Example: Generate AI-enhanced letter
    func generateAIEnhancedLetter() async {
        do {
            isGenerating = true
            error = nil

            let user = User.sampleUser
            guard let mortgageAccount = user.mortgageAccounts.first else {
                throw LetterGenerationService.LetterGenerationError.invalidUserData
            }

            let auditResults = createSampleAuditResults()

            guard let template = letterService.availableTemplates.first(where: { $0.templateType == .escalationLetter }) else {
                throw LetterGenerationService.LetterGenerationError.templateNotFound
            }

            // Generate AI-enhanced letter
            let enhancedLetter = try await letterService.generateAIEnhancedLetter(
                templateId: template.id,
                user: user,
                mortgageAccount: mortgageAccount,
                auditResults: auditResults,
                customFields: [
                    "original_date": "2024-01-15",
                    "days_since_issue": "45"
                ]
            )

            await MainActor.run {
                generatedLetters.append(enhancedLetter)
                isGenerating = false
            }

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isGenerating = false
            }
        }
    }

    /// Example: Export letter as secured PDF
    func exportLetterAsSecuredPDF(letter: GeneratedLetter) async -> Data? {
        do {
            // Export with password protection
            let pdfData = try await letterService.exportLetterAsPDF(
                letter: letter,
                includeAttachments: true,
                applyPasswordProtection: true
            )

            return pdfData

        } catch {
            await MainActor.run {
                self.error = "Export failed: \(error.localizedDescription)"
            }
            return nil
        }
    }

    /// Example: Preview letter content before generation
    func previewLetterContent() async -> String? {
        do {
            let user = User.sampleUser
            guard let mortgageAccount = user.mortgageAccounts.first else {
                return nil
            }

            let auditResults = createSampleAuditResults()

            guard let template = letterService.availableTemplates.first(where: { $0.templateType == .noticeOfError }) else {
                return nil
            }

            let preview = try await letterService.previewLetterContent(
                templateId: template.id,
                user: user,
                mortgageAccount: mortgageAccount,
                auditResults: auditResults,
                customFields: [
                    "issue_description": "Sample issue description",
                    "detailed_explanation": "Sample detailed explanation"
                ]
            )

            return preview

        } catch {
            await MainActor.run {
                self.error = "Preview failed: \(error.localizedDescription)"
            }
            return nil
        }
    }

    /// Example: Get recommended letter type based on audit severity
    func getRecommendedLetterType() -> LetterTemplate.TemplateType {
        let auditResults = createSampleAuditResults()
        return letterService.getRecommendedLetterType(for: auditResults)
    }

    /// Example: Update letter status for tracking
    func updateLetterStatus(letter: GeneratedLetter, newStatus: GeneratedLetter.LetterStatus) {
        let trackingInfo = GeneratedLetter.TrackingInfo(
            sentDate: newStatus == .sent ? Date() : nil,
            deliveryMethod: .certifiedMail,
            trackingNumber: newStatus == .sent ? "1234567890" : nil,
            expectedResponseDate: newStatus == .sent ? Calendar.current.date(byAdding: .day, value: 30, to: Date()) : nil,
            actualResponseDate: nil,
            responseReceived: false
        )

        letterService.updateLetterStatus(
            letterId: letter.id,
            status: newStatus,
            trackingInfo: trackingInfo
        )
    }

    // MARK: - Integration with Existing Services

    /// Example: Generate letter from DocumentProcessor analysis
    func generateLetterFromDocumentAnalysis(documents: [MortgageDocument]) async {
        // This would integrate with existing DocumentProcessor
        // For now, we'll simulate the process

        do {
            // Simulate document processing results
            let auditResults = simulateDocumentProcessingResults(from: documents)

            let user = User.sampleUser
            guard let mortgageAccount = user.mortgageAccounts.first else {
                throw LetterGenerationService.LetterGenerationError.invalidUserData
            }

            // Generate appropriate letter based on findings
            let recommendedType = letterService.getRecommendedLetterType(for: auditResults)
            guard let template = letterService.availableTemplates.first(where: { $0.templateType == recommendedType }) else {
                throw LetterGenerationService.LetterGenerationError.templateNotFound
            }

            let letter = try await letterService.generateLetter(
                templateId: template.id,
                user: user,
                mortgageAccount: mortgageAccount,
                auditResults: auditResults
            )

            await MainActor.run {
                generatedLetters.append(letter)
            }

        } catch {
            await MainActor.run {
                self.error = "Document analysis integration failed: \(error.localizedDescription)"
            }
        }
    }

    /// Example: Secure document storage integration
    func saveLetterSecurely(letter: GeneratedLetter) async {
        do {
            guard let pdfData = letter.pdfData else {
                throw LetterGenerationService.LetterGenerationError.exportFailed
            }

            // Use SecurityService to encrypt and store
            let encryptedData = try await securityService.encryptData(pdfData)

            // Save to secure storage (implementation would depend on specific requirements)
            let filename = "Letter_\(letter.template.templateType.rawValue)_\(letter.generatedDate.timeIntervalSince1970)"
            // await securityService.saveSecureDocument(encryptedData, filename: filename)

            print("Letter saved securely: \(filename)")

        } catch {
            await MainActor.run {
                self.error = "Secure storage failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Helper Methods

    private func createSampleAuditResults() -> [AuditResult] {
        return [
            AuditResult(
                issueType: .misappliedPayment,
                severity: .high,
                title: "Misapplied Payment Causing Late Fee",
                description: "Payment was applied incorrectly resulting in unwarranted late fee",
                detailedExplanation: "Payment due on 01/01/2025 was received on 01/05/2025, but bank records show payment was sent on 12/30/2024. A $25 late fee was incorrectly assessed.",
                suggestedAction: "Request removal of late fee and correction of payment application date",
                affectedAmount: 25.00,
                detectionMethod: .combinedAnalysis,
                confidence: 0.95,
                evidenceText: "Bank statement shows payment initiated 12/30/2024",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 0.00,
                    actualValue: 25.00,
                    difference: 25.00,
                    formula: "Late fee assessment error",
                    assumptions: ["Payment sent before due date"],
                    warningFlags: ["RESPA violation potential"]
                ),
                createdDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            ),
            AuditResult(
                issueType: .incorrectInterest,
                severity: .medium,
                title: "Interest Calculation Error",
                description: "Monthly interest appears to be calculated incorrectly",
                detailedExplanation: "Interest charged for January 2025 was $1,250.50, but based on the stated APR of 3.75% and principal balance, it should be $1,203.25.",
                suggestedAction: "Request interest recalculation and account correction",
                affectedAmount: 47.25,
                detectionMethod: .manualCalculation,
                confidence: 0.88,
                evidenceText: "Manual calculation shows discrepancy in interest assessment",
                calculationDetails: AuditResult.CalculationDetails(
                    expectedValue: 1203.25,
                    actualValue: 1250.50,
                    difference: 47.25,
                    formula: "(Principal × APR) / 12",
                    assumptions: ["APR 3.75%", "Principal $385,000"],
                    warningFlags: ["Interest calculation methodology unclear"]
                ),
                createdDate: Calendar.current.date(byAdding: .day, value: -15, to: Date()) ?? Date()
            )
        ]
    }

    private func simulateDocumentProcessingResults(from documents: [MortgageDocument]) -> [AuditResult] {
        // This would integrate with real DocumentProcessor results
        // For now, return sample results
        return createSampleAuditResults()
    }

    // MARK: - Template Management Examples

    /// Example: Add custom template
    func addCustomTemplate() {
        do {
            let customTemplate = LetterTemplate(
                templateType: .demandLetter,
                name: "Custom Demand Letter",
                version: "1.0",
                title: "Formal Demand for Correction",
                subject: "DEMAND: Immediate Correction Required - {{LOAN_NUMBER}}",
                body: """
                {{CURRENT_DATE}}

                {{SERVICER_NAME}}
                {{SERVICER_ADDRESS}}

                RE: FORMAL DEMAND FOR IMMEDIATE CORRECTION
                Loan Number: {{LOAN_NUMBER}}

                This is a formal demand for immediate correction of the following error:
                {{ISSUE_DESCRIPTION}}

                You have 10 business days to resolve this matter.

                Sincerely,
                {{USER_FULL_NAME}}
                """,
                legalCitations: ["12 CFR § 1024.35"],
                requiredFields: [],
                respaCompliance: LetterTemplate.RESPACompliance(
                    isRESPACompliant: true,
                    regulationSection: "12 CFR § 1024.35",
                    requiredDisclosures: ["Demand for correction"],
                    responseTimelineDays: 10,
                    legalRequirements: ["Urgent format"],
                    citedRegulations: []
                ),
                formatOptions: LetterTemplate.FormatOptions(
                    fontFamily: "Arial",
                    fontSize: 12.0,
                    lineSpacing: 1.0,
                    margins: LetterTemplate.FormatOptions.Margins(top: 72, bottom: 72, left: 72, right: 72),
                    headerStyle: LetterTemplate.FormatOptions.HeaderStyle(
                        includeLogo: false,
                        includeUserAddress: true,
                        includeDate: true,
                        includeSubject: true,
                        alignment: .left
                    ),
                    includeLetterhead: true,
                    includeSignatureLine: true,
                    includeAttachmentsList: false,
                    includeDeliveryConfirmation: true
                ),
                createdDate: Date(),
                lastUpdated: Date(),
                isActive: true
            )

            try letterService.addCustomTemplate(customTemplate)
            print("Custom template added successfully")

        } catch {
            self.error = "Failed to add custom template: \(error.localizedDescription)"
        }
    }

    /// Example: Get generation statistics
    func getStatistics() -> (total: Int, byType: [LetterTemplate.TemplateType: Int], byStatus: [GeneratedLetter.LetterStatus: Int]) {
        return letterService.getGenerationStatistics()
    }

    // MARK: - Batch Operations

    /// Example: Generate letters for multiple issues
    func generateLettersForMultipleIssues() async {
        do {
            let user = User.sampleUser
            guard let mortgageAccount = user.mortgageAccounts.first else {
                throw LetterGenerationService.LetterGenerationError.invalidUserData
            }

            let auditResults = createSampleAuditResults()

            // Generate multiple letter types
            let letterTypes: [LetterTemplate.TemplateType] = [
                .noticeOfError,
                .qualifiedWrittenRequest
            ]

            let letters = try await letterService.generateMultipleLetters(
                user: user,
                mortgageAccount: mortgageAccount,
                auditResults: auditResults,
                templateTypes: letterTypes
            )

            await MainActor.run {
                generatedLetters.append(contentsOf: letters)
            }

        } catch {
            await MainActor.run {
                self.error = "Batch generation failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - SwiftUI Integration Example
struct LetterGenerationView: View {
    @StateObject private var example = LetterGenerationServiceUsageExample()

    var body: some View {
        NavigationView {
            VStack {
                if example.isGenerating {
                    ProgressView("Generating letter...")
                        .padding()
                }

                if let error = example.error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                }

                List(example.generatedLetters) { letter in
                    VStack(alignment: .leading) {
                        Text(letter.template.name)
                            .font(.headline)
                        Text(letter.template.templateType.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Status: \(letter.status.displayName)")
                            .font(.caption)
                    }
                }

                Spacer()

                VStack {
                    Button("Generate Notice of Error") {
                        Task {
                            await example.generateNoticeOfErrorFromAudit()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Generate Progressive Series") {
                        Task {
                            await example.generateProgressiveLetterSeries()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Generate AI-Enhanced Letter") {
                        Task {
                            await example.generateAIEnhancedLetter()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Letter Generation")
        }
    }
}