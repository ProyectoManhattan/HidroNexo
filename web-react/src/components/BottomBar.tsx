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
    <footer className="z-30 mx-4 mb-4 flex min-h-14 flex-wrap items-center gap-x-5 gap-y-2 rounded-2xl border border-[#d5e1f4] bg-white px-4 py-2 text-sm shadow-[0_6px_22px_rgb(30_64_175/.08)] max-md:mx-0 max-md:mb-0 max-md:rounded-none md:px-5">
      <div className="flex items-center gap-2 overflow-x-auto" aria-label="Filtrar reportes">
        <span className="shrink-0 font-semibold text-slate-600">Mostrar</span>
        <div className="inline-flex shrink-0 overflow-hidden rounded-full border border-[#d5e1f4] bg-white p-0.5" role="group">
          {(Object.keys(FILTROS) as Filtro[]).map((f) => (
            <button key={f} type="button" onClick={() => setFiltro(f)} aria-pressed={filtro === f} className={`min-h-8 rounded-full px-3 font-bold ${filtro === f ? 'bg-[#0d5ac7] text-white shadow-sm' : 'bg-white text-[#17499b] hover:bg-[#eef3ff]'}`}>
              {FILTROS[f]}
            </button>
          ))}
        </div>
      </div>
      <div className="hidden text-slate-600 sm:block"><b className="text-slate-900">{nReportes}</b> reportes activos · <b className="text-slate-900">{nAltas}</b> zonas postales en alto o crítico</div>
      <div className="ml-auto hidden items-center gap-3 text-slate-500 lg:flex">
        <span>Fuentes: Open-Meteo · Protección Civil · reportes ciudadanos</span>
      </div>
    </footer>
  )
}
