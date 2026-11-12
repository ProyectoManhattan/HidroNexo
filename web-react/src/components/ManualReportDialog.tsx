import { useState, type FormEvent } from 'react'
import { crearReporteManual } from '../api/client'
import { CATEGORIAS, SEVERIDADES } from '../constants'
import { abrirDialogoManual, comoOperador, setEligiendoPunto, useStore } from '../store'
import type { Categoria, Severidad } from '../types'

export default function ManualReportDialog() {
  const abierto = useStore((s) => s.dialogoManual)
  if (!abierto) return null
  return <Contenido />
}

const campo = 'mt-1 w-full rounded-md border border-gray-300 px-2 py-1.5 text-sm focus:border-[#1E5AA8] focus:outline-none focus:ring-1 focus:ring-[#1E5AA8]'

function Contenido() {
  const eligiendo = useStore((s) => s.eligiendoPunto)
  const punto = useStore((s) => s.puntoManual)
  const [categoria, setCategoria] = useState<Categoria>('inundacion')
  const [severidad, setSeveridad] = useState<Severidad>(2)
  const [descripcion, setDescripcion] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [enviando, setEnviando] = useState(false)

  // Mientras se elige en el mapa, solo una tarjeta pequena que no tapa el mapa
  if (eligiendo) {
    return (
      <div className="fixed left-1/2 top-20 z-40 flex -translate-x-1/2 items-center gap-3 rounded-full bg-[#1E5AA8] px-4 py-2 text-sm text-white shadow-lg">
        Haz clic en el mapa para marcar la ubicación
        <button onClick={() => setEligiendoPunto(false)} className="rounded-full bg-white/20 px-2 py-0.5 text-xs font-semibold hover:bg-white/30">Cancelar</button>
      </div>
    )
  }

  async function enviar(e: FormEvent) {
    e.preventDefault()
    if (!punto) { setError('Elige la ubicación en el mapa'); return }
    setEnviando(true)
    setError(null)
    try {
      const r = await comoOperador(() =>
        crearReporteManual({ categoria, severidad, lat: punto.lat, lon: punto.lon, descripcion: descripcion.trim() || null }),
      )
      if (r !== undefined) abrirDialogoManual(false)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'No se pudo enviar el reporte')
    } finally {
      setEnviando(false)
    }
  }

  return (
    <form onSubmit={enviar} role="dialog" aria-label="Reporte manual" className="fixed bottom-20 right-4 z-40 w-80 max-w-[calc(100vw-2rem)] rounded-lg border border-gray-200 bg-white p-4 shadow-xl">
      <div className="flex items-center justify-between">
        <h2 className="text-base font-bold text-gray-900">Reporte manual</h2>
        <button type="button" onClick={() => abrirDialogoManual(false)} className="text-gray-500 hover:text-gray-800" aria-label="Cerrar">✕</button>
      </div>

      <label className="mt-3 block text-xs font-semibold text-gray-700">Categoría
        <select value={categoria} onChange={(e) => setCategoria(e.target.value as Categoria)} className={campo}>
          {(Object.keys(CATEGORIAS) as Categoria[]).map((c) => <option key={c} value={c}>{CATEGORIAS[c].texto}</option>)}
        </select>
      </label>
      <label className="mt-3 block text-xs font-semibold text-gray-700">Severidad
        <select value={severidad} onChange={(e) => setSeveridad(Number(e.target.value) as Severidad)} className={campo}>
          {([1, 2, 3] as Severidad[]).map((s) => <option key={s} value={s}>{SEVERIDADES[s]}</option>)}
        </select>
      </label>
      <label className="mt-3 block text-xs font-semibold text-gray-700">Descripción
        <textarea value={descripcion} onChange={(e) => setDescripcion(e.target.value)} rows={2} maxLength={500} className={campo} />
      </label>

      <div className="mt-3 text-xs font-semibold text-gray-700">Ubicación</div>
      <div className="mt-1 flex items-center gap-2">
        <button type="button" onClick={() => setEligiendoPunto(true)} className="rounded-md border border-[#1E5AA8] px-2 py-1 text-xs font-semibold text-[#1E5AA8] hover:bg-blue-50">
          Elegir en el mapa
        </button>
        <span className="text-xs text-gray-600">{punto ? `${punto.lat.toFixed(5)}, ${punto.lon.toFixed(5)}` : 'Sin punto elegido'}</span>
      </div>

      {error && <p className="mt-2 text-sm font-medium text-red-700" role="alert">{error}</p>}
      <div className="mt-4 flex justify-end gap-2">
        <button type="button" onClick={() => abrirDialogoManual(false)} className="rounded-md px-3 py-1.5 text-sm font-semibold text-gray-700 hover:bg-gray-100">Cancelar</button>
        <button type="submit" disabled={enviando} className="rounded-md bg-[#1E5AA8] px-4 py-1.5 text-sm font-semibold text-white disabled:opacity-60">
          {enviando ? 'Enviando…' : 'Enviar'}
        </button>
      </div>
    </form>
  )
}
