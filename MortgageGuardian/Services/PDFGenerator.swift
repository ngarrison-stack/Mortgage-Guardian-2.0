import Foundation
import UIKit
import PDFKit
import UniformTypeIdentifiers

/// Professional PDF generation service for mortgage letters and documents
@MainActor
class PDFGenerator: ObservableObject {

    // MARK: - Properties
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0.0

    private let securityService = SecurityService.shared

    // MARK: - PDF Generation Errors
    enum PDFGenerationError: LocalizedError {
        case templateNotFound
        case invalidContent
        case generationFailed
        case securityError
        case insufficientMemory
        case invalidConfiguration

        var errorDescription: String? {
            switch self {
            case .templateNotFound:
                return "Letter template not found"
            case .invalidContent:
                return "Invalid letter content provided"
            case .generationFailed:
                return "Failed to generate PDF document"
            case .securityError:
                return "Security validation failed"
            case .insufficientMemory:
                return "Insufficient memory for PDF generation"
            case .invalidConfiguration:
                return "Invalid PDF configuration"
            }
        }
    }

    // MARK: - PDF Configuration
    struct PDFConfiguration {
        let pageSize: CGSize
        let margins: UIEdgeInsets
        let fontSize: CGFloat
        let fontName: String
        let lineSpacing: CGFloat
        let includeWatermark: Bool
        let includePageNumbers: Bool
        let includeHeader: Bool
        let includeFooter: Bool
        let protection: PDFProtection?

        static let standard = PDFConfiguration(
            pageSize: CGSize(width: 612, height: 792), // 8.5 x 11 inches at 72 DPI
            margins: UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72), // 1 inch margins
            fontSize: 12.0,
            fontName: "Times-Roman",
            lineSpacing: 1.15,
            includeWatermark: false,
            includePageNumbers: true,
            includeHeader: true,
            includeFooter: true,
            protection: nil
        )

        static let legal = PDFConfiguration(
            pageSize: CGSize(width: 612, height: 1008), // 8.5 x 14 inches at 72 DPI
            margins: UIEdgeInsets(top: 72, left: 90, bottom: 72, right: 72), // Larger left margin for binding
            fontSize: 12.0,
            fontName: "Times-Roman",
            lineSpacing: 1.2,
            includeWatermark: false,
            includePageNumbers: true,
            includeHeader: true,
            includeFooter: true,
            protection: PDFProtection(
                userPassword: nil,
                ownerPassword: UUID().uuidString,
                allowsPrinting: true,
                allowsCopying: false,
                allowsDocumentAssembly: false,
                allowsContentAccessibility: true
            )
        )
    }

    struct PDFProtection {
        let userPassword: String?
        let ownerPassword: String
        let allowsPrinting: Bool
        let allowsCopying: Bool
        let allowsDocumentAssembly: Bool
        let allowsContentAccessibility: Bool
    }

    // MARK: - Public Methods

    /// Generate PDF from letter template and context
    func generateLetterPDF(
        template: LetterTemplate,
        context: LetterGenerationContext,
        configuration: PDFConfiguration = .standard
    ) async throws -> Data {

        isGenerating = true
        generationProgress = 0.0
        defer {
            isGenerating = false
            generationProgress = 0.0
        }

        do {
            // Validate inputs
            try validateInputs(template: template, context: context, configuration: configuration)
            generationProgress = 0.1

            // Generate formatted content
            let formattedContent = try await generateFormattedContent(template: template, context: context)
            generationProgress = 0.3

            // Create PDF document
            let pdfData = try await createPDF(
                content: formattedContent,
                template: template,
                context: context,
                configuration: configuration
            )
            generationProgress = 0.9

            // Apply security if needed
            let securedPDF = try await applySecurityIfNeeded(pdfData: pdfData, configuration: configuration)
            generationProgress = 1.0

            return securedPDF

        } catch {
            throw PDFGenerationError.generationFailed
        }
    }

    /// Generate PDF from pre-formatted attributed string
    func generatePDF(
        from attributedString: NSAttributedString,
        configuration: PDFConfiguration = .standard,
        title: String = "Document"
    ) async throws -> Data {

        isGenerating = true
        generationProgress = 0.0
        defer {
            isGenerating = false
            generationProgress = 0.0
        }

        do {
            let pdfData = try await createPDFFromAttributedString(
                attributedString: attributedString,
                configuration: configuration,
                title: title
            )
            generationProgress = 1.0
            return pdfData
        } catch {
            throw PDFGenerationError.generationFailed
        }
    }

    /// Create printable PDF with enhanced formatting
    func generatePrintablePDF(
        template: LetterTemplate,
        context: LetterGenerationContext
    ) async throws -> Data {

        let printConfiguration = PDFConfiguration(
            pageSize: CGSize(width: 612, height: 792),
            margins: UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72),
            fontSize: 11.0,
            fontName: "Times-Roman",
            lineSpacing: 1.1,
            includeWatermark: false,
            includePageNumbers: true,
            includeHeader: true,
            includeFooter: true,
            protection: nil
        )

        return try await generateLetterPDF(
            template: template,
            context: context,
            configuration: printConfiguration
        )
    }

    // MARK: - Private Methods

    private func validateInputs(
        template: LetterTemplate,
        context: LetterGenerationContext,
        configuration: PDFConfiguration
    ) throws {

        guard !template.body.isEmpty else {
            throw PDFGenerationError.templateNotFound
        }

        guard configuration.pageSize.width > 0 && configuration.pageSize.height > 0 else {
            throw PDFGenerationError.invalidConfiguration
        }

        guard configuration.fontSize > 0 && configuration.fontSize <= 72 else {
            throw PDFGenerationError.invalidConfiguration
        }
    }

    private func generateFormattedContent(
        template: LetterTemplate,
        context: LetterGenerationContext
    ) async throws -> NSAttributedString {

        // Replace template placeholders with actual values
        var processedContent = template.body

        // User information replacements
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

        // Mortgage account replacements
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

        // Date replacements
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

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

        // Issue-specific replacements
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
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = .currency
                numberFormatter.currencyCode = "USD"
                let formattedAmount = numberFormatter.string(from: NSNumber(value: amount)) ?? "$0.00"

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
        }

        // Calculate total damages
        let totalDamages = context.auditResults.compactMap { $0.affectedAmount }.reduce(0, +)
        if totalDamages > 0 {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .currency
            numberFormatter.currencyCode = "USD"
            let formattedTotal = numberFormatter.string(from: NSNumber(value: totalDamages)) ?? "$0.00"

            processedContent = processedContent.replacingOccurrences(
                of: TemplatePlaceholder.totalDamages.rawValue,
                with: formattedTotal
            )
        }

        // Legal citations
        let citations = template.legalCitations.joined(separator: "\n• ")
        processedContent = processedContent.replacingOccurrences(
            of: TemplatePlaceholder.legalCitations.rawValue,
            with: "• \(citations)"
        )

        // Custom field replacements
        for (key, value) in context.customFields {
            processedContent = processedContent.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        // Create attributed string with proper formatting
        return createAttributedString(from: processedContent, formatOptions: template.formatOptions)
    }

    private func createAttributedString(
        from text: String,
        formatOptions: LetterTemplate.FormatOptions
    ) -> NSAttributedString {

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(formatOptions.lineSpacing - 1.0) * CGFloat(formatOptions.fontSize)
        paragraphStyle.paragraphSpacing = CGFloat(formatOptions.fontSize) * 0.5
        paragraphStyle.alignment = .left

        let font = UIFont(name: formatOptions.fontFamily, size: CGFloat(formatOptions.fontSize)) ??
                   UIFont.systemFont(ofSize: CGFloat(formatOptions.fontSize))

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: UIColor.black
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private func createPDF(
        content: NSAttributedString,
        template: LetterTemplate,
        context: LetterGenerationContext,
        configuration: PDFConfiguration
    ) async throws -> Data {

        let pdfMetaData = [
            kCGPDFContextCreator: "Mortgage Guardian",
            kCGPDFContextAuthor: context.user.fullName,
            kCGPDFContextTitle: template.title,
            kCGPDFContextSubject: "RESPA Correspondence",
            kCGPDFContextKeywords: ["RESPA", "Mortgage", "Notice of Error", "Consumer Rights"]
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: configuration.pageSize),
            format: format
        )

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let pdfData = renderer.pdfData { context in
                        self.renderPDFContent(
                            content: content,
                            template: template,
                            context: context,
                            configuration: configuration,
                            userContext: userContext
                        )
                    }
                    continuation.resume(returning: pdfData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func createPDFFromAttributedString(
        attributedString: NSAttributedString,
        configuration: PDFConfiguration,
        title: String
    ) async throws -> Data {

        let pdfMetaData = [
            kCGPDFContextCreator: "Mortgage Guardian",
            kCGPDFContextTitle: title,
            kCGPDFContextSubject: "Generated Document"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: configuration.pageSize),
            format: format
        )

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let pdfData = renderer.pdfData { context in
                        self.renderSimplePDFContent(
                            attributedString: attributedString,
                            context: context,
                            configuration: configuration
                        )
                    }
                    continuation.resume(returning: pdfData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func renderPDFContent(
        content: NSAttributedString,
        template: LetterTemplate,
        context: UIGraphicsPDFRendererContext,
        configuration: PDFConfiguration,
        userContext: LetterGenerationContext
    ) {

        var currentY: CGFloat = configuration.margins.top
        let contentWidth = configuration.pageSize.width - configuration.margins.left - configuration.margins.right
        let contentRect = CGRect(
            x: configuration.margins.left,
            y: currentY,
            width: contentWidth,
            height: configuration.pageSize.height - configuration.margins.top - configuration.margins.bottom
        )

        // Start first page
        context.beginPage()

        // Add header if enabled
        if configuration.includeHeader {
            currentY = renderHeader(
                template: template,
                userContext: userContext,
                configuration: configuration,
                currentY: currentY,
                contentWidth: contentWidth
            )
        }

        // Render main content
        let textRect = CGRect(
            x: configuration.margins.left,
            y: currentY,
            width: contentWidth,
            height: configuration.pageSize.height - currentY - configuration.margins.bottom
        )

        let textRange = NSRange(location: 0, length: content.length)
        let framesetter = CTFramesetterCreateWithAttributedString(content)

        var currentLocation = 0
        var pageNumber = 1

        while currentLocation < content.length {
            let path = CGPath(rect: textRect, transform: nil)
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: currentLocation, length: 0),
                path,
                nil
            )

            // Draw the frame
            guard let cgContext = UIGraphicsGetCurrentContext() else { continue }
            CTFrameDraw(frame, cgContext)

            // Add footer if enabled
            if configuration.includeFooter {
                renderFooter(
                    configuration: configuration,
                    pageNumber: pageNumber,
                    contentWidth: contentWidth
                )
            }

            // Check if there's more content
            let frameRange = CTFrameGetVisibleStringRange(frame)
            currentLocation = frameRange.location + frameRange.length

            if currentLocation < content.length {
                context.beginPage()
                pageNumber += 1
                currentY = configuration.margins.top

                // Add header to subsequent pages
                if configuration.includeHeader {
                    currentY = renderHeader(
                        template: template,
                        userContext: userContext,
                        configuration: configuration,
                        currentY: currentY,
                        contentWidth: contentWidth
                    )
                }
            }
        }
    }

    private func renderSimplePDFContent(
        attributedString: NSAttributedString,
        context: UIGraphicsPDFRendererContext,
        configuration: PDFConfiguration
    ) {

        context.beginPage()

        let contentWidth = configuration.pageSize.width - configuration.margins.left - configuration.margins.right
        let contentHeight = configuration.pageSize.height - configuration.margins.top - configuration.margins.bottom

        let textRect = CGRect(
            x: configuration.margins.left,
            y: configuration.margins.top,
            width: contentWidth,
            height: contentHeight
        )

        attributedString.draw(in: textRect)
    }

    private func renderHeader(
        template: LetterTemplate,
        userContext: LetterGenerationContext,
        configuration: PDFConfiguration,
        currentY: CGFloat,
        contentWidth: CGFloat
    ) -> CGFloat {

        var y = currentY
        let headerSpacing: CGFloat = 10

        // User's return address
        if template.formatOptions.headerStyle.includeUserAddress,
           let address = userContext.user.address {

            let addressText = """
            \(userContext.user.fullName)
            \(address.street)
            \(address.city), \(address.state) \(address.zipCode)
            """

            let addressAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: configuration.fontSize - 1),
                .foregroundColor: UIColor.black
            ]

            let addressString = NSAttributedString(string: addressText, attributes: addressAttributes)
            let addressRect = CGRect(x: configuration.margins.left, y: y, width: contentWidth, height: 100)
            addressString.draw(in: addressRect)

            y += 80 + headerSpacing
        }

        // Date
        if template.formatOptions.headerStyle.includeDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long

            let dateText = dateFormatter.string(from: Date())
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: configuration.fontSize),
                .foregroundColor: UIColor.black
            ]

            let dateString = NSAttributedString(string: dateText, attributes: dateAttributes)
            let dateRect = CGRect(x: configuration.margins.left, y: y, width: contentWidth, height: 20)
            dateString.draw(in: dateRect)

            y += 30 + headerSpacing
        }

        return y
    }

    private func renderFooter(
        configuration: PDFConfiguration,
        pageNumber: Int,
        contentWidth: CGFloat
    ) {

        if configuration.includePageNumbers {
            let footerY = configuration.pageSize.height - configuration.margins.bottom + 10

            let pageText = "Page \(pageNumber)"
            let pageAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: configuration.fontSize - 2),
                .foregroundColor: UIColor.gray
            ]

            let pageString = NSAttributedString(string: pageText, attributes: pageAttributes)
            let pageRect = CGRect(
                x: configuration.margins.left,
                y: footerY,
                width: contentWidth,
                height: 20
            )

            pageString.draw(in: pageRect)
        }
    }

    private func applySecurityIfNeeded(
        pdfData: Data,
        configuration: PDFConfiguration
    ) async throws -> Data {

        guard let protection = configuration.protection else {
            return pdfData
        }

        // Apply PDF security using PDFDocument
        guard let pdfDocument = PDFDocument(data: pdfData) else {
            throw PDFGenerationError.securityError
        }

        // Set document permissions
        if !protection.allowsCopying {
            // Note: PDFKit on iOS has limited security features
            // For production use, consider using a more robust PDF security library
        }

        // For basic protection, we'll return the original data
        // In a production app, you might want to use a third-party library
        // or server-side PDF processing for advanced security features
        return pdfData
    }
}

// MARK: - Convenience Extensions
extension PDFGenerator {

    /// Quick PDF generation for simple text
    static func generateSimplePDF(
        text: String,
        title: String = "Document",
        fontSize: CGFloat = 12
    ) async throws -> Data {

        let generator = PDFGenerator()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor.black
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)

        return try await generator.generatePDF(
            from: attributedString,
            configuration: .standard,
            title: title
        )
    }

    /// Generate PDF with custom configuration
    static func generateCustomPDF(
        template: LetterTemplate,
        context: LetterGenerationContext,
        pageSize: CGSize = CGSize(width: 612, height: 792),
        margins: UIEdgeInsets = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72),
        fontSize: CGFloat = 12
    ) async throws -> Data {

        let generator = PDFGenerator()

        let configuration = PDFConfiguration(
            pageSize: pageSize,
            margins: margins,
            fontSize: fontSize,
            fontName: template.formatOptions.fontFamily,
            lineSpacing: CGFloat(template.formatOptions.lineSpacing),
            includeWatermark: false,
            includePageNumbers: true,
            includeHeader: template.formatOptions.includeLetterhead,
            includeFooter: true,
            protection: nil
        )

        return try await generator.generateLetterPDF(
            template: template,
            context: context,
            configuration: configuration
        )
    }
}

// MARK: - PDF Export Utilities
extension PDFGenerator {

    /// Save PDF to Documents directory
    func savePDFToDocuments(
        pdfData: Data,
        filename: String
    ) async throws -> URL {

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(filename).pdf")

        try pdfData.write(to: fileURL)
        return fileURL
    }

    /// Share PDF using UIActivityViewController
    func sharePDF(
        pdfData: Data,
        filename: String,
        from viewController: UIViewController
    ) {

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(filename).pdf")

        do {
            try pdfData.write(to: tempURL)

            let activityViewController = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )

            // Configure for iPad
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            viewController.present(activityViewController, animated: true)

        } catch {
            print("Error sharing PDF: \(error)")
        }
    }
}