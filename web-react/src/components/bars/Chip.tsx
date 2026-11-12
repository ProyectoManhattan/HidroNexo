import type { ReactNode } from 'react'

export default function Chip({ children, className = '', title }: { children: ReactNode; className?: string; title?: string }) {
  return (
    <span title={title} className={`inline-flex items-center gap-1.5 whitespace-nowrap rounded-full px-3 py-1 text-xs font-semibold ${className}`}>
      {children}
    </span>
  )
}
