'use client'

import { use } from 'react'
import Link from 'next/link'
import { Upload, Search, FileBarChart, User, Home, Hash, Building2 } from 'lucide-react'
import { useCase } from '@/lib/hooks'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { PageHeader } from '@/components/page-header'
import { RiskBadge } from '@/components/risk-badge'
import { DocumentList } from '@/components/document-list'
import type { CaseStatus } from '@/lib/types'

const statusConfig: Record<CaseStatus, { level: 'low' | 'medium' | 'clean' | 'info'; label: string }> = {
  open: { level: 'low', label: 'Open' },
  in_review: { level: 'medium', label: 'In Review' },
  complete: { level: 'clean', label: 'Complete' },
  archived: { level: 'info', label: 'Archived' },
}

function InfoItem({ icon: Icon, label, value }: { icon: React.ElementType; label: string; value?: string }) {
  return (
    <div className="flex items-start gap-3">
      <Icon className="h-4 w-4 mt-0.5 text-gray-500 shrink-0" />
      <div>
        <p className="text-xs text-gray-500">{label}</p>
        <p className="text-sm text-gray-200">{value || '--'}</p>
      </div>
    </div>
  )
}

export default function CaseDetailPage({ params }: { params: Promise<{ caseId: string }> }) {
  const { caseId } = use(params)
  const { data: caseData, isLoading } = useCase(caseId)

  if (isLoading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-40 rounded-xl" />
        <Skeleton className="h-60 rounded-xl" />
      </div>
    )
  }

  if (!caseData) {
    return (
      <div className="text-center py-16">
        <p className="text-gray-400">Case not found.</p>
      </div>
    )
  }

  const config = statusConfig[caseData.status]

  return (
    <div>
      <PageHeader title={caseData.caseName}>
        <RiskBadge level={config.level} label={config.label} />
        <Link href={`/dashboard/cases/${caseId}/upload`}>
          <Button variant="outline" className="border-gray-700 text-gray-300 hover:text-white">
            <Upload className="h-4 w-4" />
            Upload Document
          </Button>
        </Link>
        <Link href={`/dashboard/cases/${caseId}/analysis`}>
          <Button variant="outline" className="border-gray-700 text-gray-300 hover:text-white">
            <Search className="h-4 w-4" />
            Run Analysis
          </Button>
        </Link>
        <Link href={`/dashboard/cases/${caseId}/report`}>
          <Button className="bg-[#2997FF] text-white hover:bg-[#2080E0]">
            <FileBarChart className="h-4 w-4" />
            Generate Report
          </Button>
        </Link>
      </PageHeader>

      {/* Case info */}
      <Card className="bg-gray-900 border-gray-800 mb-6">
        <CardHeader>
          <CardTitle className="text-gray-200">Case Information</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            <InfoItem icon={User} label="Borrower" value={caseData.borrowerName} />
            <InfoItem icon={Home} label="Property" value={caseData.propertyAddress} />
            <InfoItem icon={Hash} label="Loan Number" value={caseData.loanNumber} />
            <InfoItem icon={Building2} label="Servicer" value={caseData.servicerName} />
          </div>
          {caseData.notes && (
            <div className="mt-4 pt-4 border-t border-gray-800">
              <p className="text-xs text-gray-500 mb-1">Notes</p>
              <p className="text-sm text-gray-300">{caseData.notes}</p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Documents */}
      <Card className="bg-gray-900 border-gray-800">
        <CardHeader>
          <CardTitle className="text-gray-200">Documents</CardTitle>
        </CardHeader>
        <CardContent>
          <DocumentList documents={caseData.documents ?? []} caseId={caseId} />
        </CardContent>
      </Card>
    </div>
  )
}
