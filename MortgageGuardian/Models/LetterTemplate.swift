import Foundation
import SwiftUI

/// Represents a letter template for generating RESPA-compliant correspondence
struct LetterTemplate: Identifiable, Codable {
    let id = UUID()
    let templateType: TemplateType
    let name: String
    let version: String
    let title: String
    let subject: String
    let body: String
    let legalCitations: [String]
    let requiredFields: [RequiredField]
    let respaCompliance: RESPACompliance
    let formatOptions: FormatOptions
    let createdDate: Date
    let lastUpdated: Date
    let isActive: Bool

    enum TemplateType: String, CaseIterable, Codable {
        case noticeOfError = "notice_of_error"
        case qualifiedWrittenRequest = "qualified_written_request"
        case escalationLetter = "escalation_letter"
        case cfpbComplaint = "cfpb_complaint"
        case stateRegulatorComplaint = "state_regulator_complaint"
        case executiveComplaint = "executive_complaint"
        case followUpLetter = "follow_up_letter"
        case demandLetter = "demand_letter"
        case resolutionConfirmation = "resolution_confirmation"

        var displayName: String {
            switch self {
            case .noticeOfError:
                return "Notice of Error"
            case .qualifiedWrittenRequest:
                return "Qualified Written Request"
            case .escalationLetter:
                return "Escalation Letter"
            case .cfpbComplaint:
                return "CFPB Complaint"
            case .stateRegulatorComplaint:
                return "State Regulator Complaint"
            case .executiveComplaint:
                return "Executive Complaint"
            case .followUpLetter:
                return "Follow-up Letter"
            case .demandLetter:
                return "Demand Letter"
            case .resolutionConfirmation:
                return "Resolution Confirmation"
            }
        }

        var description: String {
            switch self {
            case .noticeOfError:
                return "Formal notification of errors in mortgage account servicing"
            case .qualifiedWrittenRequest:
                return "Request for detailed information about your mortgage account"
            case .escalationLetter:
                return "Escalation to higher authority for unresolved issues"
            case .cfpbComplaint:
                return "Complaint to Consumer Financial Protection Bureau"
            case .stateRegulatorComplaint:
                return "Complaint to state mortgage regulator"
            case .executiveComplaint:
                return "Direct complaint to servicer executive leadership"
            case .followUpLetter:
                return "Follow-up on previously submitted complaints"
            case .demandLetter:
                return "Formal demand for corrective action"
            case .resolutionConfirmation:
                return "Confirmation of issue resolution"
            }
        }

        var urgencyLevel: UrgencyLevel {
            switch self {
            case .noticeOfError, .qualifiedWrittenRequest:
                return .standard
            case .escalationLetter, .followUpLetter:
                return .elevated
            case .cfpbComplaint, .stateRegulatorComplaint, .executiveComplaint:
                return .high
            case .demandLetter:
                return .urgent
            case .resolutionConfirmation:
                return .low
            }
        }
    }

    enum UrgencyLevel: String, Codable {
        case low = "low"
        case standard = "standard"
        case elevated = "elevated"
        case high = "high"
        case urgent = "urgent"

        var color: Color {
            switch self {
            case .low:
                return .gray
            case .standard:
                return .blue
            case .elevated:
                return .orange
            case .high:
                return .red
            case .urgent:
                return .purple
            }
        }
    }

    struct RequiredField: Codable {
        let fieldName: String
        let displayName: String
        let fieldType: FieldType
        let isRequired: Bool
        let placeholder: String?
        let validation: ValidationRule?

        enum FieldType: String, Codable {
            case text = "text"
            case number = "number"
            case currency = "currency"
            case date = "date"
            case email = "email"
            case phone = "phone"
            case address = "address"
            case loanNumber = "loan_number"
            case multilineText = "multiline_text"
        }

        enum ValidationRule: String, Codable {
            case email = "email"
            case phone = "phone"
            case zipCode = "zip_code"
            case currency = "currency"
            case loanNumber = "loan_number"
            case required = "required"
            case maxLength = "max_length"
            case minLength = "min_length"
        }
    }

    struct RESPACompliance: Codable {
        let isRESPACompliant: Bool
        let regulationSection: String?
        let requiredDisclosures: [String]
        let responseTimelineDays: Int?
        let legalRequirements: [String]
        let citedRegulations: [LegalCitation]

        struct LegalCitation: Codable {
            let regulation: String
            let section: String
            let description: String
            let url: String?
        }
    }

    struct FormatOptions: Codable {
        let fontFamily: String
        let fontSize: Double
        let lineSpacing: Double
        let margins: Margins
        let headerStyle: HeaderStyle
        let includeLetterhead: Bool
        let includeSignatureLine: Bool
        let includeAttachmentsList: Bool
        let includeDeliveryConfirmation: Bool

        struct Margins: Codable {
            let top: Double
            let bottom: Double
            let left: Double
            let right: Double
        }

        struct HeaderStyle: Codable {
            let includeLogo: Bool
            let includeUserAddress: Bool
            let includeDate: Bool
            let includeSubject: Bool
            let alignment: TextAlignment
        }

        enum TextAlignment: String, Codable {
            case left = "left"
            case center = "center"
            case right = "right"
        }
    }
}

// MARK: - Letter Generation Context
struct LetterGenerationContext {
    let user: User
    let mortgageAccount: User.MortgageAccount
    let auditResults: [AuditResult]
    let customFields: [String: String]
    let attachments: [LetterAttachment]
    let urgencyLevel: LetterTemplate.UrgencyLevel
    let requestedResponseDate: Date?

    struct LetterAttachment {
        let id = UUID()
        let name: String
        let description: String
        let fileExtension: String
        let size: Int64
        let isRequired: Bool
    }
}

// MARK: - Generated Letter
struct GeneratedLetter: Identifiable {
    let id = UUID()
    let template: LetterTemplate
    let context: LetterGenerationContext
    let content: String
    let formattedContent: NSAttributedString
    let pdfData: Data?
    let generatedDate: Date
    let status: LetterStatus
    let trackingInfo: TrackingInfo?

    enum LetterStatus: String, CaseIterable, Codable {
        case draft = "draft"
        case ready = "ready"
        case sent = "sent"
        case acknowledged = "acknowledged"
        case responded = "responded"
        case resolved = "resolved"
        case escalated = "escalated"

        var displayName: String {
            switch self {
            case .draft:
                return "Draft"
            case .ready:
                return "Ready to Send"
            case .sent:
                return "Sent"
            case .acknowledged:
                return "Acknowledged"
            case .responded:
                return "Response Received"
            case .resolved:
                return "Resolved"
            case .escalated:
                return "Escalated"
            }
        }

        var color: Color {
            switch self {
            case .draft:
                return .gray
            case .ready:
                return .blue
            case .sent:
                return .orange
            case .acknowledged:
                return .yellow
            case .responded:
                return .green
            case .resolved:
                return .green
            case .escalated:
                return .red
            }
        }
    }

    struct TrackingInfo: Codable {
        let sentDate: Date?
        let deliveryMethod: DeliveryMethod
        let trackingNumber: String?
        let expectedResponseDate: Date?
        let actualResponseDate: Date?
        let responseReceived: Bool

        enum DeliveryMethod: String, CaseIterable, Codable {
            case email = "email"
            case certifiedMail = "certified_mail"
            case registeredMail = "registered_mail"
            case regularMail = "regular_mail"
            case fax = "fax"
            case onlinePortal = "online_portal"

            var displayName: String {
                switch self {
                case .email:
                    return "Email"
                case .certifiedMail:
                    return "Certified Mail"
                case .registeredMail:
                    return "Registered Mail"
                case .regularMail:
                    return "Regular Mail"
                case .fax:
                    return "Fax"
                case .onlinePortal:
                    return "Online Portal"
                }
            }
        }
    }
}

// MARK: - Template Placeholders
enum TemplatePlaceholder: String, CaseIterable {
    // User Information
    case userFullName = "{{USER_FULL_NAME}}"
    case userFirstName = "{{USER_FIRST_NAME}}"
    case userLastName = "{{USER_LAST_NAME}}"
    case userAddress = "{{USER_ADDRESS}}"
    case userEmail = "{{USER_EMAIL}}"
    case userPhone = "{{USER_PHONE}}"

    // Servicer Information
    case servicerName = "{{SERVICER_NAME}}"
    case servicerAddress = "{{SERVICER_ADDRESS}}"
    case loanNumber = "{{LOAN_NUMBER}}"
    case propertyAddress = "{{PROPERTY_ADDRESS}}"

    // Date Information
    case currentDate = "{{CURRENT_DATE}}"
    case responseDeadline = "{{RESPONSE_DEADLINE}}"
    case issueDate = "{{ISSUE_DATE}}"

    // Issue Details
    case issueDescription = "{{ISSUE_DESCRIPTION}}"
    case detailedExplanation = "{{DETAILED_EXPLANATION}}"
    case affectedAmount = "{{AFFECTED_AMOUNT}}"
    case totalDamages = "{{TOTAL_DAMAGES}}"
    case evidenceText = "{{EVIDENCE_TEXT}}"

    // Legal References
    case legalCitations = "{{LEGAL_CITATIONS}}"
    case respaSection = "{{RESPA_SECTION}}"
    case regulatoryReferences = "{{REGULATORY_REFERENCES}}"

    // Custom Fields
    case customField1 = "{{CUSTOM_FIELD_1}}"
    case customField2 = "{{CUSTOM_FIELD_2}}"
    case customField3 = "{{CUSTOM_FIELD_3}}"
    case customField4 = "{{CUSTOM_FIELD_4}}"
    case customField5 = "{{CUSTOM_FIELD_5}}"

    var description: String {
        switch self {
        case .userFullName:
            return "User's full name"
        case .userFirstName:
            return "User's first name"
        case .userLastName:
            return "User's last name"
        case .userAddress:
            return "User's mailing address"
        case .userEmail:
            return "User's email address"
        case .userPhone:
            return "User's phone number"
        case .servicerName:
            return "Mortgage servicer name"
        case .servicerAddress:
            return "Servicer's address"
        case .loanNumber:
            return "Loan account number"
        case .propertyAddress:
            return "Property address"
        case .currentDate:
            return "Current date"
        case .responseDeadline:
            return "Required response deadline"
        case .issueDate:
            return "Date issue occurred"
        case .issueDescription:
            return "Brief issue description"
        case .detailedExplanation:
            return "Detailed issue explanation"
        case .affectedAmount:
            return "Dollar amount affected"
        case .totalDamages:
            return "Total damages amount"
        case .evidenceText:
            return "Supporting evidence"
        case .legalCitations:
            return "Legal citations"
        case .respaSection:
            return "RESPA section reference"
        case .regulatoryReferences:
            return "Regulatory references"
        case .customField1, .customField2, .customField3, .customField4, .customField5:
            return "Custom field"
        }
    }
}

// MARK: - Default Templates
extension LetterTemplate {
    static func defaultTemplates() -> [LetterTemplate] {
        return [
            noticeOfErrorTemplate(),
            qualifiedWrittenRequestTemplate(),
            escalationLetterTemplate(),
            cfpbComplaintTemplate()
        ]
    }

    static func noticeOfErrorTemplate() -> LetterTemplate {
        LetterTemplate(
            templateType: .noticeOfError,
            name: "Standard Notice of Error",
            version: "1.0",
            title: "Notice of Error Under RESPA Section 1024.35",
            subject: "Notice of Error - Loan Number {{LOAN_NUMBER}}",
            body: """
            {{CURRENT_DATE}}

            {{SERVICER_NAME}}
            {{SERVICER_ADDRESS}}

            RE: Notice of Error Under 12 CFR § 1024.35
            Loan Number: {{LOAN_NUMBER}}
            Property Address: {{PROPERTY_ADDRESS}}

            Dear Sir or Madam:

            I am writing to notify you of an error in the servicing of my mortgage loan pursuant to 12 CFR § 1024.35 of the Real Estate Settlement Procedures Act (RESPA). This letter serves as my formal Notice of Error.

            ERROR DESCRIPTION:
            {{ISSUE_DESCRIPTION}}

            DETAILED EXPLANATION:
            {{DETAILED_EXPLANATION}}

            FINANCIAL IMPACT:
            The error has resulted in financial damages of ${{AFFECTED_AMOUNT}}. {{EVIDENCE_TEXT}}

            REQUESTED CORRECTION:
            I request that you:
            1. Correct the error identified above
            2. Provide written confirmation of the correction
            3. Adjust my account to reflect the correct information
            4. Refund any overpayments or incorrectly charged fees

            LEGAL NOTICE:
            Under 12 CFR § 1024.35(e), you must acknowledge receipt of this notice within 5 business days and either correct the error or conduct an investigation within 30 business days (or 7 business days before the next payment due date, whichever is earlier).

            Failure to comply with RESPA requirements may result in actual damages, statutory damages up to $2,000, attorney's fees, and additional remedies available under federal and state law.

            Please provide your response in writing to the address below. I request confirmation of receipt of this notice and a timeline for resolution.

            Sincerely,

            {{USER_FULL_NAME}}
            {{USER_ADDRESS}}
            {{USER_EMAIL}}
            {{USER_PHONE}}

            Enclosures: Supporting Documentation
            """,
            legalCitations: [
                "12 CFR § 1024.35 - Error resolution procedures",
                "12 CFR § 1024.36 - Requests for information",
                "15 U.S.C. § 1692g - Validation of debts"
            ],
            requiredFields: [
                RequiredField(fieldName: "issue_description", displayName: "Issue Description", fieldType: .multilineText, isRequired: true, placeholder: "Describe the specific error", validation: .required),
                RequiredField(fieldName: "detailed_explanation", displayName: "Detailed Explanation", fieldType: .multilineText, isRequired: true, placeholder: "Provide detailed explanation with dates and amounts", validation: .required),
                RequiredField(fieldName: "affected_amount", displayName: "Affected Amount", fieldType: .currency, isRequired: false, placeholder: "0.00", validation: .currency),
                RequiredField(fieldName: "evidence_text", displayName: "Evidence", fieldType: .multilineText, isRequired: false, placeholder: "Supporting evidence", validation: nil)
            ],
            respaCompliance: RESPACompliance(
                isRESPACompliant: true,
                regulationSection: "12 CFR § 1024.35",
                requiredDisclosures: [
                    "Error identification",
                    "Correction request",
                    "Legal consequences of non-compliance"
                ],
                responseTimelineDays: 30,
                legalRequirements: [
                    "Written format required",
                    "Specific error identification",
                    "Account information included",
                    "Consumer contact information"
                ],
                citedRegulations: [
                    RESPACompliance.LegalCitation(
                        regulation: "RESPA",
                        section: "12 CFR § 1024.35",
                        description: "Error resolution procedures",
                        url: "https://www.ecfr.gov/current/title-12/chapter-X/part-1024/section-1024.35"
                    )
                ]
            ),
            formatOptions: FormatOptions(
                fontFamily: "Times New Roman",
                fontSize: 12.0,
                lineSpacing: 1.15,
                margins: FormatOptions.Margins(top: 72, bottom: 72, left: 72, right: 72),
                headerStyle: FormatOptions.HeaderStyle(
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
            ),
            createdDate: Date(),
            lastUpdated: Date(),
            isActive: true
        )
    }

    static func qualifiedWrittenRequestTemplate() -> LetterTemplate {
        LetterTemplate(
            templateType: .qualifiedWrittenRequest,
            name: "Qualified Written Request",
            version: "1.0",
            title: "Qualified Written Request Under RESPA Section 1024.36",
            subject: "Qualified Written Request - Loan Number {{LOAN_NUMBER}}",
            body: """
            {{CURRENT_DATE}}

            {{SERVICER_NAME}}
            {{SERVICER_ADDRESS}}

            RE: Qualified Written Request Under 12 CFR § 1024.36
            Loan Number: {{LOAN_NUMBER}}
            Property Address: {{PROPERTY_ADDRESS}}

            Dear Sir or Madam:

            This letter serves as my Qualified Written Request (QWR) pursuant to 12 CFR § 1024.36 of the Real Estate Settlement Procedures Act (RESPA). I am requesting information regarding the servicing of my mortgage loan.

            INFORMATION REQUESTED:
            {{ISSUE_DESCRIPTION}}

            SPECIFIC DETAILS REQUESTED:
            {{DETAILED_EXPLANATION}}

            REASON FOR REQUEST:
            I am requesting this information to better understand my mortgage account and ensure accurate servicing. {{EVIDENCE_TEXT}}

            LEGAL NOTICE:
            Under 12 CFR § 1024.36(d), you must acknowledge receipt of this request within 5 business days and provide the requested information within 30 business days (or 7 business days before the next payment due date, whichever is earlier).

            This request is made pursuant to my rights under RESPA. Failure to respond appropriately may result in actual damages, statutory damages, attorney's fees, and other remedies available under federal and state law.

            Please provide your complete response in writing to the address below. If you determine that any requested information is not available or cannot be provided, please explain the specific reasons in writing.

            Sincerely,

            {{USER_FULL_NAME}}
            {{USER_ADDRESS}}
            {{USER_EMAIL}}
            {{USER_PHONE}}
            """,
            legalCitations: [
                "12 CFR § 1024.36 - Requests for information",
                "12 CFR § 1024.35 - Error resolution procedures"
            ],
            requiredFields: [
                RequiredField(fieldName: "issue_description", displayName: "Information Requested", fieldType: .multilineText, isRequired: true, placeholder: "Describe the specific information you need", validation: .required),
                RequiredField(fieldName: "detailed_explanation", displayName: "Specific Details", fieldType: .multilineText, isRequired: true, placeholder: "List specific details or documents requested", validation: .required),
                RequiredField(fieldName: "evidence_text", displayName: "Reason for Request", fieldType: .multilineText, isRequired: false, placeholder: "Explain why you need this information", validation: nil)
            ],
            respaCompliance: RESPACompliance(
                isRESPACompliant: true,
                regulationSection: "12 CFR § 1024.36",
                requiredDisclosures: [
                    "Information request identification",
                    "Account information",
                    "Legal basis for request"
                ],
                responseTimelineDays: 30,
                legalRequirements: [
                    "Written format required",
                    "Sufficient detail to identify information",
                    "Account information included",
                    "Consumer contact information"
                ],
                citedRegulations: [
                    RESPACompliance.LegalCitation(
                        regulation: "RESPA",
                        section: "12 CFR § 1024.36",
                        description: "Requests for information",
                        url: "https://www.ecfr.gov/current/title-12/chapter-X/part-1024/section-1024.36"
                    )
                ]
            ),
            formatOptions: FormatOptions(
                fontFamily: "Times New Roman",
                fontSize: 12.0,
                lineSpacing: 1.15,
                margins: FormatOptions.Margins(top: 72, bottom: 72, left: 72, right: 72),
                headerStyle: FormatOptions.HeaderStyle(
                    includeLogo: false,
                    includeUserAddress: true,
                    includeDate: true,
                    includeSubject: true,
                    alignment: .left
                ),
                includeLetterhead: true,
                includeSignatureLine: true,
                includeAttachmentsList: false,
                includeDeliveryConfirmation: false
            ),
            createdDate: Date(),
            lastUpdated: Date(),
            isActive: true
        )
    }

    static func escalationLetterTemplate() -> LetterTemplate {
        LetterTemplate(
            templateType: .escalationLetter,
            name: "Escalation Letter",
            version: "1.0",
            title: "Escalation of Unresolved RESPA Violation",
            subject: "URGENT: Escalation of Unresolved RESPA Violation - Loan {{LOAN_NUMBER}}",
            body: """
            {{CURRENT_DATE}}

            {{SERVICER_NAME}}
            ATTN: Executive Customer Relations
            {{SERVICER_ADDRESS}}

            RE: URGENT ESCALATION - RESPA Violation
            Loan Number: {{LOAN_NUMBER}}
            Property Address: {{PROPERTY_ADDRESS}}
            Original Notice Date: {{ISSUE_DATE}}

            Dear Executive Team:

            I am writing to escalate a serious RESPA violation that remains unresolved despite my previous formal notice. This matter requires immediate executive attention and resolution.

            BACKGROUND:
            On {{ISSUE_DATE}}, I submitted a formal Notice of Error under 12 CFR § 1024.35. Your company has failed to comply with RESPA requirements, constituting a federal law violation.

            UNRESOLVED VIOLATION:
            {{ISSUE_DESCRIPTION}}

            DETAILED EXPLANATION:
            {{DETAILED_EXPLANATION}}

            FINANCIAL DAMAGES:
            The ongoing violation has caused financial damages totaling ${{TOTAL_DAMAGES}}. Each day this violation continues, additional damages accrue.

            LEGAL VIOLATIONS:
            Your company is in violation of:
            • 12 CFR § 1024.35 - Error resolution procedures
            • 12 CFR § 1024.36 - Information request requirements
            • Federal consumer protection laws

            IMMEDIATE DEMANDS:
            1. Immediate correction of the identified error
            2. Full restoration of my account to correct status
            3. Refund of all incorrectly charged amounts (${{AFFECTED_AMOUNT}})
            4. Compensation for damages caused by the violation
            5. Written confirmation of all corrective actions

            CONSEQUENCES OF CONTINUED NON-COMPLIANCE:
            Continued failure to resolve this matter will result in:
            • Formal complaints to the CFPB and state regulators
            • Legal action seeking actual and statutory damages
            • Attorney's fees and court costs
            • Additional remedies available under federal and state law

            I demand resolution within 7 business days of receipt of this letter. Failure to respond appropriately will result in immediate escalation to federal and state regulators.

            This matter requires your immediate personal attention.

            Sincerely,

            {{USER_FULL_NAME}}
            {{USER_ADDRESS}}
            {{USER_EMAIL}}
            {{USER_PHONE}}

            CC: CFPB Consumer Response Center
            CC: State Mortgage Regulator
            """,
            legalCitations: [
                "12 CFR § 1024.35 - Error resolution procedures",
                "12 CFR § 1024.36 - Requests for information",
                "15 U.S.C. § 1692 - Fair Debt Collection Practices Act"
            ],
            requiredFields: [
                RequiredField(fieldName: "issue_date", displayName: "Original Notice Date", fieldType: .date, isRequired: true, placeholder: "Date of original notice", validation: .required),
                RequiredField(fieldName: "issue_description", displayName: "Violation Description", fieldType: .multilineText, isRequired: true, placeholder: "Describe the RESPA violation", validation: .required),
                RequiredField(fieldName: "detailed_explanation", displayName: "Detailed Explanation", fieldType: .multilineText, isRequired: true, placeholder: "Provide detailed explanation of violation and non-compliance", validation: .required),
                RequiredField(fieldName: "affected_amount", displayName: "Affected Amount", fieldType: .currency, isRequired: true, placeholder: "0.00", validation: .currency),
                RequiredField(fieldName: "total_damages", displayName: "Total Damages", fieldType: .currency, isRequired: true, placeholder: "0.00", validation: .currency)
            ],
            respaCompliance: RESPACompliance(
                isRESPACompliant: true,
                regulationSection: "12 CFR § 1024.35, 1024.36",
                requiredDisclosures: [
                    "Previous notice reference",
                    "Specific violation identification",
                    "Damages calculation",
                    "Legal consequences"
                ],
                responseTimelineDays: 7,
                legalRequirements: [
                    "Reference to previous notices",
                    "Executive escalation",
                    "Specific demands",
                    "Legal consequences outlined"
                ],
                citedRegulations: [
                    RESPACompliance.LegalCitation(
                        regulation: "RESPA",
                        section: "12 CFR § 1024.35",
                        description: "Error resolution procedures",
                        url: "https://www.ecfr.gov/current/title-12/chapter-X/part-1024/section-1024.35"
                    )
                ]
            ),
            formatOptions: FormatOptions(
                fontFamily: "Times New Roman",
                fontSize: 12.0,
                lineSpacing: 1.15,
                margins: FormatOptions.Margins(top: 72, bottom: 72, left: 72, right: 72),
                headerStyle: FormatOptions.HeaderStyle(
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
            ),
            createdDate: Date(),
            lastUpdated: Date(),
            isActive: true
        )
    }

    static func cfpbComplaintTemplate() -> LetterTemplate {
        LetterTemplate(
            templateType: .cfpbComplaint,
            name: "CFPB Complaint",
            version: "1.0",
            title: "Consumer Complaint to CFPB",
            subject: "Formal Complaint Against {{SERVICER_NAME}} - RESPA Violations",
            body: """
            {{CURRENT_DATE}}

            Consumer Financial Protection Bureau
            P.O. Box 4503
            Iowa City, IA 52244

            RE: Formal Consumer Complaint
            Company: {{SERVICER_NAME}}
            Product: Mortgage
            Issue: RESPA Violations
            Loan Number: {{LOAN_NUMBER}}

            Dear CFPB:

            I am filing this formal complaint against {{SERVICER_NAME}} for violations of the Real Estate Settlement Procedures Act (RESPA) and other federal consumer protection laws.

            COMPANY INFORMATION:
            Company Name: {{SERVICER_NAME}}
            Company Address: {{SERVICER_ADDRESS}}
            Loan Number: {{LOAN_NUMBER}}
            Property Address: {{PROPERTY_ADDRESS}}

            VIOLATIONS:
            {{ISSUE_DESCRIPTION}}

            DETAILED COMPLAINT:
            {{DETAILED_EXPLANATION}}

            ATTEMPTS TO RESOLVE:
            I have made multiple attempts to resolve this matter directly with {{SERVICER_NAME}}, including formal written notices as required under RESPA. The company has failed to comply with federal law and continues to violate my consumer rights.

            FINANCIAL HARM:
            The violations have caused financial damages of ${{TOTAL_DAMAGES}}. This includes incorrect charges, fees, and ongoing harm to my credit and financial standing.

            RESOLUTION REQUESTED:
            1. Investigation of {{SERVICER_NAME}}'s practices
            2. Enforcement action against the company
            3. Correction of my account and credit reports
            4. Refund of all incorrectly charged amounts
            5. Compensation for damages
            6. Implementation of compliance procedures

            SUPPORTING DOCUMENTATION:
            I have attached copies of all correspondence, account statements, and supporting documentation.

            I request that the CFPB investigate this matter and take appropriate enforcement action against {{SERVICER_NAME}}. I am available to provide additional information as needed.

            Thank you for your attention to this serious matter.

            Sincerely,

            {{USER_FULL_NAME}}
            {{USER_ADDRESS}}
            {{USER_EMAIL}}
            {{USER_PHONE}}

            Attachments: Supporting Documentation
            """,
            legalCitations: [
                "12 CFR § 1024.35 - Error resolution procedures",
                "12 CFR § 1024.36 - Requests for information",
                "12 U.S.C. § 5481 et seq. - Consumer Financial Protection Act"
            ],
            requiredFields: [
                RequiredField(fieldName: "issue_description", displayName: "Violations", fieldType: .multilineText, isRequired: true, placeholder: "Describe the RESPA violations", validation: .required),
                RequiredField(fieldName: "detailed_explanation", displayName: "Detailed Complaint", fieldType: .multilineText, isRequired: true, placeholder: "Provide detailed explanation of the violations and their impact", validation: .required),
                RequiredField(fieldName: "total_damages", displayName: "Total Damages", fieldType: .currency, isRequired: false, placeholder: "0.00", validation: .currency)
            ],
            respaCompliance: RESPACompliance(
                isRESPACompliant: true,
                regulationSection: "Consumer Financial Protection Act",
                requiredDisclosures: [
                    "Company identification",
                    "Violation description",
                    "Resolution attempts",
                    "Damages claimed"
                ],
                responseTimelineDays: 15,
                legalRequirements: [
                    "Formal complaint format",
                    "Specific violation allegations",
                    "Supporting documentation",
                    "Resolution requests"
                ],
                citedRegulations: [
                    RESPACompliance.LegalCitation(
                        regulation: "CFPA",
                        section: "12 U.S.C. § 5481",
                        description: "Consumer Financial Protection Act",
                        url: "https://www.law.cornell.edu/uscode/text/12/5481"
                    )
                ]
            ),
            formatOptions: FormatOptions(
                fontFamily: "Times New Roman",
                fontSize: 12.0,
                lineSpacing: 1.15,
                margins: FormatOptions.Margins(top: 72, bottom: 72, left: 72, right: 72),
                headerStyle: FormatOptions.HeaderStyle(
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
            ),
            createdDate: Date(),
            lastUpdated: Date(),
            isActive: true
        )
    }
}