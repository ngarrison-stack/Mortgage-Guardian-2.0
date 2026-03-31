'use client'

import { use } from 'react'
import Link from 'next/link'
import { PageHeader } from '@/components/page-header'
import { FindingCard } from '@/components/finding-card'
import { EmptyState } from '@/components/empty-state'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/skeleton'
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import {
  useRunForensicAnalysis,
  useForensicAnalysis,
  useRunComplianceEvaluation,
  useComplianceReport,
} from '@/lib/hooks'
import {
  ArrowLeft,
  Search,
  ShieldCheck,
  Play,
  Loader2,
  CheckCircle2,
  DollarSign,
  Clock,
  FileSearch,
  Scale,
  MapPin,
} from 'lucide-react'

function AnalysisSkeleton() {
  return (
    <div className="space-y-4">
      <Skeleton className="h-6 w-48 bg-gray-800" />
      <Skeleton className="h-32 w-full bg-gray-800" />
      <Skeleton className="h-32 w-full bg-gray-800" />
      <Skeleton className="h-32 w-full bg-gray-800" />
    </div>
  )
}

export default function AnalysisPage({
  params,
}: {
  params: Promise<{ caseId: string }>
}) {
  const { caseId } = use(params)

  const forensicQuery = useForensicAnalysis(caseId)
  const complianceQuery = useComplianceReport(caseId)
  const runForensic = useRunForensicAnalysis(caseId)
  const runCompliance = useRunComplianceEvaluation(caseId)

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const forensicData = forensicQuery.data as any
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const complianceData = complianceQuery.data as any

  const hasForensic = forensicData && !forensicQuery.isError
  const hasCompliance = complianceData && !complianceQuery.isError

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Link href={`/dashboard/cases/${caseId}`}>
          <Button variant="ghost" size="icon">
            <ArrowLeft className="h-4 w-4" />
          </Button>
        </Link>
        <PageHeader
          title="Analysis"
          description="Forensic and compliance analysis of case documents"
        />
      </div>

      <Tabs defaultValue="forensic">
        <TabsList>
          <TabsTrigger value="forensic">
            <Search className="mr-1.5 h-3.5 w-3.5" />
            Forensic Analysis
          </TabsTrigger>
          <TabsTrigger value="compliance">
            <ShieldCheck className="mr-1.5 h-3.5 w-3.5" />
            Compliance Report
          </TabsTrigger>
        </TabsList>

        {/* Forensic Analysis Tab */}
        <TabsContent value="forensic" className="mt-6 space-y-6">
          {forensicQuery.isLoading && <AnalysisSkeleton />}

          {!forensicQuery.isLoading && !hasForensic && (
            <EmptyState
              icon={FileSearch}
              title="No Forensic Analysis"
              description="Run a forensic analysis to detect discrepancies, timeline violations, and verify payment records across your documents."
            >
              <Button
                onClick={() => runForensic.mutate({})}
                disabled={runForensic.isPending}
              >
                {runForensic.isPending ? (
                  <Loader2 className="mr-1.5 h-4 w-4 animate-spin" />
                ) : (
                  <Play className="mr-1.5 h-4 w-4" />
                )}
                Run Forensic Analysis
              </Button>
            </EmptyState>
          )}

          {hasForensic && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2 text-green-400">
                  <CheckCircle2 className="h-4 w-4" />
                  <span className="text-sm font-medium">Analysis Complete</span>
                </div>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => runForensic.mutate({})}
                  disabled={runForensic.isPending}
                >
                  {runForensic.isPending ? (
                    <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
                  ) : null}
                  Re-run
                </Button>
              </div>

              {/* Discrepancies */}
              {forensicData.discrepancies?.length > 0 && (
                <section className="space-y-3">
                  <h3 className="flex items-center gap-2 text-sm font-medium text-gray-300">
                    <FileSearch className="h-4 w-4 text-orange-400" />
                    Discrepancies ({forensicData.discrepancies.length})
                  </h3>
                  <div className="grid gap-3 md:grid-cols-2">
                    {forensicData.discrepancies.map(
                      // eslint-disable-next-line @typescript-eslint/no-explicit-any
                      (d: any, i: number) => (
                        <FindingCard
                          key={d.id ?? i}
                          type={d.type ?? 'Discrepancy'}
                          severity={d.severity ?? 'medium'}
                          description={d.description}
                          details={
                            d.documentIds?.length
                              ? { 'Related Documents': d.documentIds.join(', ') }
                              : undefined
                          }
                        />
                      )
                    )}
                  </div>
                </section>
              )}

              {/* Timeline Violations */}
              {forensicData.timelineViolations?.length > 0 && (
                <section className="space-y-3">
                  <h3 className="flex items-center gap-2 text-sm font-medium text-gray-300">
                    <Clock className="h-4 w-4 text-yellow-400" />
                    Timeline Violations (
                    {forensicData.timelineViolations.length})
                  </h3>
                  <div className="grid gap-3 md:grid-cols-2">
                    {forensicData.timelineViolations.map(
                      // eslint-disable-next-line @typescript-eslint/no-explicit-any
                      (v: any, i: number) => (
                        <FindingCard
                          key={i}
                          type="Timeline Violation"
                          severity={v.severity ?? 'medium'}
                          description={v.description}
                          details={{
                            ...(v.regulation
                              ? { Regulation: v.regulation }
                              : {}),
                            ...(v.relatedDocuments?.length
                              ? {
                                  'Related Documents':
                                    v.relatedDocuments.join(', '),
                                }
                              : {}),
                          }}
                        />
                      )
                    )}
                  </div>
                </section>
              )}

              {/* Payment Verification */}
              {forensicData.paymentVerification && (
                <section className="space-y-3">
                  <h3 className="flex items-center gap-2 text-sm font-medium text-gray-300">
                    <DollarSign className="h-4 w-4 text-blue-400" />
                    Payment Verification
                  </h3>
                  <Card className="bg-gray-900 border-gray-800">
                    <CardContent className="space-y-4">
                      <div className="flex items-center gap-3">
                        <Badge
                          className={
                            forensicData.paymentVerification.verified
                              ? 'bg-green-500/10 text-green-400 border-green-500/30 border'
                              : 'bg-red-500/10 text-red-400 border-red-500/30 border'
                          }
                        >
                          {forensicData.paymentVerification.verified
                            ? 'Verified'
                            : 'Unverified'}
                        </Badge>
                      </div>
                      <div className="grid grid-cols-3 gap-4 text-center">
                        <div>
                          <p className="text-lg font-bold text-white">
                            {forensicData.paymentVerification
                              .transactionsAnalyzed ?? 0}
                          </p>
                          <p className="text-xs text-gray-400">
                            Transactions Analyzed
                          </p>
                        </div>
                        <div>
                          <p className="text-lg font-bold text-green-400">
                            {forensicData.paymentVerification.matchedCount ?? 0}
                          </p>
                          <p className="text-xs text-gray-400">Matched</p>
                        </div>
                        <div>
                          <p className="text-lg font-bold text-red-400">
                            {forensicData.paymentVerification.unmatchedCount ??
                              0}
                          </p>
                          <p className="text-xs text-gray-400">Unmatched</p>
                        </div>
                      </div>
                      {forensicData.paymentVerification.findings?.length >
                        0 && (
                        <div className="space-y-1 border-t border-gray-800 pt-3">
                          {forensicData.paymentVerification.findings.map(
                            (f: string, i: number) => (
                              <p
                                key={i}
                                className="text-sm text-gray-300"
                              >
                                {f}
                              </p>
                            )
                          )}
                        </div>
                      )}
                    </CardContent>
                  </Card>
                </section>
              )}

              {/* Empty discrepancies + violations */}
              {(!forensicData.discrepancies ||
                forensicData.discrepancies.length === 0) &&
                (!forensicData.timelineViolations ||
                  forensicData.timelineViolations.length === 0) &&
                !forensicData.paymentVerification && (
                  <Card className="bg-gray-900 border-gray-800">
                    <CardContent className="py-8 text-center">
                      <CheckCircle2 className="mx-auto mb-2 h-8 w-8 text-green-400" />
                      <p className="text-sm text-gray-300">
                        No discrepancies or violations found
                      </p>
                    </CardContent>
                  </Card>
                )}
            </div>
          )}
        </TabsContent>

        {/* Compliance Report Tab */}
        <TabsContent value="compliance" className="mt-6 space-y-6">
          {complianceQuery.isLoading && <AnalysisSkeleton />}

          {!complianceQuery.isLoading && !hasCompliance && (
            <EmptyState
              icon={Scale}
              title="No Compliance Report"
              description="Run a compliance evaluation to identify federal and state regulatory violations based on your case documents."
            >
              <Button
                onClick={() => runCompliance.mutate({})}
                disabled={runCompliance.isPending}
              >
                {runCompliance.isPending ? (
                  <Loader2 className="mr-1.5 h-4 w-4 animate-spin" />
                ) : (
                  <Play className="mr-1.5 h-4 w-4" />
                )}
                Run Compliance Evaluation
              </Button>
            </EmptyState>
          )}

          {hasCompliance && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2 text-green-400">
                  <CheckCircle2 className="h-4 w-4" />
                  <span className="text-sm font-medium">
                    Evaluation Complete
                  </span>
                </div>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => runCompliance.mutate({})}
                  disabled={runCompliance.isPending}
                >
                  {runCompliance.isPending ? (
                    <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
                  ) : null}
                  Re-run
                </Button>
              </div>

              {/* Jurisdiction */}
              {complianceData.jurisdiction && (
                <Card className="bg-gray-900 border-gray-800">
                  <CardHeader>
                    <CardTitle className="flex items-center gap-2 text-sm">
                      <MapPin className="h-4 w-4 text-blue-400" />
                      Jurisdiction
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="flex flex-wrap gap-4 text-sm">
                      {complianceData.jurisdiction.propertyState && (
                        <div>
                          <span className="text-gray-500">Property State: </span>
                          <span className="text-gray-200">
                            {complianceData.jurisdiction.propertyState}
                          </span>
                        </div>
                      )}
                      {complianceData.jurisdiction.servicerState && (
                        <div>
                          <span className="text-gray-500">Servicer State: </span>
                          <span className="text-gray-200">
                            {complianceData.jurisdiction.servicerState}
                          </span>
                        </div>
                      )}
                      {complianceData.jurisdiction.applicableStates?.length >
                        0 && (
                        <div>
                          <span className="text-gray-500">
                            Applicable States:{' '}
                          </span>
                          <span className="text-gray-200">
                            {complianceData.jurisdiction.applicableStates.join(
                              ', '
                            )}
                          </span>
                        </div>
                      )}
                    </div>
                  </CardContent>
                </Card>
              )}

              {/* Federal Violations */}
              {complianceData.federalViolations?.length > 0 && (
                <section className="space-y-3">
                  <h3 className="flex items-center gap-2 text-sm font-medium text-gray-300">
                    <Scale className="h-4 w-4 text-red-400" />
                    Federal Violations (
                    {complianceData.federalViolations.length})
                  </h3>
                  <div className="grid gap-3 md:grid-cols-2">
                    {complianceData.federalViolations.map(
                      // eslint-disable-next-line @typescript-eslint/no-explicit-any
                      (v: any, i: number) => (
                        <FindingCard
                          key={v.id ?? i}
                          type={v.statuteName ?? 'Federal'}
                          severity={v.severity ?? 'high'}
                          description={v.description}
                          details={{
                            Citation: v.citation ?? '',
                            Section: v.sectionTitle ?? '',
                            ...(v.legalBasis
                              ? { 'Legal Basis': v.legalBasis }
                              : {}),
                          }}
                        />
                      )
                    )}
                  </div>
                </section>
              )}

              {/* State Violations */}
              {complianceData.stateViolations?.length > 0 && (
                <section className="space-y-3">
                  <h3 className="flex items-center gap-2 text-sm font-medium text-gray-300">
                    <MapPin className="h-4 w-4 text-yellow-400" />
                    State Violations ({complianceData.stateViolations.length})
                  </h3>
                  <div className="grid gap-3 md:grid-cols-2">
                    {complianceData.stateViolations.map(
                      // eslint-disable-next-line @typescript-eslint/no-explicit-any
                      (v: any, i: number) => (
                        <FindingCard
                          key={v.id ?? i}
                          type={v.statuteName ?? 'State'}
                          severity={v.severity ?? 'medium'}
                          description={v.description}
                          details={{
                            Citation: v.citation ?? '',
                            Section: v.sectionTitle ?? '',
                            ...(v.jurisdiction
                              ? { Jurisdiction: v.jurisdiction }
                              : {}),
                            ...(v.legalBasis
                              ? { 'Legal Basis': v.legalBasis }
                              : {}),
                          }}
                        />
                      )
                    )}
                  </div>
                </section>
              )}

              {/* No violations found */}
              {(!complianceData.federalViolations ||
                complianceData.federalViolations.length === 0) &&
                (!complianceData.stateViolations ||
                  complianceData.stateViolations.length === 0) && (
                  <Card className="bg-gray-900 border-gray-800">
                    <CardContent className="py-8 text-center">
                      <CheckCircle2 className="mx-auto mb-2 h-8 w-8 text-green-400" />
                      <p className="text-sm text-gray-300">
                        No compliance violations found
                      </p>
                    </CardContent>
                  </Card>
                )}
            </div>
          )}
        </TabsContent>
      </Tabs>
    </div>
  )
}
