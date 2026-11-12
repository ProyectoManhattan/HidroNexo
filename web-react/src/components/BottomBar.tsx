import { useMemo } from 'react'
import { FILTROS } from '../constants'
import { getState, reportesVisibles, setFiltro, useStore } from '../store'
import type { Filtro } from '../types'

export default function BottomBar() {
  const filtro = useStore((s) => s.filtro)
  const reportes = useStore((s) => s.reportes)
  const zonas = useStore((s) => s.zonas)
  const nReportes = useMemo(() => reportesVisibles({ ...getState(), reportes, filtro }).length, [reportes, filtro])
  const nAltas = useMemo(() => zonas?.features.filter((f) => f.properties.nivel === 'alto' || f.properties.nivel === 'critico').length ?? 0, [zonas])

  return (
    <footer className="z-30 flex min-h-12 flex-wrap items-center gap-x-5 gap-y-2 border-t border-[var(--color-border)] bg-white px-3 py-2 text-sm md:px-5">
      <div className="flex items-center gap-2 overflow-x-auto" aria-label="Filtrar reportes">
        <span className="shrink-0 font-semibold text-slate-600">Mostrar</span>
        <div className="inline-flex shrink-0 overflow-hidden rounded-lg border border-slate-300" role="group">
          {(Object.keys(FILTROS) as Filtro[]).map((f) => (
            <button key={f} type="button" onClick={() => setFiltro(f)} aria-pressed={filtro === f} className={`min-h-8 border-r border-slate-200 px-3 font-semibold last:border-r-0 ${filtro === f ? 'bg-[var(--color-action-primary)] text-white' : 'bg-white text-slate-600 hover:bg-slate-50'}`}>
              {FILTROS[f]}
            </button>
          ))}
        </div>
      </div>
      <div className="hidden text-slate-600 sm:block"><b className="text-slate-900">{nReportes}</b> reportes activos · <b className="text-slate-900">{nAltas}</b> zonas postales en alto o crítico</div>
      <div className="ml-auto hidden items-center gap-3 text-slate-500 lg:flex">
        <span>Fuentes: Open-Meteo · Protección Civil · reportes ciudadanos</span>
        <span className="rounded bg-slate-100 px-2 py-1 font-semibold text-slate-700">Consulta pública</span>
        <span className="font-semibold text-red-700">Emergencias: 911</span>
      </div>
    </footer>
  )
}
