'use client'

import { use, useState } from 'react'
import Link from 'next/link'
import { PageHeader } from '@/components/page-header'
import { DocumentUpload } from '@/components/document-upload'
import { Button } from '@/components/ui/button'
import { ArrowLeft, CheckCircle2 } from 'lucide-react'

export default function UploadDocumentPage({
  params,
}: {
  params: Promise<{ caseId: string }>
}) {
  const { caseId } = use(params)
  const [uploadComplete, setUploadComplete] = useState(false)

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Link href={`/dashboard/cases/${caseId}`}>
          <Button variant="ghost" size="icon">
            <ArrowLeft className="h-4 w-4" />
          </Button>
        </Link>
        <PageHeader
          title="Upload Document"
          description="Upload mortgage documents for analysis"
        />
      </div>

      <DocumentUpload
        caseId={caseId}
        onUploadComplete={() => setUploadComplete(true)}
      />

      {uploadComplete && (
        <div className="rounded-xl border border-green-500/30 bg-green-500/5 p-6 text-center">
          <CheckCircle2 className="mx-auto mb-3 h-8 w-8 text-green-400" />
          <h3 className="text-base font-medium text-white">
            Document uploaded successfully
          </h3>
          <p className="mt-1 text-sm text-gray-400">
            Your document has been processed and added to the case.
          </p>
          <div className="mt-4 flex items-center justify-center gap-3">
            <Link href={`/dashboard/cases/${caseId}`}>
              <Button variant="outline">Back to Case</Button>
            </Link>
            <Link href={`/dashboard/cases/${caseId}/analysis`}>
              <Button>Run Analysis</Button>
            </Link>
          </div>
        </div>
      )}
    </div>
  )
}
