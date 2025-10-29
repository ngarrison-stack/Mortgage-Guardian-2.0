import Foundation

/// Utility class for loading letter templates from bundle resources
class TemplateLoader {

    static let shared = TemplateLoader()

    private init() {}

    /// Load template content from bundle resources
    func loadTemplate(named templateName: String) -> String? {
        guard let url = Bundle.main.url(forResource: templateName, withExtension: "txt", subdirectory: "LetterTemplates"),
              let content = try? String(contentsOf: url) else {
            print("Failed to load template: \(templateName)")
            return nil
        }
        return content
    }

    /// Load all available templates from bundle
    func loadAllTemplates() -> [String: String] {
        var templates: [String: String] = [:]

        let templateNames = [
            "NoticeOfError_Standard",
            "QualifiedWrittenRequest_Standard",
            "EscalationLetter_Executive",
            "CFPBComplaint_Formal",
            "FollowUpLetter_30Day"
        ]

        for templateName in templateNames {
            if let content = loadTemplate(named: templateName) {
                templates[templateName] = content
            }
        }

        return templates
    }

    /// Create LetterTemplate objects from bundle resources
    func createTemplatesFromBundle() -> [LetterTemplate] {
        var templates: [LetterTemplate] = []

        // Notice of Error Template
        if let content = loadTemplate(named: "NoticeOfError_Standard") {
            let template = LetterTemplate(
                templateType: .noticeOfError,
                name: "Standard Notice of Error",
                version: "1.0",
                title: "Notice of Error Under RESPA Section 1024.35",
                subject: "Notice of Error - Loan Number {{LOAN_NUMBER}}",
                body: content,
                legalCitations: [
                    "12 CFR § 1024.35 - Error resolution procedures",
                    "12 U.S.C. § 2605 - Mortgage servicing requirements"
                ],
                requiredFields: [
                    LetterTemplate.RequiredField(
                        fieldName: "issue_description",
                        displayName: "Issue Description",
                        fieldType: .multilineText,
                        isRequired: true,
                        placeholder: "Describe the specific error",
                        validation: .required
                    ),
                    LetterTemplate.RequiredField(
                        fieldName: "detailed_explanation",
                        displayName: "Detailed Explanation",
                        fieldType: .multilineText,
                        isRequired: true,
                        placeholder: "Provide detailed explanation with dates and amounts",
                        validation: .required
                    )
                ],
                respaCompliance: LetterTemplate.RESPACompliance(
                    isRESPACompliant: true,
                    regulationSection: "12 CFR § 1024.35",
                    requiredDisclosures: ["Error identification", "Correction request"],
                    responseTimelineDays: 30,
                    legalRequirements: ["Written format", "Specific error identification"],
                    citedRegulations: [
                        LetterTemplate.RESPACompliance.LegalCitation(
                            regulation: "RESPA",
                            section: "12 CFR § 1024.35",
                            description: "Error resolution procedures",
                            url: "https://www.ecfr.gov/current/title-12/chapter-X/part-1024/section-1024.35"
                        )
                    ]
                ),
                formatOptions: createStandardFormatOptions(),
                createdDate: Date(),
                lastUpdated: Date(),
                isActive: true
            )
            templates.append(template)
        }

        // Qualified Written Request Template
        if let content = loadTemplate(named: "QualifiedWrittenRequest_Standard") {
            let template = LetterTemplate(
                templateType: .qualifiedWrittenRequest,
                name: "Standard Qualified Written Request",
                version: "1.0",
                title: "Qualified Written Request Under RESPA Section 1024.36",
                subject: "Qualified Written Request - Loan Number {{LOAN_NUMBER}}",
                body: content,
                legalCitations: [
                    "12 CFR § 1024.36 - Requests for information"
                ],
                requiredFields: [
                    LetterTemplate.RequiredField(
                        fieldName: "information_requested",
                        displayName: "Information Requested",
                        fieldType: .multilineText,
                        isRequired: true,
                        placeholder: "Describe the specific information needed",
                        validation: .required
                    )
                ],
                respaCompliance: LetterTemplate.RESPACompliance(
                    isRESPACompliant: true,
                    regulationSection: "12 CFR § 1024.36",
                    requiredDisclosures: ["Information request", "Account information"],
                    responseTimelineDays: 30,
                    legalRequirements: ["Written format", "Sufficient detail"],
                    citedRegulations: [
                        LetterTemplate.RESPACompliance.LegalCitation(
                            regulation: "RESPA",
                            section: "12 CFR § 1024.36",
                            description: "Requests for information",
                            url: "https://www.ecfr.gov/current/title-12/chapter-X/part-1024/section-1024.36"
                        )
                    ]
                ),
                formatOptions: createStandardFormatOptions(),
                createdDate: Date(),
                lastUpdated: Date(),
                isActive: true
            )
            templates.append(template)
        }

        // Escalation Letter Template
        if let content = loadTemplate(named: "EscalationLetter_Executive") {
            let template = LetterTemplate(
                templateType: .escalationLetter,
                name: "Executive Escalation Letter",
                version: "1.0",
                title: "Executive Escalation of RESPA Violation",
                subject: "URGENT: Executive Escalation - RESPA Violation {{LOAN_NUMBER}}",
                body: content,
                legalCitations: [
                    "12 CFR § 1024.35 - Error resolution procedures",
                    "12 U.S.C. § 2605 - Servicer obligations"
                ],
                requiredFields: [
                    LetterTemplate.RequiredField(
                        fieldName: "original_date",
                        displayName: "Original Notice Date",
                        fieldType: .date,
                        isRequired: true,
                        placeholder: "Date of original notice",
                        validation: .required
                    ),
                    LetterTemplate.RequiredField(
                        fieldName: "days_since_issue",
                        displayName: "Days Since Original Notice",
                        fieldType: .number,
                        isRequired: true,
                        placeholder: "Number of days",
                        validation: .required
                    )
                ],
                respaCompliance: LetterTemplate.RESPACompliance(
                    isRESPACompliant: true,
                    regulationSection: "12 CFR § 1024.35",
                    requiredDisclosures: ["Previous notice reference", "Escalation reason"],
                    responseTimelineDays: 7,
                    legalRequirements: ["Executive escalation", "Urgency indication"],
                    citedRegulations: [
                        LetterTemplate.RESPACompliance.LegalCitation(
                            regulation: "RESPA",
                            section: "12 CFR § 1024.35",
                            description: "Error resolution procedures",
                            url: "https://www.ecfr.gov/current/title-12/chapter-X/part-1024/section-1024.35"
                        )
                    ]
                ),
                formatOptions: createUrgentFormatOptions(),
                createdDate: Date(),
                lastUpdated: Date(),
                isActive: true
            )
            templates.append(template)
        }

        // CFPB Complaint Template
        if let content = loadTemplate(named: "CFPBComplaint_Formal") {
            let template = LetterTemplate(
                templateType: .cfpbComplaint,
                name: "CFPB Formal Complaint",
                version: "1.0",
                title: "Consumer Complaint to CFPB",
                subject: "Formal CFPB Complaint - {{SERVICER_NAME}}",
                body: content,
                legalCitations: [
                    "12 CFR § 1024.35 - Error resolution procedures",
                    "12 U.S.C. § 5481 - Consumer Financial Protection Act"
                ],
                requiredFields: [
                    LetterTemplate.RequiredField(
                        fieldName: "violation_details",
                        displayName: "Violation Details",
                        fieldType: .multilineText,
                        isRequired: true,
                        placeholder: "Detailed description of violations",
                        validation: .required
                    )
                ],
                respaCompliance: LetterTemplate.RESPACompliance(
                    isRESPACompliant: true,
                    regulationSection: "Consumer Financial Protection Act",
                    requiredDisclosures: ["Company information", "Violation details"],
                    responseTimelineDays: 15,
                    legalRequirements: ["Formal complaint format", "Supporting documentation"],
                    citedRegulations: [
                        LetterTemplate.RESPACompliance.LegalCitation(
                            regulation: "CFPA",
                            section: "12 U.S.C. § 5481",
                            description: "Consumer Financial Protection Act",
                            url: "https://www.law.cornell.edu/uscode/text/12/5481"
                        )
                    ]
                ),
                formatOptions: createFormalFormatOptions(),
                createdDate: Date(),
                lastUpdated: Date(),
                isActive: true
            )
            templates.append(template)
        }

        // Follow-up Letter Template
        if let content = loadTemplate(named: "FollowUpLetter_30Day") {
            let template = LetterTemplate(
                templateType: .followUpLetter,
                name: "30-Day Follow-up Letter",
                version: "1.0",
                title: "Follow-up on Unresolved RESPA Violation",
                subject: "FOLLOW-UP: Unresolved RESPA Violation {{LOAN_NUMBER}}",
                body: content,
                legalCitations: [
                    "12 CFR § 1024.35 - Error resolution procedures",
                    "12 U.S.C. § 2605(f) - Civil liability"
                ],
                requiredFields: [
                    LetterTemplate.RequiredField(
                        fieldName: "original_date",
                        displayName: "Original Notice Date",
                        fieldType: .date,
                        isRequired: true,
                        placeholder: "Date of original notice",
                        validation: .required
                    ),
                    LetterTemplate.RequiredField(
                        fieldName: "days_since_original",
                        displayName: "Days Since Original",
                        fieldType: .number,
                        isRequired: true,
                        placeholder: "Number of days",
                        validation: .required
                    )
                ],
                respaCompliance: LetterTemplate.RESPACompliance(
                    isRESPACompliant: true,
                    regulationSection: "12 CFR § 1024.35",
                    requiredDisclosures: ["Follow-up notification", "Legal consequences"],
                    responseTimelineDays: 7,
                    legalRequirements: ["Reference to original notice", "Urgency escalation"],
                    citedRegulations: [
                        LetterTemplate.RESPACompliance.LegalCitation(
                            regulation: "RESPA",
                            section: "12 CFR § 1024.35",
                            description: "Error resolution procedures",
                            url: "https://www.ecfr.gov/current/title-12/chapter-X/part-1024/section-1024.35"
                        )
                    ]
                ),
                formatOptions: createUrgentFormatOptions(),
                createdDate: Date(),
                lastUpdated: Date(),
                isActive: true
            )
            templates.append(template)
        }

        return templates
    }

    // MARK: - Format Options

    private func createStandardFormatOptions() -> LetterTemplate.FormatOptions {
        return LetterTemplate.FormatOptions(
            fontFamily: "Times New Roman",
            fontSize: 12.0,
            lineSpacing: 1.15,
            margins: LetterTemplate.FormatOptions.Margins(
                top: 72, bottom: 72, left: 72, right: 72
            ),
            headerStyle: LetterTemplate.FormatOptions.HeaderStyle(
                includeLogo: false,
                includeUserAddress: true,
                includeDate: true,
                includeSubject: true,
                alignment: .left
            ),
            includeLetterhead: true,
            includeSignatureLine: true,
            includeAttachmentsList: true,
            includeDeliveryConfirmation: false
        )
    }

    private func createUrgentFormatOptions() -> LetterTemplate.FormatOptions {
        return LetterTemplate.FormatOptions(
            fontFamily: "Times New Roman",
            fontSize: 12.0,
            lineSpacing: 1.1,
            margins: LetterTemplate.FormatOptions.Margins(
                top: 72, bottom: 72, left: 72, right: 72
            ),
            headerStyle: LetterTemplate.FormatOptions.HeaderStyle(
                includeLogo: false,
                includeUserAddress: true,
                includeDate: true,
                includeSubject: true,
                alignment: .left
            ),
            includeLetterhead: true,
            includeSignatureLine: true,
            includeAttachmentsList: true,
            includeDeliveryConfirmation: true
        )
    }

    private func createFormalFormatOptions() -> LetterTemplate.FormatOptions {
        return LetterTemplate.FormatOptions(
            fontFamily: "Times New Roman",
            fontSize: 11.0,
            lineSpacing: 1.2,
            margins: LetterTemplate.FormatOptions.Margins(
                top: 72, bottom: 72, left: 72, right: 72
            ),
            headerStyle: LetterTemplate.FormatOptions.HeaderStyle(
                includeLogo: false,
                includeUserAddress: true,
                includeDate: true,
                includeSubject: true,
                alignment: .left
            ),
            includeLetterhead: true,
            includeSignatureLine: true,
            includeAttachmentsList: true,
            includeDeliveryConfirmation: false
        )
    }
}