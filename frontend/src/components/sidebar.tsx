'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { LayoutDashboard, FolderOpen, FileText } from 'lucide-react'
import { cn } from '@/lib/utils'

const navItems = [
  { label: 'Dashboard', href: '/dashboard', icon: LayoutDashboard },
  { label: 'Cases', href: '/dashboard/cases', icon: FolderOpen },
  { label: 'Documents', href: '/dashboard/documents', icon: FileText },
]

interface SidebarProps {
  collapsed?: boolean
  className?: string
}

function ShieldLogo() {
  return (
    <svg width="28" height="28" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M20 2L4 10v12c0 9.6 6.8 18.6 16 20.8 9.2-2.2 16-11.2 16-20.8V10L20 2z" fill="#2997FF" fillOpacity="0.15" stroke="#2997FF" strokeWidth="2"/>
      <path d="M16 20l4 4 8-8" stroke="#30D158" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  )
}

export function Sidebar({ collapsed = false, className }: SidebarProps) {
  const pathname = usePathname()

  return (
    <aside
      className={cn(
        'flex h-full flex-col border-r border-gray-800 bg-gray-950',
        collapsed ? 'w-16' : 'w-60',
        className
      )}
    >
      <div className={cn(
        'flex h-14 items-center gap-2 border-b border-gray-800 px-4',
        collapsed && 'justify-center px-0'
      )}>
        <ShieldLogo />
        {!collapsed && (
          <span className="text-white font-semibold text-base">Mortgage Guardian</span>
        )}
      </div>

      <nav className="flex-1 py-3 px-2 space-y-1">
        {navItems.map((item) => {
          const isActive =
            item.href === '/dashboard'
              ? pathname === '/dashboard'
              : pathname.startsWith(item.href)

          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors',
                collapsed && 'justify-center px-0',
                isActive
                  ? 'bg-blue-500/10 text-blue-400 border-l-2 border-blue-400'
                  : 'text-gray-400 hover:text-gray-200 hover:bg-gray-800/50'
              )}
            >
              <item.icon className="h-4 w-4 shrink-0" />
              {!collapsed && <span>{item.label}</span>}
            </Link>
          )
        })}
      </nav>
    </aside>
  )
}
