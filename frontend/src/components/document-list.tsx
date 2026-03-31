'use client'

import { FileText } from 'lucide-react'
import {
  Table,
  TableHeader,
  TableBody,
  TableHead,
  TableRow,
  TableCell,
} from '@/components/ui/table'
import { RiskBadge } from '@/components/risk-badge'
import { EmptyState } from '@/components/empty-state'
import { formatRelativeTime } from '@/lib/utils'
import type { Document } from '@/lib/types'

interface DocumentListProps {
  documents: Document[]
  caseId: string
}

function anomalyLevel(count: number): 'critical' | 'high' | 'medium' | 'low' | 'clean' {
  if (count === 0) return 'clean'
  if (count <= 2) return 'low'
  if (count <= 5) return 'medium'
  if (count <= 10) return 'high'
  return 'critical'
}

export function DocumentList({ documents }: DocumentListProps) {
  if (documents.length === 0) {
    return (
      <EmptyState
        icon={FileText}
        title="No documents yet"
        description="Upload documents to this case to start the analysis process."
      />
    )
  }

  return (
    <Table>
      <TableHeader>
        <TableRow className="border-gray-800 hover:bg-transparent">
          <TableHead className="text-gray-400">File Name</TableHead>
          <TableHead className="text-gray-400">Type</TableHead>
          <TableHead className="text-gray-400">Anomalies</TableHead>
          <TableHead className="text-gray-400">Status</TableHead>
          <TableHead className="text-gray-400">Added</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {documents.map((doc) => {
          const anomalyCount = doc.analysis_report?.anomalies?.length ?? 0
          const hasReport = !!doc.analysis_report
          return (
            <TableRow key={doc.document_id} className="border-gray-800">
              <TableCell className="font-medium text-white">{doc.file_name}</TableCell>
              <TableCell className="text-gray-300 capitalize">{doc.document_type}</TableCell>
              <TableCell>
                <RiskBadge
                  level={anomalyLevel(anomalyCount)}
                  label={`${anomalyCount} found`}
                />
              </TableCell>
              <TableCell>
                <RiskBadge
                  level={hasReport ? 'clean' : 'info'}
                  label={hasReport ? 'Analyzed' : 'Pending'}
                />
              </TableCell>
              <TableCell className="text-gray-400">{formatRelativeTime(doc.created_at)}</TableCell>
            </TableRow>
          )
        })}
      </TableBody>
    </Table>
  )
}
