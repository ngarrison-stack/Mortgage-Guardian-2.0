import Foundation
import Combine
import SwiftUI

/// Comprehensive service for generating RESPA-compliant mortgage letters
@MainActor
class LetterGenerationService: ObservableObject {

    // MARK: - Published Properties
    @Published var availableTemplates: [LetterTemplate] = []
    @Published var generatedLetters: [GeneratedLetter] = []
    @Published var isLoading = false
    @Published var error: LetterGenerationError?

    // MARK: - Private Properties
    private let pdfGenerator = PDFGenerator()
    private let securityService = SecurityService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Singleton
    static let shared = LetterGenerationService()

    private init() {
        loadDefaultTemplates()
        setupBindings()
    }

    // MARK: - Error Types
    enum LetterGenerationError: LocalizedError {
        case templateNotFound
        case invalidUserData
        case missingRequiredFields([String])
        case generationFailed(String)
        case securityValidationFailed
        case exportFailed
        case templateValidationFailed
        case insufficientData

        var errorDescription: String? {
            switch self {
            case .templateNotFound:
                return "Letter template not found"
            case .invalidUserData:
                return "Invalid or incomplete user data"
            case .missingRequiredFields(let fields):
                return "Missing required fields: \(fields.joined(separator: ", "))"
            case .generationFailed(let reason):
                return "Letter generation failed: \(reason)"
            case .securityValidationFailed:
                return "Security validation failed"
            case .exportFailed:
                return "Failed to export letter"
            case .templateValidationFailed:
                return "Template validation failed"
            case .insufficientData:
                return "Insufficient data to generate letter"
            }
        }
    }

    // MARK: - Public Methods

    /// Generate a letter from template and context
    func generateLetter(
        templateId: UUID,
        user: User,
        mortgageAccount: User.MortgageAccount,
        auditResults: [AuditResult],
        customFields: [String: String] = [:],
        urgencyLevel: LetterTemplate.UrgencyLevel = .standard
    ) async throws -> GeneratedLetter {

        isLoading = true
        error = nil

        defer {
            isLoading = false
        }

        do {
            // Find template
            guard let template = availableTemplates.first(where: { $0.id == templateId }) else {
                throw LetterGenerationError.templateNotFound
            }

            // Validate inputs
            try validateInputs(user: user, mortgageAccount: mortgageAccount, auditResults: auditResults)

            // Validate required fields
            try validateRequiredFields(template: template, customFields: customFields)

            // Create generation context
            let context = createGenerationContext(
                user: user,
                mortgageAccount: mortgageAccount,
                auditResults: auditResults,
                customFields: customFields,
                urgencyLevel: urgencyLevel
            )

            // Generate letter content
            let content = try await generateLetterContent(template: template, context: context)

            // Generate formatted content
            let formattedContent = try await generateFormattedContent(template: template, context: context)

            // Generate PDF
            let pdfData = try await pdfGenerator.generateLetterPDF(
                template: template,
                context: context,
                configuration: .standard
            )

            // Create generated letter
            let generatedLetter = GeneratedLetter(
                template: template,
                context: context,
                content: content,
                formattedContent: formattedContent,
                pdfData: pdfData,
                generatedDate: Date(),
                status: .draft,
                trackingInfo: nil
            )

            // Store generated letter
            generatedLetters.append(generatedLetter)

            return generatedLetter

        } catch let generationError as LetterGenerationError {
            error = generationError
            throw generationError
        } catch {
            let wrappedError = LetterGenerationError.generationFailed(error.localizedDescription)
            self.error = wrappedError
            throw wrappedError
        }
    }

    /// Generate multiple letters for different issue types
    func generateMultipleLetters(
        user: User,
        mortgageAccount: User.MortgageAccount,
        auditResults: [AuditResult],
        templateTypes: [LetterTemplate.TemplateType] = [.noticeOfError],
        customFields: [String: String] = [:]
    ) async throws -> [GeneratedLetter] {

        var generatedLetters: [GeneratedLetter] = []

        for templateType in templateTypes {
            guard let template = availableTemplates.first(where: { $0.templateType == templateType }) else {
                continue
            }

            do {
                let letter = try await generateLetter(
                    templateId: template.id,
                    user: user,
                    mortgageAccount: mortgageAccount,
                    auditResults: auditResults,
                    customFields: customFields,
                    urgencyLevel: templateType.urgencyLevel
                )
                generatedLetters.append(letter)
            } catch {
                print("Failed to generate \(templateType.displayName): \(error)")
            }
        }

        return generatedLetters
    }

    /// Generate progressive letter series (Notice of Error -> Escalation -> CFPB)
    func generateProgressiveLetterSeries(
        user: User,
        mortgageAccount: User.MortgageAccount,
        auditResults: [AuditResult],
        customFields: [String: String] = [:]
    ) async throws -> [GeneratedLetter] {

        let progressiveTypes: [LetterTemplate.TemplateType] = [
            .noticeOfError,
            .qualifiedWrittenRequest,
            .escalationLetter,
            .cfpbComplaint
        ]

        return try await generateMultipleLetters(
            user: user,
            mortgageAccount: mortgageAccount,
            auditResults: auditResults,
            templateTypes: progressiveTypes,
            customFields: customFields
        )
    }

    /// Export letter as PDF with optional security
    func exportLetterAsPDF(
        letter: GeneratedLetter,
        includeAttachments: Bool = false,
        applyPasswordProtection: Bool = false
    ) async throws -> Data {

        guard let pdfData = letter.pdfData else {
            throw LetterGenerationError.exportFailed
        }

        if applyPasswordProtection {
            // Apply additional security measures
            return try await applySecurityToPDF(pdfData: pdfData, letter: letter)
        }

        return pdfData
    }

    /// Get recommended letter type based on audit results
    func getRecommendedLetterType(for auditResults: [AuditResult]) -> LetterTemplate.TemplateType {
        guard !auditResults.isEmpty else {
            return .noticeOfError
        }

        let highSeverityIssues = auditResults.filter { $0.severity == .high || $0.severity == .critical }
        let totalDamages = auditResults.compactMap { $0.affectedAmount }.reduce(0, +)

        if totalDamages > 5000 || highSeverityIssues.count >= 3 {
            return .escalationLetter
        } else if auditResults.count > 1 {
            return .qualifiedWrittenRequest
        } else {
            return .noticeOfError
        }
    }

    /// Get templates by type
    func getTemplates(ofType type: LetterTemplate.TemplateType) -> [LetterTemplate] {
        return availableTemplates.filter { $0.templateType == type && $0.isActive }
    }

    /// Preview letter content without generating PDF
    func previewLetterContent(
        templateId: UUID,
        user: User,
        mortgageAccount: User.MortgageAccount,
        auditResults: [AuditResult],
        customFields: [String: String] = [:]
    ) async throws -> String {

        guard let template = availableTemplates.first(where: { $0.id == templateId }) else {
            throw LetterGenerationError.templateNotFound
        }

        let context = createGenerationContext(
            user: user,
            mortgageAccount: mortgageAccount,
            auditResults: auditResults,
            customFields: customFields,
            urgencyLevel: .standard
        )

        return try await generateLetterContent(template: template, context: context)
    }

    /// Update letter status and tracking
    func updateLetterStatus(
        letterId: UUID,
        status: GeneratedLetter.LetterStatus,
        trackingInfo: GeneratedLetter.TrackingInfo? = nil
    ) {
        if let index = generatedLetters.firstIndex(where: { $0.id == letterId }) {
            var updatedLetter = generatedLetters[index]
            updatedLetter = GeneratedLetter(
                id: updatedLetter.id,
                template: updatedLetter.template,
                context: updatedLetter.context,
                content: updatedLetter.content,
                formattedContent: updatedLetter.formattedContent,
                pdfData: updatedLetter.pdfData,
                generatedDate: updatedLetter.generatedDate,
                status: status,
                trackingInfo: trackingInfo ?? updatedLetter.trackingInfo
            )
            generatedLetters[index] = updatedLetter
        }
    }

    // MARK: - Template Management

    /// Add custom template
    func addCustomTemplate(_ template: LetterTemplate) throws {
        // Validate template
        try validateTemplate(template)

        // Check for duplicates
        if availableTemplates.contains(where: { $0.name == template.name && $0.templateType == template.templateType }) {
            throw LetterGenerationError.templateValidationFailed
        }

        availableTemplates.append(template)
    }

    /// Update existing template
    func updateTemplate(_ template: LetterTemplate) throws {
        try validateTemplate(template)

        if let index = availableTemplates.firstIndex(where: { $0.id == template.id }) {
            availableTemplates[index] = template
        }
    }

    /// Delete template
    func deleteTemplate(templateId: UUID) {
        availableTemplates.removeAll { $0.id == templateId }
    }

    /// Reset to default templates
    func resetToDefaultTemplates() {
        loadDefaultTemplates()
    }

    // MARK: - AI-Enhanced Generation

    /// Generate AI-enhanced letter using existing AI service
    func generateAIEnhancedLetter(
        templateId: UUID,
        user: User,
        mortgageAccount: User.MortgageAccount,
        auditResults: [AuditResult],
        customFields: [String: String] = [:]
    ) async throws -> GeneratedLetter {

        // Get base letter
        let baseLetter = try await generateLetter(
            templateId: templateId,
            user: user,
            mortgageAccount: mortgageAccount,
            auditResults: auditResults,
            customFields: customFields
        )

        // Enhance with AI analysis if available
        if let aiService = try? await getAIAnalysisService() {
            let enhancedContent = try await enhanceLetterWithAI(
                content: baseLetter.content,
                auditResults: auditResults,
                aiService: aiService
            )

            // Create enhanced letter
            let enhancedFormattedContent = createAttributedString(from: enhancedContent, template: baseLetter.template)
            let enhancedPDFData = try await pdfGenerator.generatePDF(from: enhancedFormattedContent)

            return GeneratedLetter(
                template: baseLetter.template,
                context: baseLetter.context,
                content: enhancedContent,
                formattedContent: enhancedFormattedContent,
                pdfData: enhancedPDFData,
                generatedDate: Date(),
                status: .draft,
                trackingInfo: nil
            )
        }

        return baseLetter
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Monitor for template changes
        $availableTemplates
            .sink { _ in
                // Templates updated
            }
            .store(in: &cancellables)
    }

    private func loadDefaultTemplates() {
        availableTemplates = LetterTemplate.defaultTemplates()
    }

    private func validateInputs(
        user: User,
        mortgageAccount: User.MortgageAccount,
        auditResults: [AuditResult]
    ) throws {

        // Validate user data
        guard !user.firstName.isEmpty, !user.lastName.isEmpty, !user.email.isEmpty else {
            throw LetterGenerationError.invalidUserData
        }

        // Validate mortgage account
        guard !mortgageAccount.loanNumber.isEmpty, !mortgageAccount.servicerName.isEmpty else {
            throw LetterGenerationError.invalidUserData
        }

        // Validate audit results
        guard !auditResults.isEmpty else {
            throw LetterGenerationError.insufficientData
        }
    }

    private func validateRequiredFields(
        template: LetterTemplate,
        customFields: [String: String]
    ) throws {

        let missingFields = template.requiredFields
            .filter { $0.isRequired }
            .compactMap { field in
                let fieldValue = customFields[field.fieldName]
                return (fieldValue?.isEmpty ?? true) ? field.displayName : nil
            }

        if !missingFields.isEmpty {
            throw LetterGenerationError.missingRequiredFields(missingFields)
        }
    }

    private func validateTemplate(_ template: LetterTemplate) throws {
        guard !template.name.isEmpty, !template.body.isEmpty else {
            throw LetterGenerationError.templateValidationFailed
        }

        guard template.respaCompliance.isRESPACompliant || template.templateType == .resolutionConfirmation else {
            throw LetterGenerationError.templateValidationFailed
        }
    }

    private func createGenerationContext(
        user: User,
        mortgageAccount: User.MortgageAccount,
        auditResults: [AuditResult],
        customFields: [String: String],
        urgencyLevel: LetterTemplate.UrgencyLevel
    ) -> LetterGenerationContext {

        let attachments = auditResults.compactMap { result -> LetterGenerationContext.LetterAttachment? in
            guard let evidenceText = result.evidenceText else { return nil }
            return LetterGenerationContext.LetterAttachment(
                name: "Evidence_\(result.issueType.rawValue)",
                description: evidenceText,
                fileExtension: "txt",
                size: Int64(evidenceText.count),
                isRequired: false
            )
        }

        let responseDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())

        return LetterGenerationContext(
            user: user,
            mortgageAccount: mortgageAccount,
            auditResults: auditResults,
            customFields: customFields,
            attachments: attachments,
            urgencyLevel: urgencyLevel,
            requestedResponseDate: responseDate
        )
    }

    private func generateLetterContent(
        template: LetterTemplate,
        context: LetterGenerationContext
    ) async throws -> String {

        var processedContent = template.body

        // Replace all template placeholders
        processedContent = try await replacePlaceholders(content: processedContent, context: context)

        // Apply any custom processing based on template type
        processedContent = try await applyTemplateSpecificProcessing(
            content: processedContent,
            template: template,
            context: context
        )

        return processedContent
    }

    private func replacePlaceholders(
        content: String,
        context: LetterGenerationContext
    ) async throws -> String {

        var processedContent = content

        // User information
        processedContent = processedContent.replacingOccurrences(
            of: TemplatePlaceholder.userFullName.rawValue,
            with: context.user.fullName
        )
        processedContent = processedContent.replacingOccurrences(
            of: TemplatePlaceholder.userFirstName.rawValue,
            with: context.user.firstName
        )
        processedContent = processedContent.replacingOccurrences(
            of: TemplatePlaceholder.userLastName.rawValue,
            with: context.user.lastName
        )
        processedContent = processedContent.replacingOccurrences(
            of: TemplatePlaceholder.userEmail.rawValue,
            with: context.user.email
        )

        if let address = context.user.address {
            processedContent = processedContent.replacingOccurrences(
                of: TemplatePlaceholder.userAddress.rawValue,
                with: address.fullAddress
            )
        }

        if let phone = context.user.phoneNumber {
            processedContent = processedContent.replacingOccurrences(
                of: TemplatePlaceholder.userPhone.rawValue,
                with: phone
            )
        }

        // Mortgage account information
        processedContent = processedContent.replacingOccurrences(
            of: TemplatePlaceholder.servicerName.rawValue,
            with: context.mortgageAccount.servicerName
        )
        processedContent = processedContent.replacingOccurrences(
            of: TemplatePlaceholder.loanNumber.rawValue,
            with: context.mortgageAccount.loanNumber
        )
        processedContent = processedContent.replacingOccurrences(
            of: TemplatePlaceholder.propertyAddress.rawValue,
            with: context.mortgageAccount.propertyAddress
        )

        if let servicerAddress = context.mortgageAccount.servicerAddress {
            processedContent = processedContent.replacingOccurrences(
                of: TemplatePlaceholder.servicerAddress.rawValue,
                with: servicerAddress
            )
        }

        // Date information
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long

        processedContent = processedContent.replacingOccurrences(
            of: TemplatePlaceholder.currentDate.rawValue,
            with: dateFormatter.string(from: Date())
        )

        if let responseDate = context.requestedResponseDate {
            processedContent = processedContent.replacingOccurrences(
                of: TemplatePlaceholder.responseDeadline.rawValue,
                with: dateFormatter.string(from: responseDate)
            )
        }

        // Issue-specific information
        if let primaryIssue = context.auditResults.first {
            processedContent = processedContent.replacingOccurrences(
                of: TemplatePlaceholder.issueDescription.rawValue,
                with: primaryIssue.title
            )
            processedContent = processedContent.replacingOccurrences(
                of: TemplatePlaceholder.detailedExplanation.rawValue,
                with: primaryIssue.detailedExplanation
            )

            if let amount = primaryIssue.affectedAmount {
                let formattedAmount = formatCurrency(amount)
                processedContent = processedContent.replacingOccurrences(
                    of: TemplatePlaceholder.affectedAmount.rawValue,
                    with: formattedAmount
                )
            }

            if let evidence = primaryIssue.evidenceText {
                processedContent = processedContent.replacingOccurrences(
                    of: TemplatePlaceholder.evidenceText.rawValue,
                    with: evidence
                )
            }

            processedContent = processedContent.replacingOccurrences(
                of: TemplatePlaceholder.issueDate.rawValue,
                with: dateFormatter.string(from: primaryIssue.createdDate)
            )
        }

        // Calculate and format total damages
        let totalDamages = context.auditResults.compactMap { $0.affectedAmount }.reduce(0, +)
        processedContent = processedContent.replacingOccurrences(
            of: TemplatePlaceholder.totalDamages.rawValue,
            with: formatCurrency(totalDamages)
        )

        // Custom fields
        for (key, value) in context.customFields {
            processedContent = processedContent.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        return processedContent
    }

    private func applyTemplateSpecificProcessing(
        content: String,
        template: LetterTemplate,
        context: LetterGenerationContext
    ) async throws -> String {

        var processedContent = content

        // Apply template-specific logic
        switch template.templateType {
        case .noticeOfError:
            processedContent = try await enhanceNoticeOfError(content: processedContent, context: context)
        case .qualifiedWrittenRequest:
            processedContent = try await enhanceQWR(content: processedContent, context: context)
        case .escalationLetter:
            processedContent = try await enhanceEscalationLetter(content: processedContent, context: context)
        case .cfpbComplaint:
            processedContent = try await enhanceCFPBComplaint(content: processedContent, context: context)
        default:
            break
        }

        return processedContent
    }

    private func enhanceNoticeOfError(content: String, context: LetterGenerationContext) async throws -> String {
        // Add specific RESPA citations based on issue types
        var enhanced = content

        let respaViolations = context.auditResults.map { result in
            switch result.issueType {
            case .misappliedPayment:
                return "Payment application error (12 CFR § 1024.35(b)(1))"
            case .incorrectInterest:
                return "Interest calculation error (12 CFR § 1024.35(b)(2))"
            case .unauthorizedFee:
                return "Unauthorized fee assessment (12 CFR § 1024.35(b)(3))"
            case .escrowError:
                return "Escrow account error (12 CFR § 1024.35(b)(4))"
            default:
                return "Servicing error (12 CFR § 1024.35)"
            }
        }.joined(separator: "\n• ")

        enhanced = enhanced.replacingOccurrences(
            of: TemplatePlaceholder.respaSection.rawValue,
            with: "• \(respaViolations)"
        )

        return enhanced
    }

    private func enhanceQWR(content: String, context: LetterGenerationContext) async throws -> String {
        // Add specific information requests based on audit results
        var enhanced = content

        let informationRequests = context.auditResults.map { result in
            switch result.issueType {
            case .misappliedPayment:
                return "Complete payment history showing application of all payments from \(formatDate(result.createdDate)) to present"
            case .incorrectInterest:
                return "Detailed interest calculation methodology and all rate changes since loan origination"
            case .escrowError:
                return "Complete escrow account analysis including all deposits, disbursements, and shortage calculations"
            default:
                return "Complete account servicing records related to \(result.title)"
            }
        }.joined(separator: "\n")

        enhanced = enhanced.replacingOccurrences(
            of: "{{DETAILED_EXPLANATION}}",
            with: informationRequests
        )

        return enhanced
    }

    private func enhanceEscalationLetter(content: String, context: LetterGenerationContext) async throws -> String {
        // Add escalation-specific urgency and legal references
        var enhanced = content

        let violationCount = context.auditResults.count
        let daysSinceFirstIssue = Calendar.current.dateComponents([.day], from: context.auditResults.first?.createdDate ?? Date(), to: Date()).day ?? 0

        enhanced = enhanced.replacingOccurrences(
            of: "{{VIOLATION_COUNT}}",
            with: "\(violationCount)"
        )
        enhanced = enhanced.replacingOccurrences(
            of: "{{DAYS_SINCE_ISSUE}}",
            with: "\(daysSinceFirstIssue)"
        )

        return enhanced
    }

    private func enhanceCFPBComplaint(content: String, context: LetterGenerationContext) async throws -> String {
        // Add CFPB-specific formatting and requirements
        var enhanced = content

        let issueCategories = Set(context.auditResults.map { $0.issueType.displayName }).joined(separator: ", ")
        enhanced = enhanced.replacingOccurrences(
            of: "{{ISSUE_CATEGORIES}}",
            with: issueCategories
        )

        return enhanced
    }

    private func generateFormattedContent(
        template: LetterTemplate,
        context: LetterGenerationContext
    ) async throws -> NSAttributedString {

        let content = try await generateLetterContent(template: template, context: context)
        return createAttributedString(from: content, template: template)
    }

    private func createAttributedString(from text: String, template: LetterTemplate) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(template.formatOptions.lineSpacing - 1.0) * CGFloat(template.formatOptions.fontSize)
        paragraphStyle.paragraphSpacing = CGFloat(template.formatOptions.fontSize) * 0.5
        paragraphStyle.alignment = .left

        let font = UIFont(name: template.formatOptions.fontFamily, size: CGFloat(template.formatOptions.fontSize)) ??
                   UIFont.systemFont(ofSize: CGFloat(template.formatOptions.fontSize))

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: UIColor.black
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private func applySecurityToPDF(pdfData: Data, letter: GeneratedLetter) async throws -> Data {
        // Apply additional security measures using SecurityService
        return try await securityService.encryptData(pdfData)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - AI Integration

    private func getAIAnalysisService() async throws -> Any? {
        // Integration point for AI analysis service
        // This would integrate with the existing AIAnalysisService
        return nil
    }

    private func enhanceLetterWithAI(
        content: String,
        auditResults: [AuditResult],
        aiService: Any
    ) async throws -> String {
        // AI enhancement logic would go here
        // This is a placeholder for future AI integration
        return content
    }
}

// MARK: - Convenience Extensions
extension LetterGenerationService {

    /// Quick generation for single issue
    func generateQuickNoticeOfError(
        user: User,
        mortgageAccount: User.MortgageAccount,
        issue: AuditResult
    ) async throws -> GeneratedLetter {

        guard let template = availableTemplates.first(where: { $0.templateType == .noticeOfError }) else {
            throw LetterGenerationError.templateNotFound
        }

        return try await generateLetter(
            templateId: template.id,
            user: user,
            mortgageAccount: mortgageAccount,
            auditResults: [issue],
            customFields: [:],
            urgencyLevel: issue.severity == .critical ? .urgent : .standard
        )
    }

    /// Generate follow-up letter
    func generateFollowUpLetter(
        originalLetter: GeneratedLetter,
        daysSinceOriginal: Int = 30
    ) async throws -> GeneratedLetter {

        guard let followUpTemplate = availableTemplates.first(where: { $0.templateType == .followUpLetter }) else {
            throw LetterGenerationError.templateNotFound
        }

        var customFields = originalLetter.context.customFields
        customFields["ORIGINAL_DATE"] = formatDate(originalLetter.generatedDate)
        customFields["DAYS_SINCE_ORIGINAL"] = "\(daysSinceOriginal)"

        return try await generateLetter(
            templateId: followUpTemplate.id,
            user: originalLetter.context.user,
            mortgageAccount: originalLetter.context.mortgageAccount,
            auditResults: originalLetter.context.auditResults,
            customFields: customFields,
            urgencyLevel: .elevated
        )
    }

    /// Get letter generation statistics
    func getGenerationStatistics() -> (total: Int, byType: [LetterTemplate.TemplateType: Int], byStatus: [GeneratedLetter.LetterStatus: Int]) {
        let total = generatedLetters.count

        let byType = Dictionary(grouping: generatedLetters) { $0.template.templateType }
            .mapValues { $0.count }

        let byStatus = Dictionary(grouping: generatedLetters) { $0.status }
            .mapValues { $0.count }

        return (total, byType, byStatus)
    }
}