'use client'

import { PieChart, Pie, Cell, ResponsiveContainer } from 'recharts'

function getScoreColor(score: number): string {
  if (score > 92) return '#30D158'   // green
  if (score > 75) return '#2997FF'   // blue
  if (score > 55) return '#FFD60A'   // yellow
  if (score > 30) return '#FF9F0A'   // orange
  return '#FF453A'                    // red
}

interface ConfidenceGaugeProps {
  score: number
  label?: string
  size?: number
}

export function ConfidenceGauge({
  score,
  label,
  size = 120,
}: ConfidenceGaugeProps) {
  const color = getScoreColor(score)
  const remaining = 100 - score
  const data = [
    { value: score },
    { value: remaining },
  ]

  return (
    <div className="flex flex-col items-center gap-1">
      <div className="relative" style={{ width: size, height: size }}>
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={data}
              cx="50%"
              cy="50%"
              innerRadius={size * 0.35}
              outerRadius={size * 0.45}
              startAngle={90}
              endAngle={-270}
              dataKey="value"
              strokeWidth={0}
            >
              <Cell fill={color} />
              <Cell fill="rgba(255,255,255,0.06)" />
            </Pie>
          </PieChart>
        </ResponsiveContainer>
        <div className="absolute inset-0 flex items-center justify-center">
          <span
            className="font-bold text-white"
            style={{ fontSize: size * 0.22 }}
          >
            {Math.round(score)}
          </span>
        </div>
      </div>
      {label && (
        <span className="text-xs font-medium text-gray-400">{label}</span>
      )}
    </div>
  )
}
