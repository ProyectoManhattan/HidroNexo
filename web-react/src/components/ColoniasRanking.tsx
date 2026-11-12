import { useEffect, useMemo, useState } from 'react'
import { getColonias } from '../api/client'
import { MOTIVOS, hace, nivelInfo } from '../constants'
import { seleccionarColonia, useStore } from '../store'
import type { ZonaProps } from '../types'
import { Badge, NivelPill, Vacio } from './sidebar/ui'

function Fuente({ f }: { f?: string }) {
  if (!f) return null
  const ejemplo = f === 'ejemplo'
  return (
    <Badge className={ejemplo ? 'border border-dashed border-orange-400 bg-orange-50 text-orange-700' : 'bg-gray-100 text-gray-600'}>
      {ejemplo ? 'datos de ejemplo' : f}
    </Badge>
  )
}

function Detalle({ z, reportes, fuente }: { z: ZonaProps; reportes: number; fuente?: string }) {
  const n = nivelInfo(z.nivel)
  const comp = z.componentes ?? { lluvia: 0, reportes: 0, vulnerabilidad: 0 }
  return (
    <div className="mb-3 rounded-lg border-2 bg-white p-3" style={{ borderColor: n.color }}>
      <div className="flex items-center gap-2">
        <span className="font-semibold text-gray-900">{z.nombre}</span>
        <NivelPill nivel={z.nivel} />
        <button onClick={() => seleccionarColonia(null)} className="ml-auto text-xs text-gray-500 hover:text-gray-800">Cerrar ✕</button>
      </div>
      <div className="text-xs text-gray-500">{z.municipio} · riesgo {Math.round((z.riesgo ?? 0) * 100)}/100 · {hace(z.actualizado_en)}</div>
      <div className="mt-1 text-sm text-gray-700">Motivo principal: {MOTIVOS[z.motivo] ?? z.motivo}</div>
      <div className="text-sm text-gray-700">Reportes activos: <b>{reportes}</b></div>
      <div className="mt-2 space-y-1">
        {(['lluvia', 'reportes', 'vulnerabilidad'] as const).map((k) => (
          <div key={k} className="flex items-center gap-2 text-xs">
            <span className="w-24 capitalize text-gray-600">{k}</span>
            <div className="h-1.5 flex-1 rounded bg-gray-100">
              <div className="h-full rounded bg-blue-600" style={{ width: `${Math.min(100, Math.round((comp[k] ?? 0) * 100))}%` }} />
            </div>
            <span className="w-8 text-right text-gray-500">{Math.round((comp[k] ?? 0) * 100)}</span>
          </div>
        ))}
      </div>
      <div className="mt-2"><Fuente f={fuente} /></div>
    </div>
  )
}

export default function ColoniasRanking() {
  const zonas = useStore((s) => s.zonas)
  const reportes = useStore((s) => s.reportes)
  const sel = useStore((s) => s.coloniaSeleccionada)

  const [fuentes, setFuentes] = useState<Map<number, string>>(new Map())
  useEffect(() => {
    getColonias()
      .then((cs) => setFuentes(new Map(cs.map((c) => [c.id, c.vulnerabilidad_fuente]))))
      .catch(() => {})
  }, [])

  const lista = useMemo(
    () => [...(zonas?.features ?? [])].map((f) => f.properties).sort((a, b) => (b.riesgo ?? 0) - (a.riesgo ?? 0)),
    [zonas],
  )
  const conteo = useMemo(() => {
    const m = new Map<number, number>()
    ;(reportes ?? []).forEach((r) => r.colonia_id != null && m.set(r.colonia_id, (m.get(r.colonia_id) ?? 0) + 1))
    return m
  }, [reportes])

  if (lista.length === 0) return <Vacio icono="🗺️" texto="Sin datos de colonias" />

  const fuenteDe = (z: ZonaProps) => fuentes.get(z.id)
  const elegida = lista.find((z) => z.id === sel)

  return (
    <div className="p-3">
      {elegida && <Detalle z={elegida} reportes={conteo.get(elegida.id) ?? 0} fuente={fuenteDe(elegida)} />}
      <ul className="space-y-2">
        {lista.map((z, i) => {
          const n = nivelInfo(z.nivel)
          const pct = Math.min(100, Math.round((z.riesgo ?? 0) * 100))
          const fuente = fuenteDe(z)
          return (
            <li
              key={z.id}
              onClick={() => seleccionarColonia(z.id)}
              className={`cursor-pointer rounded-lg border bg-white p-2.5 text-sm shadow-sm hover:border-blue-400 ${
                z.id === sel ? 'border-blue-500 ring-2 ring-blue-300' : 'border-gray-200'
              }`}
            >
              <div className="flex items-center gap-2">
                <span className="w-5 text-xs text-gray-400">{i + 1}</span>
                <span className="font-medium text-gray-900">{z.nombre}</span>
                <NivelPill nivel={z.nivel} />
                <span className="ml-auto text-xs font-semibold" style={{ color: n.color }}>{pct}</span>
              </div>
              <div className="mt-1.5 h-1.5 rounded bg-gray-100">
                <div className="h-full rounded" style={{ width: `${pct}%`, background: n.color }} />
              </div>
              <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-gray-500">
                <span>por {MOTIVOS[z.motivo] ?? z.motivo}</span>
                <Fuente f={fuente} />
              </div>
            </li>
          )
        })}
      </ul>
    </div>
  )
}
