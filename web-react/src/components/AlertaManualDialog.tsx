import { useMemo, useState, type FormEvent } from 'react'
import { ApiError, crearAlertaManual } from '../api/client'
import { CATEGORIAS } from '../constants'
import { abrirDialogoAlertaManual, comoOperador, getState, useStore } from '../store'
import type { AlertaManualNueva, Categoria } from '../types'
import { ErrorBox } from './sidebar/ui'

type NivelManual = AlertaManualNueva['nivel']
const NIVELES_MANUAL: { id: NivelManual; texto: string }[] = [
  { id: 'medio', texto: 'Medio' },
  { id: 'alto', texto: 'Alto' },
  { id: 'critico', texto: 'Crítico' },
]
const MIN = 10
const MAX = 1000

function mensajeError(e: unknown): string {
  if (e instanceof ApiError) return e.estado === 0 ? 'Sin conexión con la API' : e.message
  return e instanceof Error ? e.message : 'Error desconocido'
}

const campo = 'mt-1 w-full rounded-md border border-gray-300 px-2 py-1.5 text-sm focus:border-[#1E5AA8] focus:outline-none focus:ring-1 focus:ring-[#1E5AA8]'

export default function AlertaManualDialog() {
  const abierto = useStore((s) => s.dialogoAlertaManual)
  if (!abierto) return null
  return <Contenido />
}

function Contenido() {
  const zonas = useStore((s) => s.zonas)
  const [sel, setSel] = useState<Set<number>>(() => {
    const id = getState().coloniaSeleccionada
    return new Set(id != null ? [id] : [])
  })
  const [busqueda, setBusqueda] = useState('')
  const [tipo, setTipo] = useState<Categoria>('inundacion')
  const [nivel, setNivel] = useState<NivelManual>('alto')
  const [texto, setTexto] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [exito, setExito] = useState<string | null>(null)
  const [enviando, setEnviando] = useState(false)

  const colonias = useMemo(
    () => (zonas?.features ?? [])
      .map((f) => ({ id: f.properties.id, nombre: f.properties.nombre }))
      .sort((a, b) => a.nombre.localeCompare(b.nombre, 'es')),
    [zonas],
  )
  const filtradas = useMemo(() => {
    const q = busqueda.trim().toLowerCase()
    return q ? colonias.filter((c) => c.nombre.toLowerCase().includes(q)) : colonias
  }, [colonias, busqueda])

  const alternar = (id: number) => setSel((s) => {
    const n = new Set(s)
    if (n.has(id)) n.delete(id)
    else n.add(id)
    return n
  })
  const largo = texto.trim().length

  async function enviar(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (sel.size === 0) { setError('Selecciona al menos una colonia'); return }
    if (largo < MIN) { setError(`El mensaje debe tener al menos ${MIN} caracteres`); return }
    if (largo > MAX) { setError(`El mensaje no puede pasar de ${MAX} caracteres`); return }
    if (!window.confirm(`Se enviará a ${sel.size} colonia(s) de inmediato. Esta acción no se puede deshacer. ¿Enviar la alerta?`)) return
    setEnviando(true)
    try {
      const r = await comoOperador(() =>
        crearAlertaManual({ colonia_ids: [...sel], tipo, nivel, texto: texto.trim() }),
      )
      setExito(`Alerta enviada a ${r.length} colonia(s)`)
      setTimeout(() => abrirDialogoAlertaManual(false), 1200)
    } catch (err) {
      setError(mensajeError(err))
      setEnviando(false)
    }
  }

  return (
    <form onSubmit={enviar} role="dialog" aria-label="Enviar alerta manual" className="fixed bottom-20 right-4 z-40 w-96 max-w-[calc(100vw-2rem)] rounded-lg border border-gray-200 bg-white p-4 shadow-xl">
      <div className="flex items-center justify-between">
        <h2 className="text-base font-bold text-gray-900">Enviar alerta manual</h2>
        <button type="button" onClick={() => abrirDialogoAlertaManual(false)} className="text-gray-500 hover:text-gray-800" aria-label="Cerrar">✕</button>
      </div>

      <div className="mt-3">
        <div className="flex items-center justify-between text-sm font-semibold text-gray-700">
          <span>Colonias ({sel.size} seleccionada{sel.size === 1 ? '' : 's'})</span>
          <span className="space-x-2 font-medium text-[#1E5AA8]">
            <button type="button" onClick={() => setSel(new Set(colonias.map((c) => c.id)))} className="hover:underline">Seleccionar todas</button>
            <button type="button" onClick={() => setSel(new Set())} className="hover:underline">Limpiar</button>
          </span>
        </div>
        <input
          type="search"
          value={busqueda}
          onChange={(e) => setBusqueda(e.target.value)}
          placeholder="Buscar colonia…"
          className={campo}
        />
        <ul className="mt-1 max-h-36 overflow-y-auto rounded-md border border-gray-200">
          {filtradas.length === 0 && <li className="px-2 py-1.5 text-sm text-gray-400">Sin resultados</li>}
          {filtradas.map((c) => (
            <li key={c.id}>
              <label className="flex cursor-pointer items-center gap-2 px-2 py-1 text-sm hover:bg-gray-50">
                <input type="checkbox" checked={sel.has(c.id)} onChange={() => alternar(c.id)} />
                {c.nombre}
              </label>
            </li>
          ))}
        </ul>
      </div>

      <div className="mt-3 grid grid-cols-2 gap-3">
        <label className="block text-sm font-semibold text-gray-700">Tipo
          <select value={tipo} onChange={(e) => setTipo(e.target.value as Categoria)} className={campo}>
            {(Object.keys(CATEGORIAS) as Categoria[]).map((c) => <option key={c} value={c}>{CATEGORIAS[c].texto}</option>)}
          </select>
        </label>
        <label className="block text-sm font-semibold text-gray-700">Nivel
          <select value={nivel} onChange={(e) => setNivel(e.target.value as NivelManual)} className={campo}>
            {NIVELES_MANUAL.map((n) => <option key={n.id} value={n.id}>{n.texto}</option>)}
          </select>
        </label>
      </div>

      <label className="mt-3 block text-sm font-semibold text-gray-700">Mensaje
        <textarea
          value={texto}
          onChange={(e) => setTexto(e.target.value)}
          rows={4}
          maxLength={MAX}
          placeholder="Texto que recibirán los vecinos de las colonias seleccionadas"
          className={campo}
        />
        <span className={`block text-right text-xs font-normal ${largo < MIN ? 'text-gray-400' : 'text-gray-500'}`}>{largo}/{MAX} (mín. {MIN})</span>
      </label>

      <div className="mt-2">
        <ErrorBox texto={error} />
        {exito && <div className="mb-2 rounded border border-green-200 bg-green-50 px-2 py-1 text-sm text-green-700" role="status">{exito}</div>}
      </div>

      <div className="flex justify-end gap-2">
        <button type="button" onClick={() => abrirDialogoAlertaManual(false)} className="rounded-md px-3 py-1.5 text-sm font-semibold text-gray-700 hover:bg-gray-100">Cancelar</button>
        <button type="submit" disabled={enviando || exito !== null} className="rounded-md bg-[#1E5AA8] px-3 py-1.5 text-sm font-semibold text-white hover:bg-blue-800 disabled:opacity-60">
          {enviando ? 'Enviando…' : 'Enviar alerta'}
        </button>
      </div>
    </form>
  )
}
