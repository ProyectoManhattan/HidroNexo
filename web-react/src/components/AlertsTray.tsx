import { useMemo } from 'react'
import { MOTIVOS, hace } from '../constants'
import { useStore } from '../store'
import type { AlertaActiva } from '../types'
import { Badge, NivelPill, Vacio } from './sidebar/ui'

const masNuevo = (a: AlertaActiva, b: AlertaActiva) => new Date(b.creada_en).getTime() - new Date(a.creada_en).getTime()

function GuiaAlerta({ alerta }: { alerta: AlertaActiva }) {
  const guia = alerta.guia
  if (!guia?.pasos?.length) return null
  return (
    <details className="mt-3 rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-700">
      <summary className="cursor-pointer font-bold text-[var(--color-action-primary)]">{guia.titulo}</summary>
      <ol className="mt-2 list-decimal space-y-1 pl-4">{guia.pasos.map((paso, i) => <li key={i}>{paso}</li>)}</ol>
    </details>
  )
}

export default function AlertsTray() {
  const activas = useStore((s) => s.alertasActivas)
  const zonas = useStore((s) => s.zonas)
  const nombres = useMemo(() => new Map(zonas?.features.map((f) => [f.properties.id, f.properties.nombre])), [zonas])
  const vigentes = useMemo(() => [...(activas ?? [])].sort(masNuevo), [activas])
  return (
    <div className="p-4">
      <div className="mb-4 md:hidden">
        <h2 className="text-base font-extrabold text-slate-900">Alertas vigentes</h2>
        <p className="mt-1 text-sm leading-relaxed text-slate-600">Mensajes aprobados por Protección Civil. Los avisos de otras autoridades aparecen en la franja superior.</p>
      </div>
      <div className="mb-5 flex items-center gap-3 rounded-xl bg-[#eef3ff] px-4 py-3 text-sm font-semibold text-[#17499b]">
        <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full border-2 border-[#0d5ac7] text-base font-black" aria-hidden>i</span>
        Los boletines oficiales se muestran en la franja superior.
      </div>
      {vigentes.length === 0 ? (
        <Vacio icono="✓" texto="No hay alertas internas vigentes" detalle="Esto no garantiza ausencia de riesgo. Consulta el mapa y las fuentes oficiales." />
      ) : (
        <ul className="divide-y divide-slate-200 border-y border-slate-200">
          {vigentes.map((a) => (
            <li key={a.id} className="py-4 first:pt-3">
              <div className="flex flex-wrap items-center gap-2">
                <span className="font-bold text-slate-900">{nombres.get(a.colonia_id) ?? `Zona postal ${a.colonia_id}`}</span>
                <NivelPill nivel={a.nivel} />
                {a.simulada && <Badge className="border border-orange-300 bg-orange-50 text-orange-800">Simulación</Badge>}
                <span className="ml-auto text-sm text-slate-500">{hace(a.aprobada_en ?? a.creada_en)}</span>
              </div>
              <p className="mt-2 text-sm leading-relaxed text-slate-700">{a.texto}</p>
              <div className="mt-2 text-sm text-slate-500">Motivo: {MOTIVOS[a.motivo] ?? a.motivo} · Fuente: Protección Civil</div>
              <GuiaAlerta alerta={a} />
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
