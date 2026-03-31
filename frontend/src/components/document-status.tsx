'use client'

import { useDocumentStatus } from '@/lib/hooks'
import { cn } from '@/lib/utils'
import {
  Upload,
  ScanText,
  FolderSearch,
  Brain,
  ClipboardCheck,
  CheckCircle2,
  XCircle,
  Loader2,
} from 'lucide-react'

const PIPELINE_STEPS = [
  { key: 'uploaded', label: 'Upload', icon: Upload },
  { key: 'ocr', label: 'OCR', icon: ScanText },
  { key: 'classifying', label: 'Classify', icon: FolderSearch },
  { key: 'analyzing', label: 'Analyze', icon: Brain },
  { key: 'review', label: 'Review', icon: ClipboardCheck },
  { key: 'complete', label: 'Complete', icon: CheckCircle2 },
] as const

type StepState = 'pending' | 'active' | 'complete' | 'failed'

function getStepStates(
  currentStatus: string
): Record<string, StepState> {
  const stepKeys = PIPELINE_STEPS.map((s) => s.key)
  const currentIndex = stepKeys.indexOf(currentStatus as (typeof stepKeys)[number])

  const states: Record<string, StepState> = {}
  for (let i = 0; i < stepKeys.length; i++) {
    if (currentStatus === 'failed') {
      // Mark everything up to last active as complete, current as failed
      if (i < currentIndex) states[stepKeys[i]] = 'complete'
      else if (i === currentIndex) states[stepKeys[i]] = 'failed'
      else states[stepKeys[i]] = 'pending'
    } else if (i < currentIndex) {
      states[stepKeys[i]] = 'complete'
    } else if (i === currentIndex) {
      states[stepKeys[i]] = currentStatus === 'complete' ? 'complete' : 'active'
    } else {
      states[stepKeys[i]] = 'pending'
    }
  }
  return states
}

interface DocumentStatusProps {
  documentId: string
}

export function DocumentStatus({ documentId }: DocumentStatusProps) {
  const { data: status, isLoading } = useDocumentStatus(documentId)

  if (isLoading || !status) {
    return (
      <div className="flex items-center justify-center py-8">
        <Loader2 className="h-5 w-5 animate-spin text-gray-400" />
        <span className="ml-2 text-sm text-gray-400">Loading status...</span>
      </div>
    )
  }

  const stepStates = getStepStates(status.status)

  return (
    <div className="w-full">
      <div className="flex items-center justify-between">
        {PIPELINE_STEPS.map((step, index) => {
          const state = stepStates[step.key] ?? 'pending'
          const Icon = step.icon

          return (
            <div key={step.key} className="flex flex-1 items-center">
              <div className="flex flex-col items-center gap-1.5">
                <div
                  className={cn(
                    'flex h-10 w-10 items-center justify-center rounded-full border-2 transition-all',
                    state === 'complete' &&
                      'border-green-500 bg-green-500/10 text-green-400',
                    state === 'active' &&
                      'animate-pulse border-blue-500 bg-blue-500/10 text-blue-400',
                    state === 'failed' &&
                      'border-red-500 bg-red-500/10 text-red-400',
                    state === 'pending' &&
                      'border-gray-700 bg-gray-800/50 text-gray-500'
                  )}
                >
                  {state === 'complete' ? (
                    <CheckCircle2 className="h-5 w-5" />
                  ) : state === 'failed' ? (
                    <XCircle className="h-5 w-5" />
                  ) : (
                    <Icon className="h-5 w-5" />
                  )}
                </div>
                <span
                  className={cn(
                    'text-xs font-medium',
                    state === 'complete' && 'text-green-400',
                    state === 'active' && 'text-blue-400',
                    state === 'failed' && 'text-red-400',
                    state === 'pending' && 'text-gray-500'
                  )}
                >
                  {step.label}
                </span>
              </div>

              {index < PIPELINE_STEPS.length - 1 && (
                <div
                  className={cn(
                    'mx-2 h-0.5 flex-1',
                    state === 'complete' ? 'bg-green-500/50' : 'bg-gray-700'
                  )}
                />
              )}
            </div>
          )
        })}
      </div>

      {status.status === 'failed' && (
        <div className="mt-4 rounded-lg border border-red-500/30 bg-red-500/5 px-4 py-3">
          <p className="text-sm text-red-400">
            Processing failed. Please try uploading the document again.
          </p>
        </div>
      )}
    </div>
  )
}
