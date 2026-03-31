import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { cn } from '@/lib/utils'

const severityStyles: Record<string, string> = {
  critical: 'bg-red-500/10 text-red-400 border-red-500/30',
  high: 'bg-orange-500/10 text-orange-400 border-orange-500/30',
  medium: 'bg-yellow-500/10 text-yellow-400 border-yellow-500/30',
  low: 'bg-blue-500/10 text-blue-400 border-blue-500/30',
  info: 'bg-gray-500/10 text-gray-400 border-gray-500/30',
}

interface FindingCardProps {
  type: string
  severity: string
  description: string
  details?: Record<string, string>
}

export function FindingCard({
  type,
  severity,
  description,
  details,
}: FindingCardProps) {
  const severityKey = severity.toLowerCase()

  return (
    <Card className="bg-gray-900 border-gray-800">
      <CardContent className="space-y-3">
        <div className="flex items-center justify-between gap-3">
          <span className="text-xs font-medium uppercase tracking-wider text-gray-400">
            {type}
          </span>
          <Badge
            className={cn(
              'border text-xs capitalize',
              severityStyles[severityKey] ?? severityStyles.info
            )}
          >
            {severity}
          </Badge>
        </div>
        <p className="text-sm leading-relaxed text-gray-200">{description}</p>
        {details && Object.keys(details).length > 0 && (
          <div className="space-y-1.5 border-t border-gray-800 pt-3">
            {Object.entries(details).map(([key, value]) => (
              <div key={key} className="flex justify-between gap-4 text-xs">
                <span className="text-gray-500">{key}</span>
                <span className="text-right text-gray-300">{value}</span>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  )
}
