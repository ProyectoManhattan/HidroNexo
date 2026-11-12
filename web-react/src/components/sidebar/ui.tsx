import { nivelInfo } from '../../constants'

export function NivelPill({ nivel }: { nivel?: string | null }) {
  const n = nivelInfo(nivel)
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-sm font-bold" style={{ background: n.suave, color: n.color }}>
      <span className="h-1.5 w-1.5 rounded-full bg-current" aria-hidden />{n.texto}
    </span>
  )
}

export function Badge({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return <span className={`inline-block rounded px-2 py-0.5 text-sm font-semibold ${className}`}>{children}</span>
}

export function ErrorBox({ texto }: { texto: string | null }) {
  if (!texto) return null
  return <div className="mb-2 rounded border border-red-200 bg-red-50 px-2 py-1 text-sm text-red-700">{texto}</div>
}

export function Vacio({ icono, texto, detalle }: { icono: string; texto: string; detalle?: string }) {
  return (
    <div className="flex flex-col items-center px-5 py-12 text-center text-slate-500">
      <span className="grid h-10 w-10 place-items-center rounded-full bg-slate-100 text-xl text-slate-600" aria-hidden>{icono}</span>
      <span className="mt-3 text-sm font-bold text-slate-700">{texto}</span>
      {detalle && <span className="mt-1 max-w-72 text-sm leading-relaxed">{detalle}</span>}
    </div>
  )
}
