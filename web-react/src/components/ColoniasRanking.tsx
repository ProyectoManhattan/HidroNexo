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
  const n = nivelInfo(z.nivel)
  const comp = z.componentes ?? { lluvia: 0, reportes: 0, vulnerabilidad: 0 }
  const p = z.perfil_territorial
  return (
    <div className="mb-3 rounded-lg border-2 bg-white p-3" style={{ borderColor: n.color }}>
      <div className="flex items-center gap-2">
        <span className="font-semibold text-gray-900">{z.nombre}</span>
        <NivelPill nivel={z.nivel} />
        <button onClick={() => seleccionarColonia(null)} className="ml-auto min-h-9 px-2 text-sm font-semibold text-gray-500 hover:text-gray-800">Cerrar ×</button>
      </div>
      <div className="text-sm text-gray-500">{z.municipio} · riesgo {Math.round((z.riesgo ?? 0) * 100)}/100 · {hace(z.actualizado_en)}</div>
      <div className="mt-1.5 text-[15px] text-gray-700">Motivo principal: {MOTIVOS[z.motivo] ?? z.motivo}</div>
      <div className="text-[15px] text-gray-700">Reportes activos: <b>{reportes}</b></div>
      <div className="mt-2 space-y-1">
        {(['lluvia', 'reportes', 'vulnerabilidad'] as const).map((k) => (
          <div key={k} className="flex items-center gap-2 text-sm">
            <span className="w-24 capitalize text-gray-600">{k}</span>
            <div className="h-1.5 flex-1 rounded bg-gray-100">
              <div className="h-full rounded bg-[#126783]" style={{ width: `${Math.min(100, Math.round((comp[k] ?? 0) * 100))}%` }} />
            </div>
            <span className="w-8 text-right text-gray-500">{Math.round((comp[k] ?? 0) * 100)}</span>
          </div>
        ))}
      </div>
      {p && (
        <div className="mt-3 rounded-md bg-slate-50 p-3 text-sm text-slate-600">
          <div className="mb-1 flex items-center justify-between">
            <span className="font-semibold text-slate-800">Perfil territorial</span>
            <span className="font-semibold text-[#126783]">{Math.round(p.indice_susceptibilidad_preliminar ?? 0)}/100</span>
          </div>
          <div className="grid grid-cols-2 gap-x-3 gap-y-1">
            <span>Elevación mediana</span><b className="text-right">{p.elevacion_mediana_m?.toFixed(1) ?? '—'} m</b>
            <span>Altura sobre cauce</span><b className="text-right">{p.hand_mediana_m?.toFixed(1) ?? '—'} m</b>
            <span>Distancia al agua</span><b className="text-right">{p.distancia_cuerpo_agua_m != null ? Math.round(p.distancia_cuerpo_agua_m) : '—'} m</b>
            <span>Retorno lluvia 2 años</span><b className="text-right">{p.lluvia_24h_retorno_2a_mm?.toFixed(1) ?? '—'} mm</b>
            <span>Eventos documentados</span><b className="text-right">{p.eventos_inundacion_registrados ?? '—'}</b>
          </div>
          <div className="mt-2 border-t border-slate-200 pt-2 text-[13px] leading-relaxed text-slate-600">{p.advertencia}</div>
        </div>
      )}
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
  const elegida = lista.find((z) => z.id === sel)

  return (
    <div className="p-4">
      <div className="mb-4">
        <h2 className="text-base font-extrabold text-slate-900">Riesgo por zona postal</h2>
        <p className="mt-1 text-sm leading-relaxed text-slate-600">Ordenado por nivel actual. Combina lluvia, reportes y vulnerabilidad; no equivale a una probabilidad exacta.</p>
      </div>
      {elegida && <Detalle z={elegida} reportes={conteo.get(elegida.id) ?? 0} fuente={fuenteDe(elegida)} />}
      <ul className="divide-y divide-slate-200 border-y border-slate-200">
        {lista.map((z, i) => {
          const n = nivelInfo(z.nivel)
          const pct = Math.min(100, Math.round((z.riesgo ?? 0) * 100))
          const fuente = fuenteDe(z)
          return (
            <li
              key={z.id}
              onClick={() => seleccionarColonia(z.id)}
              onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); seleccionarColonia(z.id) } }}
              role="button"
              tabIndex={0}
              aria-pressed={z.id === sel}
              className={`interactive-row cursor-pointer py-3 text-[15px] ${z.id === sel ? 'border-l-4 border-[var(--color-action-primary)] bg-cyan-50/50 pl-3 pr-2' : 'px-2'}`}
            >
              <div className="flex items-center gap-2">
                <span className="w-6 text-sm font-semibold text-gray-400">{i + 1}</span>
                <span className="font-medium text-gray-900">{z.nombre}</span>
                <NivelPill nivel={z.nivel} />
                <span className="ml-auto text-sm font-bold" style={{ color: n.color }}>{pct}</span>
              </div>
              <div className="mt-1.5 h-1.5 rounded bg-gray-100">
                <div className="h-full rounded" style={{ width: `${pct}%`, background: n.color }} />
              </div>
              <div className="mt-1.5 flex flex-wrap items-center gap-2 text-sm text-gray-500">
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
