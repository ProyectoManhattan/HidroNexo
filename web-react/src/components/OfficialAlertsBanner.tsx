import { useState } from 'react'
import { useStore } from '../store'

export default function OfficialAlertsBanner() {
  const avisos = useStore((s) => s.avisosOficiales)
  const [abierto, setAbierto] = useState(false)
  if (!avisos || avisos.alertas.length === 0) return null

  const principal = avisos.alertas[0]
  return (
    <section className="border-b border-amber-300 bg-amber-50 text-amber-950" aria-label="Alertamiento oficial">
      <button
        type="button"
        onClick={() => setAbierto((v) => !v)}
        className="flex w-full items-center gap-3 px-4 py-2 text-left hover:bg-amber-100"
        aria-expanded={abierto}
      >
        <span className="rounded bg-amber-600 px-2 py-0.5 text-[10px] font-black uppercase tracking-wide text-white">Oficial</span>
        <span className="min-w-0 flex-1 truncate text-sm font-semibold">{principal.titulo}</span>
        <span className="hidden text-xs text-amber-800 md:inline">{principal.fenomenos.join(' · ')}</span>
        <span className="text-xs font-semibold">{avisos.alertas.length} vigente{avisos.alertas.length === 1 ? '' : 's'} {abierto ? '▲' : '▼'}</span>
      </button>
      {abierto && (
        <div className="grid gap-3 border-t border-amber-200 px-4 py-3 md:grid-cols-2">
          {avisos.alertas.map((a) => (
            <article key={a.id} className="rounded-md border border-amber-200 bg-white/80 p-3 text-sm">
              <div className="flex items-start justify-between gap-2">
                <h2 className="font-bold">{a.titulo}</h2>
                <span className="shrink-0 text-xs font-semibold text-amber-700">{a.institucion}</span>
              </div>
              <div className="mt-1 text-xs text-slate-600">Emitido: {a.emitida_en ?? '—'} · Expira: {a.expira_en ?? '—'}</div>
              <div className="mt-1 text-xs font-semibold text-amber-800">{a.fenomenos.join(' · ') || a.tipo}</div>
              {a.descripcion && <p className="mt-2 line-clamp-3 text-xs leading-relaxed text-slate-700">{a.descripcion}</p>}
              <div className="mt-2 flex gap-3 text-xs font-semibold">
                <a href={a.detalle_url} target="_blank" rel="noreferrer" className="text-blue-700 hover:underline">Ver fuente oficial</a>
                {a.documento_url && <a href={a.documento_url} target="_blank" rel="noreferrer" className="text-blue-700 hover:underline">Abrir boletín</a>}
              </div>
            </article>
          ))}
          {avisos.desactualizado && <p className="text-xs text-red-700">La última consulta está desactualizada; confirma directamente en la fuente oficial.</p>}
        </div>
      )}
    </section>
  )
}
