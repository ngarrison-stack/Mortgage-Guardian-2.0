'use client'

import { useState, useCallback } from 'react'
import { useDropzone } from 'react-dropzone'
import {
  useUploadDocument,
  useProcessDocument,
  useAddDocumentToCase,
} from '@/lib/hooks'
import { cn, formatFileSize } from '@/lib/utils'
import { DocumentStatus } from '@/components/document-status'
import { Button } from '@/components/ui/button'
import { Upload, FileText, CheckCircle2, AlertCircle, Loader2 } from 'lucide-react'

type UploadPhase = 'idle' | 'uploading' | 'processing' | 'complete' | 'failed'

interface DocumentUploadProps {
  caseId: string
  onUploadComplete?: () => void
}

export function DocumentUpload({ caseId, onUploadComplete }: DocumentUploadProps) {
  const [phase, setPhase] = useState<UploadPhase>('idle')
  const [documentId, setDocumentId] = useState<string | null>(null)
  const [selectedFile, setSelectedFile] = useState<File | null>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const uploadMutation = useUploadDocument()
  const processMutation = useProcessDocument()
  const addToCase = useAddDocumentToCase()

  const readFileAsBase64 = (file: File): Promise<string> => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onload = () => {
        const result = reader.result as string
        // Strip the data URI prefix (e.g. "data:application/pdf;base64,")
        const base64 = result.split(',')[1]
        resolve(base64)
      }
      reader.onerror = reject
      reader.readAsDataURL(file)
    })
  }

  const handleUpload = useCallback(
    async (file: File) => {
      setSelectedFile(file)
      setErrorMessage(null)

      const docId = crypto.randomUUID()
      setDocumentId(docId)

      try {
        setPhase('uploading')
        const base64 = await readFileAsBase64(file)

        await uploadMutation.mutateAsync({
          documentId: docId,
          fileName: file.name,
          content: base64,
          documentType: 'unknown',
        })

        setPhase('processing')

        await processMutation.mutateAsync({
          documentId: docId,
          fileBuffer: base64,
        })

        await addToCase.mutateAsync({
          caseId,
          documentId: docId,
        })

        setPhase('complete')
        onUploadComplete?.()
      } catch (err) {
        setPhase('failed')
        setErrorMessage(
          err instanceof Error ? err.message : 'An unexpected error occurred'
        )
      }
    },
    [caseId, uploadMutation, processMutation, addToCase, onUploadComplete]
  )

  const onDrop = useCallback(
    (acceptedFiles: File[]) => {
      if (acceptedFiles.length > 0) {
        handleUpload(acceptedFiles[0])
      }
    },
    [handleUpload]
  )

  const { getRootProps, getInputProps, isDragActive, fileRejections } =
    useDropzone({
      onDrop,
      accept: {
        'application/pdf': ['.pdf'],
        'image/*': ['.png', '.jpg', '.jpeg'],
      },
      maxSize: 20 * 1024 * 1024,
      multiple: false,
      disabled: phase === 'uploading' || phase === 'processing',
    })

  const reset = () => {
    setPhase('idle')
    setDocumentId(null)
    setSelectedFile(null)
    setErrorMessage(null)
  }

  return (
    <div className="space-y-6">
      <div
        {...getRootProps()}
        className={cn(
          'relative rounded-xl border-2 border-dashed p-8 text-center transition-all',
          'cursor-pointer hover:border-blue-500/50 hover:bg-blue-500/5',
          isDragActive && 'border-blue-500 bg-blue-500/10',
          phase === 'uploading' || phase === 'processing'
            ? 'pointer-events-none opacity-60'
            : 'border-gray-700',
          phase === 'complete' && 'border-green-500/30 bg-green-500/5',
          phase === 'failed' && 'border-red-500/30 bg-red-500/5'
        )}
      >
        <input {...getInputProps()} />

        {phase === 'idle' && !selectedFile && (
          <div className="flex flex-col items-center gap-3">
            <div className="rounded-full bg-gray-800 p-4">
              <Upload className="h-8 w-8 text-gray-400" />
            </div>
            <div>
              <p className="text-base font-medium text-white">
                {isDragActive
                  ? 'Drop the file here'
                  : 'Drop PDF or image files here'}
              </p>
              <p className="mt-1 text-sm text-gray-400">
                or click to browse. Maximum file size: 20MB
              </p>
            </div>
            <p className="text-xs text-gray-500">
              Supported formats: PDF, PNG, JPG, JPEG
            </p>
          </div>
        )}

        {selectedFile && (
          <div className="flex flex-col items-center gap-3">
            {phase === 'uploading' && (
              <Loader2 className="h-8 w-8 animate-spin text-blue-400" />
            )}
            {phase === 'processing' && (
              <Loader2 className="h-8 w-8 animate-spin text-blue-400" />
            )}
            {phase === 'complete' && (
              <CheckCircle2 className="h-8 w-8 text-green-400" />
            )}
            {phase === 'failed' && (
              <AlertCircle className="h-8 w-8 text-red-400" />
            )}

            <div className="flex items-center gap-2">
              <FileText className="h-5 w-5 text-gray-400" />
              <span className="text-sm font-medium text-white">
                {selectedFile.name}
              </span>
              <span className="text-xs text-gray-500">
                ({formatFileSize(selectedFile.size)})
              </span>
            </div>

            <p className="text-sm text-gray-400">
              {phase === 'uploading' && 'Uploading document...'}
              {phase === 'processing' && 'Processing document...'}
              {phase === 'complete' && 'Document processed successfully'}
              {phase === 'failed' && (errorMessage || 'Processing failed')}
            </p>
          </div>
        )}
      </div>

      {fileRejections.length > 0 && (
        <div className="rounded-lg border border-red-500/30 bg-red-500/5 px-4 py-3">
          <p className="text-sm text-red-400">
            {fileRejections[0].errors[0]?.message || 'File not accepted'}
          </p>
        </div>
      )}

      {phase === 'processing' && documentId && (
        <div className="rounded-xl border border-gray-800 bg-gray-900 p-6">
          <h3 className="mb-4 text-sm font-medium text-gray-400">
            Processing Pipeline
          </h3>
          <DocumentStatus documentId={documentId} />
        </div>
      )}

      {(phase === 'complete' || phase === 'failed') && (
        <div className="flex justify-center">
          <Button variant="outline" onClick={reset}>
            Upload Another Document
          </Button>
        </div>
      )}
    </div>
  )
}
