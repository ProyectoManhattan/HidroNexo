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
      {ejemplo ? 'datos de ejemplo' : f === 'modelada' ? 'modelada (relieve y cauces)' : f}
    </Badge>
  )
}

function Detalle({ z, reportes, fuente }: { z: ZonaProps; reportes: number; fuente?: string }) {
  const comp = z.componentes ?? { lluvia: 0, reportes: 0, vulnerabilidad: 0 }
  return (
    <div className="mt-3 border-t border-slate-200 pt-3">
      <div className="text-base text-gray-600">{z.municipio} · actualizado {hace(z.actualizado_en)}</div>
      <div className="mt-1.5 text-base text-gray-700">Motivo principal: <b>{MOTIVOS[z.motivo] ?? z.motivo}</b></div>
      <div className="text-base text-gray-700">Reportes activos: <b>{reportes}</b></div>
      <div className="mt-3 space-y-2">
        {(['lluvia', 'reportes', 'vulnerabilidad'] as const).map((k) => (
          <div key={k} className="flex items-center gap-2 text-base">
            <span className="w-24 capitalize text-gray-600">{k}</span>
            <div className="h-2 flex-1 rounded bg-gray-100">
              <div className="h-full rounded bg-[#126783]" style={{ width: `${Math.min(100, Math.round((comp[k] ?? 0) * 100))}%` }} />
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

  if (lista.length === 0) return <Vacio icono="◇" texto="Sin datos de zonas postales" detalle="El mapa territorial aún no ha entregado información." />

  const fuenteDe = (z: ZonaProps) => fuentes.get(z.id)
  return (
    <div className="p-4">
      <div className="mb-4">
        <h2 className="text-base font-extrabold text-slate-900">Riesgo por zona postal</h2>
        <p className="mt-1 text-sm leading-relaxed text-slate-600">Ordenado por nivel actual. Combina lluvia, reportes y vulnerabilidad; no equivale a una probabilidad exacta.</p>
      </div>
      <ul className="space-y-2">
        {lista.map((z, i) => {
          const n = nivelInfo(z.nivel)
          const pct = Math.min(100, Math.round((z.riesgo ?? 0) * 100))
          const fuente = fuenteDe(z)
          return (
            <li key={z.id} className={`rounded-xl border p-3 text-base transition-colors ${z.id === sel ? 'border-[#8eb4eb] bg-[#f5f8ff] shadow-sm' : 'border-slate-200 bg-white hover:border-[#b8ccec]'}`}>
              <button type="button" onClick={() => seleccionarColonia(z.id === sel ? null : z.id)} aria-expanded={z.id === sel} className="w-full text-left">
              <div className="flex items-center gap-2.5">
                <span className="w-6 text-sm font-semibold text-gray-400">{i + 1}</span>
                <span className="font-bold text-gray-900">{z.nombre}</span>
                <NivelPill nivel={z.nivel} />
                <span className="ml-auto text-base font-extrabold" style={{ color: n.color }}>{pct}</span>
                <span className="text-slate-400" aria-hidden>{z.id === sel ? '−' : '+'}</span>
              </div>
              <div className="mt-1.5 h-1.5 rounded bg-gray-100">
                <div className="h-full rounded" style={{ width: `${pct}%`, background: n.color }} />
              </div>
              <div className="mt-1.5 flex flex-wrap items-center gap-2 text-sm text-gray-500">
                <span>por {MOTIVOS[z.motivo] ?? z.motivo}</span>
                <Fuente f={fuente} />
              </div>
              </button>
              {z.id === sel && <Detalle z={z} reportes={conteo.get(z.id) ?? 0} fuente={fuente} />}
            </li>
          )
        })}
      </ul>
    </div>
  )
}
