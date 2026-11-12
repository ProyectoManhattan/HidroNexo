import { useMemo, useState } from 'react'
import { resolverReporte } from '../api/client'
import { SEVERIDADES, categoriaInfo, hace, urlFotoSegura } from '../constants'
import { comoOperador, seleccionarColonia, useStore } from '../store'
import type { Reporte } from '../types'
import { Badge, ErrorBox, Vacio, useAccion } from './sidebar/ui'

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
        <span className="flex h-full w-full items-center justify-center text-[10px] text-gray-400">Sin foto</span>
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
  const accion = useAccion()

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

  if (visibles.length === 0) return <Vacio icono="📭" texto="Sin reportes activos" />

  return (
    <div className="p-3">
      <ErrorBox texto={accion.error} />
      <ul className="space-y-2">
        {visibles.map((r) => {
          const cat = categoriaInfo(r.categoria)
          const colonia = r.colonia_id != null ? nombres.get(r.colonia_id) : undefined
          const clic = r.colonia_id != null
          return (
            <li
              key={r.id}
              onClick={() => clic && seleccionarColonia(r.colonia_id)}
              className={`rounded-lg border bg-white p-2.5 text-sm shadow-sm ${clic ? 'cursor-pointer hover:border-blue-400' : ''} ${
                r.colonia_id != null && r.colonia_id === seleccionada ? 'border-blue-500 ring-1 ring-blue-300' : 'border-gray-200'
              }`}
            >
              <div className="flex flex-wrap items-center gap-2">
                <span className="h-3 w-3 shrink-0 rounded-full" style={{ background: cat.color }} />
                <span className="font-medium text-gray-900">{cat.texto}</span>
                <Badge className="bg-gray-100 text-gray-600">Severidad {SEVERIDADES[r.severidad] ?? r.severidad}</Badge>
                <Badge className={r.origen === 'app' ? 'bg-blue-50 text-blue-700' : 'bg-purple-50 text-purple-700'}>
                  {r.origen === 'app' ? 'ciudadano' : r.origen === 'panel' ? 'manual' : 'ejemplo'}
                </Badge>
                <span className="ml-auto text-xs text-gray-400">{hace(r.creado_en)}</span>
              </div>
              {colonia && <div className="mt-0.5 text-xs text-gray-500">{colonia}</div>}
              {(r.descripcion || urlFotoSegura(r.foto_url)) && (
                <div className="mt-1 flex items-start gap-2">
                  <Miniatura url={r.foto_url} />
                  {r.descripcion && <p className="min-w-0 flex-1 truncate text-gray-700" title={r.descripcion}>{r.descripcion}</p>}
                </div>
              )}
              {(
                <div className="mt-1.5 text-right">
                  <button
                    disabled={accion.cargando !== null}
                    onClick={(e) => {
                      e.stopPropagation()
                      void accion.ejecutar(String(r.id), () => comoOperador(() => resolverReporte(r.id)))
                    }}
                    className="rounded border border-green-600 px-2 py-0.5 text-xs text-green-700 hover:bg-green-50 disabled:opacity-50"
                  >
                    {accion.cargando === String(r.id) ? 'Resolviendo…' : 'Marcar resuelto'}
                  </button>
                </div>
              )}
            </li>
          )
        })}
      </ul>
    </div>
  )
}
