'use client'

import { useRouter } from 'next/navigation'
import {
  Table,
  TableHeader,
  TableBody,
  TableHead,
  TableRow,
  TableCell,
} from '@/components/ui/table'
import { Skeleton } from '@/components/ui/skeleton'
import { RiskBadge } from '@/components/risk-badge'
import { formatRelativeTime } from '@/lib/utils'
import type { Case, CaseStatus } from '@/lib/types'

const statusConfig: Record<CaseStatus, { level: 'low' | 'medium' | 'clean' | 'info'; label: string }> = {
  open: { level: 'low', label: 'Open' },
  in_review: { level: 'medium', label: 'In Review' },
  complete: { level: 'clean', label: 'Complete' },
  archived: { level: 'info', label: 'Archived' },
}

interface CaseTableProps {
  cases: Case[]
  isLoading: boolean
}

function LoadingRows() {
  return (
    <>
      {Array.from({ length: 4 }).map((_, i) => (
        <TableRow key={i}>
          <TableCell><Skeleton className="h-4 w-40" /></TableCell>
          <TableCell><Skeleton className="h-4 w-28" /></TableCell>
          <TableCell><Skeleton className="h-4 w-28" /></TableCell>
          <TableCell><Skeleton className="h-5 w-20" /></TableCell>
          <TableCell><Skeleton className="h-4 w-8" /></TableCell>
          <TableCell><Skeleton className="h-4 w-24" /></TableCell>
        </TableRow>
      ))}
    </>
  )
}

export function CaseTable({ cases, isLoading }: CaseTableProps) {
  const router = useRouter()

  return (
    <Table>
      <TableHeader>
        <TableRow className="border-gray-800 hover:bg-transparent">
          <TableHead className="text-gray-400">Case Name</TableHead>
          <TableHead className="text-gray-400">Borrower</TableHead>
          <TableHead className="text-gray-400">Servicer</TableHead>
          <TableHead className="text-gray-400">Status</TableHead>
          <TableHead className="text-gray-400">Documents</TableHead>
          <TableHead className="text-gray-400">Created</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {isLoading ? (
          <LoadingRows />
        ) : (
          cases.map((c) => {
            const config = statusConfig[c.status]
            return (
              <TableRow
                key={c.id}
                className="cursor-pointer border-gray-800 hover:bg-gray-800/50"
                onClick={() => router.push(`/dashboard/cases/${c.id}`)}
              >
                <TableCell className="font-medium text-white">{c.caseName}</TableCell>
                <TableCell className="text-gray-300">{c.borrowerName ?? '--'}</TableCell>
                <TableCell className="text-gray-300">{c.servicerName ?? '--'}</TableCell>
                <TableCell>
                  <RiskBadge level={config.level} label={config.label} />
                </TableCell>
                <TableCell className="text-gray-300">{c.documents?.length ?? 0}</TableCell>
                <TableCell className="text-gray-400">{formatRelativeTime(c.created_at)}</TableCell>
              </TableRow>
            )
          })
        )}
      </TableBody>
    </Table>
  )
}
