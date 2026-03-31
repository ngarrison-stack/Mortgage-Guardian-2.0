// TypeScript interfaces matching the backend OpenAPI spec

export interface Case {
  id: string
  caseName: string
  borrowerName?: string
  propertyAddress?: string
  loanNumber?: string
  servicerName?: string
  status: 'open' | 'in_review' | 'complete' | 'archived'
  notes?: string
  documents?: Document[]
  created_at: string
  updated_at?: string
}

export interface Document {
  document_id: string
  file_name: string
  document_type: string
  analysis_report?: AnalysisReport
  created_at: string
}

export interface AnalysisReport {
  documentInfo: {
    documentId: string
    fileName: string
    classificationType: string
    classificationSubtype: string
  }
  completeness: {
    score: number
    totalExpected: number
    totalFound: number
  }
  anomalies: Anomaly[]
  summary: {
    riskLevel: string
    keyFindings: string[]
  }
}

export interface Anomaly {
  id: string
  field: string
  type: string
  severity: 'critical' | 'high' | 'medium' | 'low' | 'info'
  description: string
}

export interface PipelineStatus {
  documentId: string
  status: 'uploaded' | 'ocr' | 'classifying' | 'analyzing' | 'analyzed' | 'review' | 'complete' | 'failed'
  steps: Record<string, { status: string; method?: string }>
}

export interface ConsolidatedReport {
  reportId: string
  caseId: string
  userId: string
  generatedAt: string
  reportVersion: string
  caseSummary: {
    borrowerName: string
    propertyAddress: string
    loanNumber: string
    servicerName: string
    documentCount: number
    caseCreatedAt: string
  }
  overallRiskLevel: 'critical' | 'high' | 'medium' | 'low' | 'clean'
  confidenceScore: {
    overall: number
    breakdown: {
      documentAnalysis: number
      forensicAnalysis: number | null
      complianceAnalysis: number | null
    }
    classificationImpact?: {
      confidenceUsed: number
      factor: number
      layerAffected: string
    }
  }
  findingSummary: {
    totalFindings: number
    bySeverity: Record<string, number>
    byCategory: Record<string, number>
  }
  documentAnalysis: DocumentAnalysisItem[]
  forensicFindings: {
    discrepancies: Discrepancy[]
    timelineViolations: TimelineViolation[]
    paymentVerification: PaymentVerification | null
  }
  complianceFindings: {
    federalViolations: Violation[]
    stateViolations: Violation[]
    jurisdiction: { propertyState?: string; servicerState?: string; applicableStates: string[] } | null
  }
  evidenceLinks: EvidenceLink[]
  recommendations: Recommendation[]
  disputeLetterAvailable: boolean
  disputeLetter: DisputeLetter | null
}

export interface DocumentAnalysisItem {
  documentId: string
  documentName: string
  type: string
  subtype: string
  completenessScore: number
  anomalyCount: number
  anomalies: Anomaly[]
  keyFindings: string[]
}

export interface Discrepancy {
  id: string
  type: string
  severity: string
  description: string
  documentIds: string[]
}

export interface TimelineViolation {
  description: string
  severity: string
  relatedDocuments: string[]
  regulation?: string
}

export interface PaymentVerification {
  verified: boolean
  transactionsAnalyzed: number
  matchedCount: number
  unmatchedCount: number
  findings: string[]
}

export interface Violation {
  id: string
  statuteId: string
  sectionId: string
  statuteName: string
  sectionTitle: string
  citation: string
  severity: string
  description: string
  legalBasis: string
  jurisdiction?: string
}

export interface EvidenceLink {
  findingId: string
  findingType: string
  sourceDocumentIds: string[]
  evidenceDescription: string
  severity: string
}

export interface Recommendation {
  priority: number
  category: string
  action: string
  legalBasis: string | null
  relatedFindingIds: string[]
}

export interface DisputeLetter {
  letterType: 'qualified_written_request' | 'notice_of_error' | 'request_for_information'
  generatedAt: string
  content: {
    subject: string
    salutation: string
    body: string
    demands: string[]
    legalCitations: string[]
    responseDeadline: string
    closingStatement: string
  }
  recipientInfo: {
    servicerName: string
    servicerAddress: string
  }
}

export type RiskLevel = 'critical' | 'high' | 'medium' | 'low' | 'clean'
export type CaseStatus = 'open' | 'in_review' | 'complete' | 'archived'
