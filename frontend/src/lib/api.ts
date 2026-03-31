const API_BASE = '/api/v1'

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message)
    this.name = 'ApiError'
  }
}

async function fetchWithAuth(path: string, token: string, options?: RequestInit) {
  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
      ...options?.headers,
    },
  })

  if (!res.ok) {
    const error = await res.json().catch(() => ({ message: res.statusText }))
    throw new ApiError(res.status, error.message || 'Request failed')
  }

  return res.json()
}

function qs(params?: Record<string, string | number | undefined>): string {
  if (!params) return ''
  const entries = Object.entries(params).filter(([, v]) => v !== undefined)
  return new URLSearchParams(entries.map(([k, v]) => [k, String(v)])).toString()
}

export const api = {
  cases: {
    list: (token: string, params?: { status?: string; limit?: number; offset?: number }) =>
      fetchWithAuth(`/cases?${qs(params)}`, token),
    get: (token: string, id: string) =>
      fetchWithAuth(`/cases/${id}`, token),
    create: (token: string, data: { caseName: string; borrowerName?: string; propertyAddress?: string; loanNumber?: string; servicerName?: string; notes?: string }) =>
      fetchWithAuth('/cases', token, { method: 'POST', body: JSON.stringify(data) }),
    update: (token: string, id: string, data: Record<string, unknown>) =>
      fetchWithAuth(`/cases/${id}`, token, { method: 'PUT', body: JSON.stringify(data) }),
    delete: (token: string, id: string) =>
      fetchWithAuth(`/cases/${id}`, token, { method: 'DELETE' }),
    addDocument: (token: string, caseId: string, documentId: string) =>
      fetchWithAuth(`/cases/${caseId}/documents`, token, { method: 'POST', body: JSON.stringify({ documentId }) }),
    removeDocument: (token: string, caseId: string, documentId: string) =>
      fetchWithAuth(`/cases/${caseId}/documents/${documentId}`, token, { method: 'DELETE' }),
  },

  documents: {
    list: (token: string, params?: { limit?: number; offset?: number }) =>
      fetchWithAuth(`/documents?${qs(params)}`, token),
    get: (token: string, id: string) =>
      fetchWithAuth(`/documents/${id}`, token),
    upload: (token: string, data: { documentId: string; fileName: string; content: string; documentType?: string }) =>
      fetchWithAuth('/documents/upload', token, { method: 'POST', body: JSON.stringify(data) }),
    process: (token: string, data: { documentId: string; documentText?: string; fileBuffer?: string; documentType?: string }) =>
      fetchWithAuth('/documents/process', token, { method: 'POST', body: JSON.stringify(data) }),
    status: (token: string, id: string) =>
      fetchWithAuth(`/documents/${id}/status`, token),
    analysis: (token: string, id: string) =>
      fetchWithAuth(`/documents/${id}/analysis`, token),
    complete: (token: string, id: string) =>
      fetchWithAuth(`/documents/${id}/complete`, token, { method: 'POST' }),
    retry: (token: string, id: string) =>
      fetchWithAuth(`/documents/${id}/retry`, token, { method: 'POST' }),
  },

  forensic: {
    run: (token: string, caseId: string, data?: Record<string, unknown>) =>
      fetchWithAuth(`/cases/${caseId}/forensic-analysis`, token, { method: 'POST', body: JSON.stringify(data || {}) }),
    get: (token: string, caseId: string) =>
      fetchWithAuth(`/cases/${caseId}/forensic-analysis`, token),
  },

  compliance: {
    evaluate: (token: string, caseId: string, data?: Record<string, unknown>) =>
      fetchWithAuth(`/cases/${caseId}/compliance`, token, { method: 'POST', body: JSON.stringify(data || {}) }),
    get: (token: string, caseId: string) =>
      fetchWithAuth(`/cases/${caseId}/compliance`, token),
  },

  reports: {
    generate: (token: string, caseId: string, data?: { generateLetter?: boolean; letterType?: string; skipPersistence?: boolean }) =>
      fetchWithAuth(`/cases/${caseId}/report`, token, { method: 'POST', body: JSON.stringify(data || {}) }),
    get: (token: string, caseId: string) =>
      fetchWithAuth(`/cases/${caseId}/report`, token),
    generateLetter: (token: string, caseId: string, data: { letterType: string }) =>
      fetchWithAuth(`/cases/${caseId}/report/letter`, token, { method: 'POST', body: JSON.stringify(data) }),
  },

  health: {
    check: () => fetch('/health').then(r => r.json()),
  },
}
