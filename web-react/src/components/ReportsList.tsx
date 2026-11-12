import { useMemo } from 'react'
import { SEVERIDADES, categoriaInfo, hace } from '../constants'
import { seleccionarColonia, useStore } from '../store'
import type { Reporte } from '../types'
import { Badge, Vacio } from './sidebar/ui'

export default function ReportsList() {
  const reportes = useStore((s) => s.reportes)
  const filtro = useStore((s) => s.filtro)
  const zonas = useStore((s) => s.zonas)
  const seleccionada = useStore((s) => s.coloniaSeleccionada)

  const visibles = useMemo(() => {
    const lluvia = ['inundacion', 'encharcamiento', 'alcantarilla']
    const lista = (reportes ?? []).filter((r) => filtro === 'todo' || (filtro === 'lluvia') === lluvia.includes(r.categoria))
    // Más prioritarios primero (severidad ajustada por lluvia local); a igualdad, el más reciente
    const prioridad = (r: Reporte) => r.prioridad ?? r.severidad
    return [...lista].sort(
      (a, b) => prioridad(b) - prioridad(a) || new Date(b.creado_en).getTime() - new Date(a.creado_en).getTime(),
    )
  }, [reportes, filtro])

  const nombres = useMemo(() => {
    const m = new Map<number, string>()
    zonas?.features?.forEach((f) => m.set(f.properties.id, f.properties.nombre))
    return m
  }, [zonas])

  if (visibles.length === 0) return <Vacio icono="○" texto="Sin reportes activos" detalle="No se han recibido observaciones ciudadanas para este filtro." />

  return (
    <div className="p-4">
      <div className="mb-4">
        <h2 className="text-base font-extrabold text-slate-900">Reportes ciudadanos</h2>
        <p className="mt-1 text-sm leading-relaxed text-slate-600">Observaciones sin validación automática por una autoridad. Selecciona una para ubicar su zona postal.</p>
      </div>
      <ul className="divide-y divide-slate-200 border-y border-slate-200">
        {visibles.map((r) => {
          const cat = categoriaInfo(r.categoria)
          const colonia = r.colonia_id != null ? nombres.get(r.colonia_id) : undefined
          const clic = r.colonia_id != null
          return (
            <li
              key={r.id}
              onClick={() => clic && seleccionarColonia(r.colonia_id)}
              onKeyDown={(e) => { if (clic && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); seleccionarColonia(r.colonia_id) } }}
              role={clic ? 'button' : undefined}
              tabIndex={clic ? 0 : undefined}
              className={`interactive-row py-3 text-[15px] ${clic ? 'cursor-pointer px-2' : ''} ${r.colonia_id != null && r.colonia_id === seleccionada ? 'border-l-4 border-[var(--color-action-primary)] bg-cyan-50/50 pl-3' : ''}`}
            >
              <div className="flex flex-wrap items-center gap-2">
                <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full text-xs font-black text-white" style={{ background: cat.color }} aria-hidden>{cat.letra}</span>
                <span className="font-medium text-gray-900">{cat.texto}</span>
                <Badge className="bg-gray-100 text-gray-600">Severidad {SEVERIDADES[r.severidad] ?? r.severidad}</Badge>
                <Badge className={r.origen === 'app' ? 'bg-cyan-50 text-cyan-900' : 'bg-slate-100 text-slate-700'}>
                  {r.origen === 'app' ? 'Ciudadano' : r.origen === 'panel' ? 'Operador' : 'Ejemplo'}
                </Badge>
                <span className="ml-auto text-sm text-gray-500">{hace(r.creado_en)}</span>
              </div>
              {colonia && <div className="mt-1 text-sm text-gray-600">Zona postal: {colonia}</div>}
              {r.descripcion && <p className="mt-1 truncate text-gray-700" title={r.descripcion}>{r.descripcion}</p>}
              <div className="mt-1 text-[13px] text-slate-500">Fuente: reporte recibido por el sistema · expira automáticamente</div>
            </li>
          )
        })}
      </ul>
    </div>
  )
}
