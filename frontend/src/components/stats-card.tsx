import type { LucideIcon } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/card'

interface StatsCardProps {
  label: string
  value: string | number
  icon: LucideIcon
  trend?: string
}

export function StatsCard({ label, value, icon: Icon, trend }: StatsCardProps) {
  return (
    <Card className="bg-gray-900 border-gray-800">
      <CardContent className="flex items-center gap-4">
        <div className="rounded-lg bg-blue-500/10 p-2.5">
          <Icon className="h-5 w-5 text-blue-400" />
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-sm text-gray-400">{label}</p>
          <div className="flex items-baseline gap-2">
            <p className="text-2xl font-bold text-white">{value}</p>
            {trend && (
              <span className="text-xs font-medium text-green-400">{trend}</span>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
