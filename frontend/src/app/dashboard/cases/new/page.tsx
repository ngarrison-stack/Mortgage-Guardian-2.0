'use client'

import { useRouter } from 'next/navigation'
import { useCreateCase } from '@/lib/hooks'
import { PageHeader } from '@/components/page-header'
import { CaseForm } from '@/components/case-form'
import { Card, CardContent } from '@/components/ui/card'

export default function NewCasePage() {
  const router = useRouter()
  const createCase = useCreateCase()

  function handleSubmit(data: Parameters<typeof createCase.mutate>[0]) {
    createCase.mutate(data, {
      onSuccess: (newCase) => {
        router.push(`/dashboard/cases/${(newCase as { id: string }).id}`)
      },
    })
  }

  return (
    <div>
      <PageHeader
        title="New Case"
        description="Create a new mortgage audit case"
      />

      <Card className="bg-gray-900 border-gray-800">
        <CardContent>
          <CaseForm onSubmit={handleSubmit} isLoading={createCase.isPending} />
        </CardContent>
      </Card>
    </div>
  )
}
