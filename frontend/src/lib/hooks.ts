'use client'

import { useAuth } from '@clerk/nextjs'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useCallback } from 'react'
import { api } from './api'
import type { Case, ConsolidatedReport, PipelineStatus } from './types'

// --------------------------------------------------------------------------
// Auth token hook
// --------------------------------------------------------------------------

export function useApiToken() {
  const { getToken } = useAuth()
  return useCallback(async () => {
    const token = await getToken()
    if (!token) throw new Error('Not authenticated')
    return token
  }, [getToken])
}

// --------------------------------------------------------------------------
// Cases
// --------------------------------------------------------------------------

export function useCases(params?: { status?: string }) {
  const getToken = useApiToken()
  return useQuery<Case[]>({
    queryKey: ['cases', params],
    queryFn: async () => {
      const token = await getToken()
      return api.cases.list(token, params)
    },
  })
}

export function useCase(caseId: string) {
  const getToken = useApiToken()
  return useQuery<Case>({
    queryKey: ['cases', caseId],
    queryFn: async () => {
      const token = await getToken()
      return api.cases.get(token, caseId)
    },
    enabled: !!caseId,
  })
}

export function useCreateCase() {
  const getToken = useApiToken()
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (data: { caseName: string; borrowerName?: string; propertyAddress?: string; loanNumber?: string; servicerName?: string }) => {
      const token = await getToken()
      return api.cases.create(token, data)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cases'] })
    },
  })
}

export function useUpdateCase(caseId: string) {
  const getToken = useApiToken()
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (data: Record<string, unknown>) => {
      const token = await getToken()
      return api.cases.update(token, caseId, data)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cases'] })
    },
  })
}

export function useDeleteCase() {
  const getToken = useApiToken()
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (caseId: string) => {
      const token = await getToken()
      return api.cases.delete(token, caseId)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cases'] })
    },
  })
}

// --------------------------------------------------------------------------
// Documents
// --------------------------------------------------------------------------

export function useUploadDocument() {
  const getToken = useApiToken()
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (data: { documentId: string; fileName: string; content: string; documentType?: string }) => {
      const token = await getToken()
      return api.documents.upload(token, data)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cases'] })
    },
  })
}

export function useProcessDocument() {
  const getToken = useApiToken()
  return useMutation({
    mutationFn: async (data: { documentId: string; fileBuffer?: string; documentText?: string; documentType?: string }) => {
      const token = await getToken()
      return api.documents.process(token, data)
    },
  })
}

export function useDocumentStatus(documentId: string | null) {
  const getToken = useApiToken()
  return useQuery<PipelineStatus>({
    queryKey: ['document-status', documentId],
    queryFn: async () => {
      const token = await getToken()
      return api.documents.status(token, documentId!)
    },
    enabled: !!documentId,
    refetchInterval: (query) => {
      const status = query.state.data?.status
      if (status === 'complete' || status === 'failed') return false
      return 2000
    },
  })
}

export function useAddDocumentToCase() {
  const getToken = useApiToken()
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async ({ caseId, documentId }: { caseId: string; documentId: string }) => {
      const token = await getToken()
      return api.cases.addDocument(token, caseId, documentId)
    },
    onSuccess: (_, { caseId }) => {
      queryClient.invalidateQueries({ queryKey: ['cases', caseId] })
    },
  })
}

// --------------------------------------------------------------------------
// Forensic Analysis
// --------------------------------------------------------------------------

export function useRunForensicAnalysis(caseId: string) {
  const getToken = useApiToken()
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (data?: Record<string, unknown>) => {
      const token = await getToken()
      return api.forensic.run(token, caseId, data)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['forensic', caseId] })
      queryClient.invalidateQueries({ queryKey: ['cases', caseId] })
    },
  })
}

export function useForensicAnalysis(caseId: string) {
  const getToken = useApiToken()
  return useQuery({
    queryKey: ['forensic', caseId],
    queryFn: async () => {
      const token = await getToken()
      return api.forensic.get(token, caseId)
    },
    enabled: !!caseId,
    retry: false,
  })
}

// --------------------------------------------------------------------------
// Compliance
// --------------------------------------------------------------------------

export function useRunComplianceEvaluation(caseId: string) {
  const getToken = useApiToken()
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (data?: Record<string, unknown>) => {
      const token = await getToken()
      return api.compliance.evaluate(token, caseId, data)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['compliance', caseId] })
      queryClient.invalidateQueries({ queryKey: ['cases', caseId] })
    },
  })
}

export function useComplianceReport(caseId: string) {
  const getToken = useApiToken()
  return useQuery({
    queryKey: ['compliance', caseId],
    queryFn: async () => {
      const token = await getToken()
      return api.compliance.get(token, caseId)
    },
    enabled: !!caseId,
    retry: false,
  })
}

// --------------------------------------------------------------------------
// Reports
// --------------------------------------------------------------------------

export function useGenerateReport(caseId: string) {
  const getToken = useApiToken()
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (data?: { generateLetter?: boolean; letterType?: string }) => {
      const token = await getToken()
      return api.reports.generate(token, caseId, data)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['report', caseId] })
      queryClient.invalidateQueries({ queryKey: ['cases', caseId] })
    },
  })
}

export function useReport(caseId: string) {
  const getToken = useApiToken()
  return useQuery<ConsolidatedReport>({
    queryKey: ['report', caseId],
    queryFn: async () => {
      const token = await getToken()
      return api.reports.get(token, caseId)
    },
    enabled: !!caseId,
    retry: false,
  })
}

export function useGenerateLetter(caseId: string) {
  const getToken = useApiToken()
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (data: { letterType: string }) => {
      const token = await getToken()
      return api.reports.generateLetter(token, caseId, data)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['report', caseId] })
    },
  })
}
