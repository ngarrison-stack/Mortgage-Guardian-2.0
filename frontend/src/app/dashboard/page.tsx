'use client'

import Link from 'next/link'
import { FolderOpen, FileText, AlertTriangle, Briefcase, Plus } from 'lucide-react'
import { useCases } from '@/lib/hooks'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/skeleton'
import { PageHeader } from '@/components/page-header'
import { StatsCard } from '@/components/stats-card'
import { CaseTable } from '@/components/case-table'
import { EmptyState } from '@/components/empty-state'

export default function DashboardPage() {
  const { data: cases, isLoading } = useCases()

  const totalCases = cases?.length ?? 0
  const activeCases = cases?.filter((c) => c.status === 'open' || c.status === 'in_review').length ?? 0
  const totalDocuments = cases?.reduce((sum, c) => sum + (c.documents?.length ?? 0), 0) ?? 0
  const totalAnomalies = cases?.reduce((sum, c) => {
    return sum + (c.documents?.reduce((dSum, d) => dSum + (d.analysis_report?.anomalies?.length ?? 0), 0) ?? 0)
  }, 0) ?? 0

  return (
    <div>
      <PageHeader
        title="Dashboard"
        description="Overview of your mortgage audit cases"
      />

      {/* Stats grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        {isLoading ? (
          Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-24 rounded-xl" />
          ))
        ) : (
          <>
            <StatsCard label="Total Cases" value={totalCases} icon={Briefcase} />
            <StatsCard label="Active Cases" value={activeCases} icon={FolderOpen} />
            <StatsCard label="Documents" value={totalDocuments} icon={FileText} />
            <StatsCard label="Findings" value={totalAnomalies} icon={AlertTriangle} />
          </>
        )}
      </div>

      {/* Cases section */}
      <PageHeader title="Cases">
        <Link href="/dashboard/cases/new">
          <Button className="bg-[#2997FF] text-white hover:bg-[#2080E0]">
            <Plus className="h-4 w-4" />
            New Case
          </Button>
        </Link>
      </PageHeader>

      {isLoading ? (
        <CaseTable cases={[]} isLoading />
      ) : cases && cases.length > 0 ? (
        <CaseTable cases={cases} isLoading={false} />
      ) : (
        <EmptyState
          icon={FolderOpen}
          title="No cases yet"
          description="Create your first case to begin analyzing mortgage documents for servicer violations."
        >
          <Link href="/dashboard/cases/new">
            <Button className="bg-[#2997FF] text-white hover:bg-[#2080E0]">
              <Plus className="h-4 w-4" />
              Create Your First Case
            </Button>
          </Link>
        </EmptyState>
      )}
    </div>
  )
}
