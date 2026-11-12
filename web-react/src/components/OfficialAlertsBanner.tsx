import { useState } from 'react'
import { hace } from '../constants'
import { useStore } from '../store'

export default function OfficialAlertsBanner() {
  const avisos = useStore((s) => s.avisosOficiales)
  const [abierto, setAbierto] = useState(false)
  if (!avisos || avisos.alertas.length === 0) return null
  const principal = avisos.alertas[0]
  return (
    <section className="z-20 border-b border-slate-200 bg-white text-slate-900" aria-label="Avisos hidrometeorológicos oficiales">
      <button type="button" onClick={() => setAbierto((v) => !v)} className="flex min-h-14 w-full items-center gap-3 border-l-4 border-cyan-700 px-4 py-2.5 text-left hover:bg-slate-50 md:px-5" aria-expanded={abierto}>
        <span className="shrink-0 rounded-md bg-[#0d536a] px-2.5 py-1 text-xs font-extrabold uppercase tracking-wide text-white">Boletín oficial</span>
        <span className="min-w-0 flex-1">
          <span className="block truncate text-base font-extrabold">{principal.titulo || 'Aviso hidrometeorológico vigente'}</span>
          <span className="hidden text-sm text-slate-600 sm:block">{principal.institucion || avisos.fuente} · actualizado {hace(avisos.actualizado_en)}</span>
        </span>
        <span className="hidden text-sm font-semibold text-slate-600 lg:inline">{principal.fenomenos.join(' · ')}</span>
        <span className="shrink-0 rounded-lg border border-slate-300 px-3 py-1.5 text-sm font-bold text-slate-700">{avisos.alertas.length} vigente{avisos.alertas.length === 1 ? '' : 's'} <span className="ml-1" aria-hidden>{abierto ? '−' : '+'}</span></span>
      </button>
      {abierto && (
        <div className="grid max-h-[48vh] gap-4 overflow-y-auto border-t border-slate-200 bg-slate-50 px-4 py-4 md:grid-cols-2 md:px-5">
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
