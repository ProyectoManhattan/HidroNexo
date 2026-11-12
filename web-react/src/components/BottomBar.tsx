import { useEffect, useMemo, useRef, useState } from 'react'
import { adminReset, adminSeed, simularTormenta, terminarTormenta } from '../api/client'
import { FILTROS, NARANJA_SIM } from '../constants'
import {
  abrirDialogoClave, abrirDialogoManual, comoOperador, getState, reportesVisibles, setFiltro, useStore,
} from '../store'
import type { Filtro } from '../types'

const msgError = (e: unknown) => (e instanceof Error ? e.message : 'Error desconocido')

export default function BottomBar() {
  const filtro = useStore((s) => s.filtro)
  const reportes = useStore((s) => s.reportes)
  const zonas = useStore((s) => s.zonas)
  const sim = useStore((s) => s.clima?.simulacion ?? false)
  const clave = useStore((s) => s.operadorClave)
  const [ocupado, setOcupado] = useState<string | null>(null)
  const [aviso, setAviso] = useState<{ ok: boolean; texto: string } | null>(null)
  const [menu, setMenu] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)

  const nReportes = useMemo(() => reportesVisibles({ ...getState(), reportes, filtro }).length, [reportes, filtro])
  const nAltas = useMemo(
    () => zonas?.features.filter((f) => f.properties.nivel === 'alto' || f.properties.nivel === 'critico').length ?? 0,
    [zonas],
  )

  useEffect(() => {
    if (!menu) return
    const cerrar = (e: MouseEvent) => { if (!menuRef.current?.contains(e.target as Node)) setMenu(false) }
    document.addEventListener('mousedown', cerrar)
    return () => document.removeEventListener('mousedown', cerrar)
  }, [menu])

  useEffect(() => {
    if (!aviso?.ok) return
    const t = setTimeout(() => setAviso(null), 6000)
    return () => clearTimeout(t)
  }, [aviso])

  async function ejecutar<T>(nombre: string, accion: () => Promise<T>, ok: (r: T) => string) {
    setOcupado(nombre)
    setAviso(null)
    try {
      const r = await comoOperador(accion)
      if (r !== undefined) setAviso({ ok: true, texto: ok(r) })
    } catch (e) {
      setAviso({ ok: false, texto: msgError(e) })
    } finally {
      setOcupado(null)
    }
  }

  const alternarSim = () =>
    sim
      ? ejecutar('sim', () => terminarTormenta(), () => 'Simulación terminada')
      : ejecutar('sim', () => simularTormenta(1), () => 'Tormenta simulada activa')

  const seed = () => {
    setMenu(false)
    void ejecutar('seed', () => adminSeed(), (r) => `${r.colonias} colonias, ${r.reportes} reportes cargados`)
  }
  const reset = () => {
    setMenu(false)
    if (!window.confirm('¿Reiniciar todos los datos? Se borrarán reportes y alertas.')) return
    void ejecutar('reset', () => adminReset(), () => 'Datos reiniciados')
  }
  const manual = () => (clave ? abrirDialogoManual() : abrirDialogoClave())

  const btn = 'rounded-md px-3 py-1.5 text-sm font-semibold disabled:opacity-60'

  return (
    <footer className="relative flex flex-wrap items-center gap-x-4 gap-y-2 border-t border-gray-200 bg-white px-4 py-2 text-sm">
      <div className="flex items-center gap-2">
        <span className="text-gray-600">Mostrar:</span>
        <div className="inline-flex overflow-hidden rounded-md border border-gray-300" role="group">
          {(Object.keys(FILTROS) as Filtro[]).map((f) => (
            <button
              key={f}
              onClick={() => setFiltro(f)}
              aria-pressed={filtro === f}
              className={`px-3 py-1.5 text-xs font-semibold ${filtro === f ? 'bg-[#1E5AA8] text-white' : 'bg-white text-gray-700 hover:bg-gray-100'}`}
            >
              {FILTROS[f]}
            </button>
          ))}
        </div>
      </div>

      <div className="text-gray-600">
        <b className="text-gray-900">{nReportes}</b> reportes activos ·{' '}
        <b className="text-gray-900">{nAltas}</b> colonias en alto o crítico
      </div>

      {aviso && (
        <div className={`rounded px-2 py-1 text-xs font-medium ${aviso.ok ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`} role="status">
          {aviso.texto}
        </div>
      )}

      <div className="ml-auto flex items-center gap-2">
        <button onClick={manual} className={`${btn} border border-[#1E5AA8] text-[#1E5AA8] hover:bg-blue-50`}>
          Reporte manual
        </button>
        <button
          onClick={() => void alternarSim()}
          disabled={ocupado !== null}
          className={`${btn} text-white`}
          style={{ background: NARANJA_SIM }}
        >
          {ocupado === 'sim' ? 'Procesando…' : sim ? 'Terminar simulación' : 'Simular tormenta'}
        </button>
        <div className="relative" ref={menuRef}>
          <button
            onClick={() => setMenu((m) => !m)}
            className={`${btn} border border-gray-300 text-gray-700 hover:bg-gray-100`}
            aria-label="Ajustes"
            title="Ajustes"
          >
            {ocupado === 'seed' || ocupado === 'reset' ? '…' : '⚙'}
          </button>
          {menu && (
            <div className="absolute bottom-full right-0 z-30 mb-2 w-52 rounded-md border border-gray-200 bg-white py-1 shadow-lg">
              <button onClick={seed} className="block w-full px-3 py-2 text-left hover:bg-gray-100">Cargar datos (seed)</button>
              <button onClick={reset} className="block w-full px-3 py-2 text-left text-red-700 hover:bg-red-50">Reiniciar (reset)</button>
            </div>
          )}
        </div>
      </div>
    </footer>
  )
}
