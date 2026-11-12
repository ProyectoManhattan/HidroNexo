import { useMemo, useState } from 'react'
import { ApiError, resolverReporte } from '../api/client'
import { SEVERIDADES, categoriaInfo, hace, urlFotoSegura } from '../constants'
import { comoOperador, seleccionarColonia, useStore } from '../store'
import type { Reporte } from '../types'
import { Badge, Vacio } from './sidebar/ui'

function Miniatura({ url }: { url: string | null }) {
  const [fallo, setFallo] = useState(false)
  const src = urlFotoSegura(url)
  if (!src) return null
  return (
    <a
      href={src}
      target="_blank"
      rel="noopener noreferrer"
      onClick={(e) => e.stopPropagation()}
      title="Ver foto ampliada"
      className="block h-14 w-14 shrink-0 overflow-hidden rounded border border-gray-200 bg-gray-100"
    >
      {fallo ? (
        <span className="flex h-full w-full items-center justify-center text-xs text-gray-400">Sin foto</span>
      ) : (
        <img
          src={src}
          alt="Foto del reporte enviada por el ciudadano"
          loading="lazy"
          referrerPolicy="no-referrer"
          onError={() => setFallo(true)}
          className="h-full w-full object-cover"
        />
      )}
    </a>
  )
}

export default function ReportsList() {
  const reportes = useStore((s) => s.reportes)
  const filtro = useStore((s) => s.filtro)
  const zonas = useStore((s) => s.zonas)
  const seleccionada = useStore((s) => s.coloniaSeleccionada)
  const [resolviendo, setResolviendo] = useState<number | null>(null)
  const [error, setError] = useState<string | null>(null)

  async function resolver(id: number) {
    setResolviendo(id)
    setError(null)
    try {
      await comoOperador(() => resolverReporte(id))
    } catch (e) {
      setError(e instanceof ApiError && e.estado === 401
        ? 'Esta acción requiere una sesión administrativa segura.'
        : e instanceof Error ? e.message : 'No fue posible resolver el reporte.')
    } finally {
      setResolviendo(null)
    }
  }

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
      {error && <div className="mb-3 rounded-lg border border-red-200 bg-red-50 p-3 text-sm font-semibold text-red-700" role="alert">{error}</div>}
      <ul className="divide-y divide-slate-200 border-y border-slate-200">
        {visibles.map((r) => {
          const cat = categoriaInfo(r.categoria)
          const colonia = r.colonia_id != null ? nombres.get(r.colonia_id) : undefined
          const clic = r.colonia_id != null
          return (
            <li
              key={r.id}
              onClick={() => clic && seleccionarColonia(r.colonia_id)}
              onKeyDown={(e) => { if (e.target === e.currentTarget && clic && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); seleccionarColonia(r.colonia_id) } }}
              role={clic ? 'button' : undefined}
              tabIndex={clic ? 0 : undefined}
              className={`interactive-row py-3 text-base ${clic ? 'cursor-pointer px-2' : ''} ${r.colonia_id != null && r.colonia_id === seleccionada ? 'border-l-4 border-[var(--color-action-primary)] bg-cyan-50/50 pl-3' : ''}`}
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
              {(r.descripcion || urlFotoSegura(r.foto_url)) && (
                <div className="mt-2 flex items-start gap-3">
                  <Miniatura url={r.foto_url} />
                  {r.descripcion && <p className="min-w-0 flex-1 text-sm leading-relaxed text-gray-700" title={r.descripcion}>{r.descripcion}</p>}
                </div>
              )}
              <div className="mt-2 text-sm text-slate-500">Fuente: reporte recibido por el sistema · observación ciudadana no confirmada</div>
              <div className="mt-3 flex justify-end">
                <button
                  type="button"
                  disabled={resolviendo !== null}
                  onClick={(e) => { e.stopPropagation(); void resolver(r.id) }}
                  className="min-h-10 rounded-lg border border-emerald-600 bg-white px-3 text-sm font-bold text-emerald-700 hover:bg-emerald-50 disabled:opacity-50"
                >
                  {resolviendo === r.id ? 'Marcando como atendido…' : 'Marcar como atendido'}
                </button>
              </div>
            </li>
          )
        })}
      </ul>
    </div>
  )
}
