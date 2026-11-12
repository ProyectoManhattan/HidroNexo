import { useState } from 'react'
import { hace } from '../constants'
import { useStore } from '../store'

export default function OfficialAlertsBanner() {
  const avisos = useStore((s) => s.avisosOficiales)
  const [abierto, setAbierto] = useState(false)
  if (!avisos || avisos.alertas.length === 0) return null
  const principal = avisos.alertas[0]
  return (
    <section className="z-20 mx-4 mt-3 overflow-hidden rounded-2xl border border-red-200 bg-red-50 text-red-950 shadow-sm" aria-label="Avisos hidrometeorológicos oficiales">
      <button type="button" onClick={() => setAbierto((v) => !v)} className="flex min-h-16 w-full items-center gap-4 px-5 py-2.5 text-left hover:bg-red-100/60" aria-expanded={abierto}>
        <svg viewBox="0 0 32 32" className="h-9 w-9 shrink-0 text-red-600" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden><path d="M16 3 29 27H3L16 3Z"/><path d="M16 11v8m0 4v.1" strokeLinecap="round"/></svg>
        <span className="min-w-0 flex-1">
          <span className="block truncate text-base font-extrabold text-red-900">{principal.titulo || 'Boletín de alerta hidrometeorológica general'}</span>
          <span className="block text-sm font-medium text-[#17326b]">{principal.institucion || avisos.fuente} · actualizado {hace(avisos.actualizado_en)}</span>
        </span>
        <span className="hidden text-sm font-semibold text-red-800 lg:inline">{principal.fenomenos.join(' · ')}</span>
        <span className="shrink-0 rounded-full border border-red-300 bg-white/50 px-5 py-2 text-sm font-extrabold text-red-700">{abierto ? 'Cerrar' : 'Ver más'} <span className="ml-1" aria-hidden>{abierto ? '↑' : '→'}</span></span>
      </button>
      {abierto && (
        <div className="grid max-h-[48vh] gap-4 overflow-y-auto border-t border-red-200 bg-white px-4 py-4 md:grid-cols-2 md:px-5">
          {avisos.alertas.map((a) => (
            <article key={a.id} className="rounded-xl border border-slate-200 bg-white p-4 text-[15px] shadow-sm">
              <div className="flex items-start justify-between gap-3">
                <h2 className="text-base font-extrabold text-slate-900">{a.titulo || 'Aviso oficial'}</h2>
                <span className="shrink-0 rounded bg-cyan-50 px-2.5 py-1 text-xs font-bold text-cyan-900">Vigente</span>
              </div>
              <p className="mt-1 text-sm font-semibold text-slate-600">{a.institucion || avisos.fuente}</p>
              <dl className="mt-3 grid grid-cols-[auto_1fr] gap-x-3 gap-y-1.5 text-sm text-slate-600">
                <dt>Emisión</dt><dd className="font-medium text-slate-800">{a.emitida_en ?? 'No indicada'}</dd>
                <dt>Expiración</dt><dd className="font-medium text-slate-800">{a.expira_en ?? 'No indicada'}</dd>
                <dt>Fenómenos</dt><dd className="font-medium text-slate-800">{a.fenomenos.join(', ') || a.tipo || 'No indicados'}</dd>
                <dt>Alcance</dt><dd className="font-medium text-slate-800">{a.alcance || 'Consulta la fuente'}</dd>
              </dl>
              {a.descripcion && <p className="mt-3 line-clamp-4 text-[15px] leading-relaxed text-slate-700">{a.descripcion}</p>}
              <div className="mt-4 flex flex-wrap gap-4 text-sm font-bold">
                <a href={a.detalle_url} target="_blank" rel="noreferrer" className="text-[var(--color-action-primary)] underline">Ver fuente original</a>
                {a.documento_url && <a href={a.documento_url} target="_blank" rel="noreferrer" className="text-[var(--color-action-primary)] underline">Abrir boletín</a>}
              </div>
            </article>
          ))}
          {avisos.desactualizado && <p className="rounded-lg border border-red-200 bg-red-50 p-3 text-sm font-medium text-red-800" role="status">La consulta está desactualizada. Confirma directamente en la fuente oficial.</p>}
        </div>
      )}
    </section>
  )
}
