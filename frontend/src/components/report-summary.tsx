import { Card, CardContent } from '@/components/ui/card'
import { RiskBadge } from '@/components/risk-badge'
import { ConfidenceGauge } from '@/components/confidence-gauge'
import { FileText, AlertTriangle } from 'lucide-react'
import type { ConsolidatedReport } from '@/lib/types'

interface ReportSummaryProps {
  report: ConsolidatedReport
}

export function ReportSummary({ report }: ReportSummaryProps) {
  const { overallRiskLevel, confidenceScore, findingSummary, caseSummary } =
    report

  return (
    <div className="space-y-6">
      {/* Summary stats grid */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {/* Risk Level */}
        <Card className="bg-gray-900 border-gray-800">
          <CardContent className="flex flex-col items-center justify-center py-2">
            <span className="mb-2 text-xs font-medium text-gray-400">
              Risk Level
            </span>
            <RiskBadge
              level={overallRiskLevel}
              className="px-3 py-1 text-sm"
            />
          </CardContent>
        </Card>

        {/* Confidence Score */}
        <Card className="bg-gray-900 border-gray-800">
          <CardContent className="flex items-center justify-center py-2">
            <ConfidenceGauge
              score={confidenceScore.overall}
              label="Confidence"
              size={100}
            />
          </CardContent>
        </Card>

        {/* Total Findings */}
        <Card className="bg-gray-900 border-gray-800">
          <CardContent className="flex flex-col items-center justify-center py-2">
            <div className="mb-1 rounded-lg bg-orange-500/10 p-2">
              <AlertTriangle className="h-5 w-5 text-orange-400" />
            </div>
            <span className="text-2xl font-bold text-white">
              {findingSummary.totalFindings}
            </span>
            <span className="text-xs text-gray-400">Total Findings</span>
          </CardContent>
        </Card>

        {/* Documents Analyzed */}
        <Card className="bg-gray-900 border-gray-800">
          <CardContent className="flex flex-col items-center justify-center py-2">
            <div className="mb-1 rounded-lg bg-blue-500/10 p-2">
              <FileText className="h-5 w-5 text-blue-400" />
            </div>
            <span className="text-2xl font-bold text-white">
              {caseSummary.documentCount}
            </span>
            <span className="text-xs text-gray-400">Documents Analyzed</span>
          </CardContent>
        </Card>
      </div>

      {/* Findings by severity */}
      {Object.keys(findingSummary.bySeverity).length > 0 && (
        <div className="space-y-2">
          <h3 className="text-sm font-medium text-gray-400">
            Findings by Severity
          </h3>
          <div className="flex flex-wrap gap-2">
            {Object.entries(findingSummary.bySeverity).map(
              ([severity, count]) => (
                <span
                  key={severity}
                  className="inline-flex items-center gap-1.5 rounded-full border border-gray-700 bg-gray-800 px-3 py-1 text-xs font-medium text-gray-300"
                >
                  <span className="capitalize">{severity}</span>
                  <span className="rounded-full bg-gray-700 px-1.5 py-0.5 text-white">
                    {count}
                  </span>
                </span>
              )
            )}
          </div>
        </div>
      )}

      {/* Findings by category */}
      {Object.keys(findingSummary.byCategory).length > 0 && (
        <div className="space-y-2">
          <h3 className="text-sm font-medium text-gray-400">
            Findings by Category
          </h3>
          <div className="flex flex-wrap gap-2">
            {Object.entries(findingSummary.byCategory).map(
              ([category, count]) => (
                <span
                  key={category}
                  className="inline-flex items-center gap-1.5 rounded-full border border-gray-700 bg-gray-800 px-3 py-1 text-xs font-medium text-gray-300"
                >
                  <span className="capitalize">{category}</span>
                  <span className="rounded-full bg-gray-700 px-1.5 py-0.5 text-white">
                    {count}
                  </span>
                </span>
              )
            )}
          </div>
        </div>
      )}
    </div>
  )
}
