'use client'

import { use, useState } from 'react'
import Link from 'next/link'
import { PageHeader } from '@/components/page-header'
import { LetterViewer } from '@/components/letter-viewer'
import { EmptyState } from '@/components/empty-state'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { useReport, useGenerateLetter } from '@/lib/hooks'
import type { ConsolidatedReport } from '@/lib/types'
import { ArrowLeft, Mail, Loader2, Play, FileText } from 'lucide-react'

const LETTER_TYPES = [
  {
    value: 'qualified_written_request',
    label: 'Qualified Written Request (QWR)',
    description:
      'Requests the servicer to provide account information and correct errors under RESPA Section 6.',
  },
  {
    value: 'notice_of_error',
    label: 'Notice of Error (NOE)',
    description:
      'Formally notifies the servicer of a specific error in the servicing of the loan under 12 CFR 1024.35.',
  },
  {
    value: 'request_for_information',
    label: 'Request for Information (RFI)',
    description:
      'Requests specific information about the mortgage loan under 12 CFR 1024.36.',
  },
] as const

export default function LetterPage({
  params,
}: {
  params: Promise<{ caseId: string }>
}) {
  const { caseId } = use(params)
  const [selectedType, setSelectedType] = useState<string>(
    'qualified_written_request'
  )

  const reportQuery = useReport(caseId)
  const generateLetter = useGenerateLetter(caseId)

  const report = reportQuery.data as ConsolidatedReport | undefined
  const existingLetter = report?.disputeLetter ?? null

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Link href={`/dashboard/cases/${caseId}/report`}>
          <Button variant="ghost" size="icon">
            <ArrowLeft className="h-4 w-4" />
          </Button>
        </Link>
        <PageHeader
          title="Dispute Letter"
          description="Generate and review RESPA-compliant dispute letters"
        />
      </div>

      {reportQuery.isLoading && (
        <div className="space-y-4">
          <Skeleton className="h-12 bg-gray-800" />
          <Skeleton className="h-96 bg-gray-800" />
        </div>
      )}

      {!reportQuery.isLoading && !report && (
        <EmptyState
          icon={FileText}
          title="No Report Available"
          description="You need to generate a consolidated report before creating a dispute letter."
        >
          <Link href={`/dashboard/cases/${caseId}/report`}>
            <Button>Go to Report</Button>
          </Link>
        </EmptyState>
      )}

      {report && !existingLetter && (
        <div className="space-y-6">
          {/* Letter type selection */}
          <div className="space-y-3">
            <h3 className="text-sm font-medium text-gray-300">
              Select Letter Type
            </h3>
            <div className="grid gap-3 md:grid-cols-3">
              {LETTER_TYPES.map((type) => (
                <button
                  key={type.value}
                  onClick={() => setSelectedType(type.value)}
                  className={`rounded-xl border p-4 text-left transition-all ${
                    selectedType === type.value
                      ? 'border-blue-500 bg-blue-500/5'
                      : 'border-gray-800 bg-gray-900 hover:border-gray-700'
                  }`}
                >
                  <div className="flex items-start gap-3">
                    <div
                      className={`mt-0.5 h-4 w-4 shrink-0 rounded-full border-2 ${
                        selectedType === type.value
                          ? 'border-blue-500 bg-blue-500'
                          : 'border-gray-600'
                      }`}
                    >
                      {selectedType === type.value && (
                        <div className="m-0.5 h-2 w-2 rounded-full bg-white" />
                      )}
                    </div>
                    <div>
                      <p className="text-sm font-medium text-gray-200">
                        {type.label}
                      </p>
                      <p className="mt-1 text-xs text-gray-500">
                        {type.description}
                      </p>
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </div>

          <Button
            onClick={() =>
              generateLetter.mutate({ letterType: selectedType })
            }
            disabled={generateLetter.isPending}
          >
            {generateLetter.isPending ? (
              <Loader2 className="mr-1.5 h-4 w-4 animate-spin" />
            ) : (
              <Play className="mr-1.5 h-4 w-4" />
            )}
            Generate Letter
          </Button>

          {generateLetter.isPending && (
            <Card className="bg-gray-900 border-gray-800">
              <CardContent className="flex items-center justify-center py-12">
                <div className="text-center">
                  <Loader2 className="mx-auto mb-3 h-8 w-8 animate-spin text-blue-400" />
                  <p className="text-sm text-gray-400">
                    Generating dispute letter...
                  </p>
                  <p className="mt-1 text-xs text-gray-500">
                    This may take up to 30 seconds
                  </p>
                </div>
              </CardContent>
            </Card>
          )}
        </div>
      )}

      {existingLetter && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Mail className="h-4 w-4 text-blue-400" />
              <span className="text-sm font-medium text-gray-300">
                Letter Generated
              </span>
            </div>
            <Button
              variant="outline"
              size="sm"
              onClick={() =>
                generateLetter.mutate({ letterType: selectedType })
              }
              disabled={generateLetter.isPending}
            >
              {generateLetter.isPending ? (
                <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
              ) : null}
              Regenerate
            </Button>
          </div>
          <LetterViewer letter={existingLetter} />
        </div>
      )}
    </div>
  )
}
