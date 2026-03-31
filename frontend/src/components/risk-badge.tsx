import { cn } from '@/lib/utils'
import { Badge } from '@/components/ui/badge'

type RiskBadgeLevel = 'critical' | 'high' | 'medium' | 'low' | 'clean' | 'info'

const levelStyles: Record<RiskBadgeLevel, string> = {
  critical: 'bg-red-500/15 text-red-400 border-red-500/30',
  high: 'bg-orange-500/15 text-orange-400 border-orange-500/30',
  medium: 'bg-yellow-500/15 text-yellow-400 border-yellow-500/30',
  low: 'bg-blue-500/15 text-blue-400 border-blue-500/30',
  clean: 'bg-green-500/15 text-green-400 border-green-500/30',
  info: 'bg-gray-500/15 text-gray-400 border-gray-500/30',
}

const levelLabels: Record<RiskBadgeLevel, string> = {
  critical: 'Critical',
  high: 'High',
  medium: 'Medium',
  low: 'Low',
  clean: 'Clean',
  info: 'Info',
}

interface RiskBadgeProps {
  level: RiskBadgeLevel
  label?: string
  className?: string
}

export function RiskBadge({ level, label, className }: RiskBadgeProps) {
  return (
    <Badge
      variant="outline"
      className={cn(levelStyles[level], className)}
    >
      {label ?? levelLabels[level]}
    </Badge>
  )
}
