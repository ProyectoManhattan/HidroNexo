import { useMemo, useState } from 'react'
import { aprobarAlerta, descartarAlerta, editarAlerta } from '../api/client'
import { MOTIVOS, hace } from '../constants'
import { comoOperador, useStore } from '../store'
import type { Alerta } from '../types'
import { Badge, ErrorBox, NivelPill, Vacio, useAccion } from './sidebar/ui'

const masNuevo = (a: Alerta, b: Alerta) => new Date(b.creada_en).getTime() - new Date(a.creada_en).getTime()

function Tarjeta({ alerta, nombre, accion }: { alerta: Alerta; nombre: string; accion: ReturnType<typeof useAccion> }) {
  const [texto, setTexto] = useState(alerta.texto)
  const k = (s: string) => `${s}${alerta.id}`
  const ocupado = accion.cargando !== null
  const cambiado = texto.trim() !== alerta.texto && texto.trim().length > 0

  return (
    <div className="rounded-lg border border-gray-200 bg-white p-3 shadow-sm">
      <div className="mb-1 flex flex-wrap items-center gap-2">
        <span className="font-semibold text-gray-900">{nombre}</span>
        <NivelPill nivel={alerta.nivel} />
        <span className="text-xs text-gray-500">por {MOTIVOS[alerta.motivo] ?? alerta.motivo}</span>
        {alerta.simulada && <Badge className="bg-orange-100 text-orange-700">simulada</Badge>}
        <Badge className="bg-gray-100 text-gray-600">{alerta.redactada_por === 'llm' ? 'IA' : alerta.redactada_por === 'manual' ? 'manual' : 'plantilla'}</Badge>
        <span className="ml-auto text-xs text-gray-400">{hace(alerta.creada_en)}</span>
      </div>
      <textarea
        value={texto}
        onChange={(e) => setTexto(e.target.value)}
        rows={4}
        className="mt-1 w-full resize-y rounded border border-gray-300 p-2 text-sm focus:border-blue-500 focus:outline-none"
      />
      <div className="mt-2 flex flex-wrap gap-2">
        <button
          disabled={ocupado || !cambiado}
          onClick={() => accion.ejecutar(k('g'), () => comoOperador(() => editarAlerta(alerta.id, texto.trim())))}
          className="rounded border border-gray-300 px-3 py-1 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-40"
        >
          {accion.cargando === k('g') ? 'Guardando…' : 'Guardar'}
        </button>
        <button
          disabled={ocupado}
          onClick={() => {
            if (!window.confirm('Se enviará a los dispositivos de la colonia. ¿Aprobar y enviar?')) return
            void accion.ejecutar(k('a'), () => comoOperador(() => aprobarAlerta(alerta.id)))
          }}
          className="rounded bg-blue-700 px-3 py-1 text-sm font-medium text-white hover:bg-blue-800 disabled:opacity-50"
        >
          {accion.cargando === k('a') ? 'Enviando…' : 'Aprobar y enviar'}
        </button>
        <button
          disabled={ocupado}
          onClick={() => accion.ejecutar(k('d'), () => comoOperador(() => descartarAlerta(alerta.id)))}
          className="rounded border border-red-300 px-3 py-1 text-sm text-red-700 hover:bg-red-50 disabled:opacity-50"
        >
          {accion.cargando === k('d') ? 'Descartando…' : 'Descartar'}
        </button>
      </div>
    </div>
  )
}

export default function AlertsTray() {
  const propuestas = useStore((s) => s.alertasPropuestas)
  const activas = useStore((s) => s.alertasActivas)
  const zonas = useStore((s) => s.zonas)
  const accion = useAccion()

  const nombres = useMemo(() => {
    const m = new Map<number, string>()
    zonas?.features?.forEach((f) => m.set(f.properties.id, f.properties.nombre))
    return m
  }, [zonas])
  const nombreDe = (id: number) => nombres.get(id) ?? `Colonia ${id}`

  const ordenadas = useMemo(() => [...(propuestas ?? [])].sort(masNuevo), [propuestas])
  const vigentes = useMemo(() => [...(activas ?? [])].sort(masNuevo), [activas])

  return (
    <div className="space-y-3 p-3">
      <ErrorBox texto={accion.error} />
      {ordenadas.length === 0 ? (
        <Vacio icono="✅" texto="Sin alertas pendientes" />
      ) : (
        ordenadas.map((a) => <Tarjeta key={a.id} alerta={a} nombre={nombreDe(a.colonia_id)} accion={accion} />)
      )}

      <section>
        <h3 className="mb-2 mt-4 text-xs font-semibold uppercase tracking-wide text-gray-500">
          Alertas enviadas y vigentes ({vigentes.length})
        </h3>
        {vigentes.length === 0 ? (
          <p className="text-xs text-gray-400">Ninguna alerta vigente.</p>
        ) : (
          <ul className="space-y-2">
            {vigentes.map((a) => (
              <li key={a.id} className="rounded border border-gray-200 bg-gray-50 p-2 text-sm">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-medium">{nombreDe(a.colonia_id)}</span>
                  <NivelPill nivel={a.nivel} />
                  {a.simulada && <Badge className="bg-orange-100 text-orange-700">simulada</Badge>}
                  {a.redactada_por === 'manual' && <Badge className="bg-purple-50 text-purple-700">manual</Badge>}
                  <span className="ml-auto text-xs text-gray-400">{hace(a.aprobada_en ?? a.creada_en)}</span>
                </div>
                <p className="mt-1 text-gray-700">{a.texto}</p>
                {a.guia && a.guia.pasos?.length > 0 && (
                  <div className="mt-1 text-xs text-gray-600">
                    <div className="font-semibold">{a.guia.titulo}</div>
                    <ol className="list-decimal pl-4">
                      {a.guia.pasos.map((p, i) => <li key={i}>{p}</li>)}
                    </ol>
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  )
}
