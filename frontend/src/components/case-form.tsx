'use client'

import { useState } from 'react'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Label } from '@/components/ui/label'
import { Button } from '@/components/ui/button'

interface CaseFormData {
  caseName: string
  borrowerName?: string
  propertyAddress?: string
  loanNumber?: string
  servicerName?: string
  notes?: string
}

interface CaseFormProps {
  onSubmit: (data: CaseFormData) => void
  isLoading?: boolean
}

export function CaseForm({ onSubmit, isLoading = false }: CaseFormProps) {
  const [formData, setFormData] = useState<CaseFormData>({
    caseName: '',
    borrowerName: '',
    propertyAddress: '',
    loanNumber: '',
    servicerName: '',
    notes: '',
  })

  function handleChange(field: keyof CaseFormData, value: string) {
    setFormData((prev) => ({ ...prev, [field]: value }))
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    // Strip empty optional fields
    const cleaned: CaseFormData = { caseName: formData.caseName }
    if (formData.borrowerName) cleaned.borrowerName = formData.borrowerName
    if (formData.propertyAddress) cleaned.propertyAddress = formData.propertyAddress
    if (formData.loanNumber) cleaned.loanNumber = formData.loanNumber
    if (formData.servicerName) cleaned.servicerName = formData.servicerName
    if (formData.notes) cleaned.notes = formData.notes
    onSubmit(cleaned)
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5 max-w-xl">
      <div className="space-y-2">
        <Label htmlFor="caseName" className="text-gray-300">
          Case Name <span className="text-red-400">*</span>
        </Label>
        <Input
          id="caseName"
          required
          placeholder="e.g., Smith Mortgage Review"
          value={formData.caseName}
          onChange={(e) => handleChange('caseName', e.target.value)}
          className="bg-gray-900 border-gray-700 text-white placeholder:text-gray-500"
        />
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div className="space-y-2">
          <Label htmlFor="borrowerName" className="text-gray-300">Borrower Name</Label>
          <Input
            id="borrowerName"
            placeholder="Jane Smith"
            value={formData.borrowerName}
            onChange={(e) => handleChange('borrowerName', e.target.value)}
            className="bg-gray-900 border-gray-700 text-white placeholder:text-gray-500"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="servicerName" className="text-gray-300">Servicer Name</Label>
          <Input
            id="servicerName"
            placeholder="ABC Mortgage Co."
            value={formData.servicerName}
            onChange={(e) => handleChange('servicerName', e.target.value)}
            className="bg-gray-900 border-gray-700 text-white placeholder:text-gray-500"
          />
        </div>
      </div>

      <div className="space-y-2">
        <Label htmlFor="propertyAddress" className="text-gray-300">Property Address</Label>
        <Input
          id="propertyAddress"
          placeholder="123 Main St, City, ST 12345"
          value={formData.propertyAddress}
          onChange={(e) => handleChange('propertyAddress', e.target.value)}
          className="bg-gray-900 border-gray-700 text-white placeholder:text-gray-500"
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="loanNumber" className="text-gray-300">Loan Number</Label>
        <Input
          id="loanNumber"
          placeholder="LOAN-12345678"
          value={formData.loanNumber}
          onChange={(e) => handleChange('loanNumber', e.target.value)}
          className="bg-gray-900 border-gray-700 text-white placeholder:text-gray-500"
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="notes" className="text-gray-300">Notes</Label>
        <Textarea
          id="notes"
          placeholder="Any additional details about this case..."
          value={formData.notes}
          onChange={(e) => handleChange('notes', e.target.value)}
          className="bg-gray-900 border-gray-700 text-white placeholder:text-gray-500"
        />
      </div>

      <Button
        type="submit"
        disabled={isLoading || !formData.caseName.trim()}
        className="bg-[#2997FF] text-white hover:bg-[#2080E0]"
      >
        {isLoading ? 'Creating...' : 'Create Case'}
      </Button>
    </form>
  )
}
