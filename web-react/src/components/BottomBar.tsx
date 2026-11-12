import { useEffect, useMemo, useRef, useState } from 'react'
import { adminReset, adminSeed, simularTormenta, terminarTormenta } from '../api/client'
import { FILTROS, NARANJA_SIM } from '../constants'
import {
  abrirDialogoAlertaManual, comoOperador, getState, reportesVisibles, setFiltro, useStore,
} from '../store'
import type { Filtro } from '../types'

const msgError = (e: unknown) => (e instanceof Error ? e.message : 'Error desconocido')

export default function BottomBar() {
  const filtro = useStore((s) => s.filtro)
  const reportes = useStore((s) => s.reportes)
  const zonas = useStore((s) => s.zonas)
  const sim = useStore((s) => s.clima?.simulacion ?? false)
  const [ocupado, setOcupado] = useState<string | null>(null)
  const [aviso, setAviso] = useState<{ ok: boolean; texto: string } | null>(null)
  const [menu, setMenu] = useState(false)
  const [panelSim, setPanelSim] = useState(false)
  const [modoSim, setModoSim] = useState<'ahora' | 'viene'>('ahora')
  const [intensidad, setIntensidad] = useState(1)
  const [probabilidad, setProbabilidad] = useState(90)
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
      setAviso({ ok: true, texto: ok(r) })
    } catch (e) {
      setAviso({ ok: false, texto: msgError(e) })
    } finally {
      setOcupado(null)
    }
  }

  const alternarSim = () => {
    if (sim) return ejecutar('sim', () => terminarTormenta(), () => 'Simulación terminada')
    setPanelSim((v) => !v)
  }

  const iniciarSim = () => {
    setPanelSim(false)
    const viene = modoSim === 'viene'
    void ejecutar(
      'sim',
      () => simularTormenta({ intensidad, probabilidad, solo_pronostico: viene }),
      () => (viene ? `Tormenta que viene simulada (${probabilidad} % de probabilidad)` : 'Tormenta simulada activa'),
    )
  }

  const seed = () => {
    setMenu(false)
    void ejecutar('seed', () => adminSeed(), (r) => `${r.colonias} colonias, ${r.reportes} reportes cargados`)
  }
  const reset = () => {
    setMenu(false)
    if (!window.confirm('¿Reiniciar todos los datos? Se borrarán reportes y alertas.')) return
    void ejecutar('reset', () => adminReset(), () => 'Datos reiniciados')
  }

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
        <button onClick={() => abrirDialogoAlertaManual()} className={`${btn} border border-[#1E5AA8] text-[#1E5AA8] hover:bg-blue-50`}>
          Enviar alerta manual
        </button>
        <div className="relative">
        {panelSim && !sim && (
          <div className="absolute bottom-full right-0 z-30 mb-2 w-72 rounded-md border border-gray-200 bg-white p-3 text-xs shadow-lg">
            <div className="mb-2 font-bold text-gray-900">Simular tormenta</div>
            <div className="mb-3 inline-flex overflow-hidden rounded-md border border-gray-300" role="group">
              {([['ahora', 'Lluvia ahora'], ['viene', 'Tormenta que viene']] as const).map(([m, texto]) => (
                <button
                  key={m}
                  onClick={() => setModoSim(m)}
                  aria-pressed={modoSim === m}
                  className={`px-2.5 py-1 font-semibold ${modoSim === m ? 'bg-[#1E5AA8] text-white' : 'bg-white text-gray-700 hover:bg-gray-100'}`}
                >
                  {texto}
                </button>
              ))}
            </div>
            <p className="mb-2 text-gray-500">
              {modoSim === 'viene'
                ? 'Todavía no llueve: el riesgo sale del pronóstico ponderado por su probabilidad.'
                : 'Lluvia que ya está cayendo, más el pronóstico de las próximas horas.'}
            </p>
            <label className="mb-2 block">
              <span className="flex justify-between text-gray-700"><span>Intensidad</span><b>{intensidad.toFixed(1)}</b></span>
              <input type="range" min={0.2} max={2} step={0.1} value={intensidad}
                onChange={(e) => setIntensidad(Number(e.target.value))} className="w-full" />
            </label>
            <label className="mb-3 block">
              <span className="flex justify-between text-gray-700"><span>Probabilidad del pronóstico</span><b>{probabilidad} %</b></span>
              <input type="range" min={0} max={100} step={5} value={probabilidad}
                onChange={(e) => setProbabilidad(Number(e.target.value))} className="w-full" />
            </label>
            <div className="flex justify-end gap-2">
              <button onClick={() => setPanelSim(false)} className="rounded-md px-3 py-1.5 font-semibold text-gray-600 hover:bg-gray-100">
                Cancelar
              </button>
              <button onClick={iniciarSim} className="rounded-md px-3 py-1.5 font-semibold text-white" style={{ background: NARANJA_SIM }}>
                Iniciar simulación
              </button>
            </div>
          </div>
        )}
        <button
          onClick={() => void alternarSim()}
          disabled={ocupado !== null}
          className={`${btn} text-white`}
          style={{ background: NARANJA_SIM }}
        >
          {ocupado === 'sim' ? 'Procesando…' : sim ? 'Terminar simulación' : 'Simular tormenta'}
        </button>
        </div>
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
