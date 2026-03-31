'use client'

import { use, useState } from 'react'
import Link from 'next/link'
import { PageHeader } from '@/components/page-header'
import { ReportSummary } from '@/components/report-summary'
import { FindingCard } from '@/components/finding-card'
import { RiskBadge } from '@/components/risk-badge'
import { EmptyState } from '@/components/empty-state'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/skeleton'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { useGenerateReport, useReport } from '@/lib/hooks'
import type { ConsolidatedReport } from '@/lib/types'
import {
  ArrowLeft,
  FileText,
  Play,
  Loader2,
  RefreshCw,
  Mail,
  ChevronDown,
  ChevronUp,
  FileSearch,
  Search,
  ShieldCheck,
  Lightbulb,
  Link2,
} from 'lucide-react'

function ReportSkeleton() {
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton key={i} className="h-32 bg-gray-800" />
        ))}
      </div>
      <Skeleton className="h-48 bg-gray-800" />
      <Skeleton className="h-48 bg-gray-800" />
    </div>
  )
}

function CollapsibleSection({
  title,
  icon: Icon,
  count,
  defaultOpen = false,
  children,
}: {
  title: string
  icon: React.ElementType
  count?: number
  defaultOpen?: boolean
  children: React.ReactNode
}) {
  const [open, setOpen] = useState(defaultOpen)

  return (
    <div className="rounded-xl border border-gray-800 bg-gray-900">
      <button
        onClick={() => setOpen(!open)}
        className="flex w-full items-center justify-between px-4 py-3 text-left"
      >
        <div className="flex items-center gap-2">
          <Icon className="h-4 w-4 text-gray-400" />
          <span className="text-sm font-medium text-gray-200">{title}</span>
          {count !== undefined && (
            <Badge className="bg-gray-800 text-gray-400 border-gray-700 border text-xs">
              {count}
            </Badge>
          )}
        </div>
        {open ? (
          <ChevronUp className="h-4 w-4 text-gray-500" />
        ) : (
          <ChevronDown className="h-4 w-4 text-gray-500" />
        )}
      </button>
      {open && (
        <div className="border-t border-gray-800 px-4 py-4">{children}</div>
      )}
    </div>
  )
}

export default function ReportPage({
  params,
}: {
  params: Promise<{ caseId: string }>
}) {
  const { caseId } = use(params)
  const [includeLetterOnGenerate, setIncludeLetterOnGenerate] = useState(false)

  const reportQuery = useReport(caseId)
  const generateReport = useGenerateReport(caseId)

  const report = reportQuery.data as ConsolidatedReport | undefined
  const hasReport = report && !reportQuery.isError

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Link href={`/dashboard/cases/${caseId}`}>
          <Button variant="ghost" size="icon">
            <ArrowLeft className="h-4 w-4" />
          </Button>
        </Link>
        <PageHeader
          title="Consolidated Report"
          description="Complete analysis report with findings and recommendations"
        >
          {hasReport && (
            <div className="flex items-center gap-2">
              <Link href={`/dashboard/cases/${caseId}/report/letter`}>
                <Button variant="outline" size="sm">
                  <Mail className="mr-1.5 h-3.5 w-3.5" />
                  Dispute Letter
                </Button>
              </Link>
              <Button
                variant="outline"
                size="sm"
                onClick={() => generateReport.mutate({})}
                disabled={generateReport.isPending}
              >
                {generateReport.isPending ? (
                  <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
                ) : (
                  <RefreshCw className="mr-1.5 h-3.5 w-3.5" />
                )}
                Regenerate
              </Button>
            </div>
          )}
        </PageHeader>
      </div>

      {reportQuery.isLoading && <ReportSkeleton />}

      {!reportQuery.isLoading && !hasReport && (
        <EmptyState
          icon={FileText}
          title="No Report Generated"
          description="Generate a consolidated report to combine document analysis, forensic findings, and compliance results into a single report."
        >
          <div className="space-y-3">
            <label className="flex items-center gap-2 text-sm text-gray-400">
              <input
                type="checkbox"
                checked={includeLetterOnGenerate}
                onChange={(e) => setIncludeLetterOnGenerate(e.target.checked)}
                className="rounded border-gray-600 bg-gray-800"
              />
              Also generate dispute letter
            </label>
            <Button
              onClick={() =>
                generateReport.mutate({
                  generateLetter: includeLetterOnGenerate,
                })
              }
              disabled={generateReport.isPending}
            >
              {generateReport.isPending ? (
                <Loader2 className="mr-1.5 h-4 w-4 animate-spin" />
              ) : (
                <Play className="mr-1.5 h-4 w-4" />
              )}
              Generate Report
            </Button>
          </div>
        </EmptyState>
      )}

      {hasReport && (
        <div className="space-y-6">
          <ReportSummary report={report} />

          {/* Document Analysis */}
          {report.documentAnalysis?.length > 0 && (
            <CollapsibleSection
              title="Document Analysis"
              icon={FileSearch}
              count={report.documentAnalysis.length}
              defaultOpen
            >
              <div className="space-y-4">
                {report.documentAnalysis.map((doc) => (
                  <Card
                    key={doc.documentId}
                    className="bg-gray-800/50 border-gray-700"
                  >
                    <CardHeader>
                      <CardTitle className="flex items-center justify-between text-sm">
                        <span className="text-gray-200">
                          {doc.documentName}
                        </span>
                        <div className="flex items-center gap-2">
                          <Badge className="bg-gray-700 text-gray-300 border-gray-600 border text-xs">
                            {doc.type}
                            {doc.subtype ? ` / ${doc.subtype}` : ''}
                          </Badge>
                          <span className="text-xs text-gray-500">
                            Completeness: {doc.completenessScore}%
                          </span>
                        </div>
                      </CardTitle>
                    </CardHeader>
                    {(doc.keyFindings?.length > 0 ||
                      doc.anomalies?.length > 0) && (
                      <CardContent className="space-y-3">
                        {doc.keyFindings?.length > 0 && (
                          <ul className="space-y-1">
                            {doc.keyFindings.map((f, i) => (
                              <li
                                key={i}
                                className="text-sm text-gray-300"
                              >
                                {f}
                              </li>
                            ))}
                          </ul>
                        )}
                        {doc.anomalies?.length > 0 && (
                          <div className="grid gap-2 md:grid-cols-2">
                            {doc.anomalies.map((a, i) => (
                              <FindingCard
                                key={a.id ?? i}
                                type={a.type}
                                severity={a.severity}
                                description={a.description}
                              />
                            ))}
                          </div>
                        )}
                      </CardContent>
                    )}
                  </Card>
                ))}
              </div>
            </CollapsibleSection>
          )}

          {/* Forensic Findings */}
          <CollapsibleSection
            title="Forensic Findings"
            icon={Search}
            count={
              (report.forensicFindings?.discrepancies?.length ?? 0) +
              (report.forensicFindings?.timelineViolations?.length ?? 0)
            }
          >
            <div className="space-y-4">
              {report.forensicFindings?.discrepancies?.length > 0 && (
                <div className="space-y-2">
                  <h4 className="text-xs font-medium uppercase tracking-wider text-gray-500">
                    Discrepancies
                  </h4>
                  <div className="grid gap-2 md:grid-cols-2">
                    {report.forensicFindings.discrepancies.map((d, i) => (
                      <FindingCard
                        key={d.id ?? i}
                        type={d.type}
                        severity={d.severity}
                        description={d.description}
                      />
                    ))}
                  </div>
                </div>
              )}
              {report.forensicFindings?.timelineViolations?.length > 0 && (
                <div className="space-y-2">
                  <h4 className="text-xs font-medium uppercase tracking-wider text-gray-500">
                    Timeline Violations
                  </h4>
                  <div className="grid gap-2 md:grid-cols-2">
                    {report.forensicFindings.timelineViolations.map((v, i) => (
                      <FindingCard
                        key={i}
                        type="Timeline"
                        severity={v.severity}
                        description={v.description}
                        details={
                          v.regulation
                            ? { Regulation: v.regulation }
                            : undefined
                        }
                      />
                    ))}
                  </div>
                </div>
              )}
              {(!report.forensicFindings?.discrepancies?.length &&
                !report.forensicFindings?.timelineViolations?.length) && (
                <p className="text-sm text-gray-500 text-center py-4">
                  No forensic findings
                </p>
              )}
            </div>
          </CollapsibleSection>

          {/* Compliance Findings */}
          <CollapsibleSection
            title="Compliance Findings"
            icon={ShieldCheck}
            count={
              (report.complianceFindings?.federalViolations?.length ?? 0) +
              (report.complianceFindings?.stateViolations?.length ?? 0)
            }
          >
            <div className="space-y-4">
              {report.complianceFindings?.federalViolations?.length > 0 && (
                <div className="space-y-2">
                  <h4 className="text-xs font-medium uppercase tracking-wider text-gray-500">
                    Federal Violations
                  </h4>
                  <div className="grid gap-2 md:grid-cols-2">
                    {report.complianceFindings.federalViolations.map(
                      (v, i) => (
                        <FindingCard
                          key={v.id ?? i}
                          type={v.statuteName}
                          severity={v.severity}
                          description={v.description}
                          details={{
                            Citation: v.citation,
                            Section: v.sectionTitle,
                          }}
                        />
                      )
                    )}
                  </div>
                </div>
              )}
              {report.complianceFindings?.stateViolations?.length > 0 && (
                <div className="space-y-2">
                  <h4 className="text-xs font-medium uppercase tracking-wider text-gray-500">
                    State Violations
                  </h4>
                  <div className="grid gap-2 md:grid-cols-2">
                    {report.complianceFindings.stateViolations.map((v, i) => (
                      <FindingCard
                        key={v.id ?? i}
                        type={v.statuteName}
                        severity={v.severity}
                        description={v.description}
                        details={{
                          Citation: v.citation,
                          Jurisdiction: v.jurisdiction ?? '',
                        }}
                      />
                    ))}
                  </div>
                </div>
              )}
              {(!report.complianceFindings?.federalViolations?.length &&
                !report.complianceFindings?.stateViolations?.length) && (
                <p className="text-sm text-gray-500 text-center py-4">
                  No compliance findings
                </p>
              )}
            </div>
          </CollapsibleSection>

          {/* Recommendations */}
          {report.recommendations?.length > 0 && (
            <CollapsibleSection
              title="Recommendations"
              icon={Lightbulb}
              count={report.recommendations.length}
            >
              <div className="space-y-3">
                {report.recommendations
                  .sort((a, b) => a.priority - b.priority)
                  .map((rec, i) => (
                    <div
                      key={i}
                      className="flex gap-3 rounded-lg border border-gray-800 bg-gray-800/50 p-3"
                    >
                      <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-blue-500/10 text-xs font-bold text-blue-400">
                        {rec.priority}
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-2">
                          <span className="text-xs font-medium uppercase tracking-wider text-gray-500">
                            {rec.category}
                          </span>
                        </div>
                        <p className="mt-1 text-sm text-gray-200">
                          {rec.action}
                        </p>
                        {rec.legalBasis && (
                          <p className="mt-1 text-xs text-gray-500">
                            Legal basis: {rec.legalBasis}
                          </p>
                        )}
                      </div>
                    </div>
                  ))}
              </div>
            </CollapsibleSection>
          )}

          {/* Evidence Links */}
          {report.evidenceLinks?.length > 0 && (
            <CollapsibleSection
              title="Evidence Links"
              icon={Link2}
              count={report.evidenceLinks.length}
            >
              <div className="space-y-2">
                {report.evidenceLinks.map((link, i) => (
                  <div
                    key={i}
                    className="flex items-start gap-3 rounded-lg border border-gray-800 bg-gray-800/50 p-3"
                  >
                    <RiskBadge level={link.severity as 'critical' | 'high' | 'medium' | 'low' | 'clean' | 'info'} />
                    <div className="min-w-0 flex-1">
                      <p className="text-sm text-gray-200">
                        {link.evidenceDescription}
                      </p>
                      <p className="mt-1 text-xs text-gray-500">
                        Finding: {link.findingType} | Documents:{' '}
                        {link.sourceDocumentIds.join(', ')}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </CollapsibleSection>
          )}
        </div>
      )}
    </div>
  )
}
