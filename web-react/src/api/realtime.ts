import { WS_URL } from '../config'
import type { MensajeWS, TipoWS } from '../types'

type Oyente = (m: MensajeWS) => void
type Estado = (conectado: boolean) => void

const oyentes = new Map<TipoWS | '*', Set<Oyente>>()
const estados = new Set<Estado>()
let ws: WebSocket | null = null
let intentos = 0
let timer: ReturnType<typeof setTimeout> | undefined
let activo = false

function emitirEstado(v: boolean) { estados.forEach((f) => f(v)) }

function abrir() {
  if (!activo) return
  ws = new WebSocket(WS_URL)
  ws.onopen = () => { intentos = 0; emitirEstado(true) }
  ws.onmessage = (e) => {
    let m: MensajeWS
    try { m = JSON.parse(e.data) } catch { return }
    oyentes.get(m.tipo)?.forEach((f) => f(m))
    oyentes.get('*')?.forEach((f) => f(m))
  }
  ws.onclose = () => {
    emitirEstado(false)
    ws = null
    if (!activo) return
    const espera = Math.min(30000, 1000 * 2 ** intentos++)
    timer = setTimeout(abrir, espera)
  }
  ws.onerror = () => ws?.close()
}

export function conectar() {
  if (activo) return
  activo = true
  abrir()
}

export function desconectar() {
  activo = false
  clearTimeout(timer)
  ws?.close()
}

/** Suscribe a un tipo de evento (o '*' para todos). Devuelve la funcion para cancelar. */
export function suscribir(tipo: TipoWS | '*', f: Oyente): () => void {
  if (!oyentes.has(tipo)) oyentes.set(tipo, new Set())
  oyentes.get(tipo)!.add(f)
  return () => { oyentes.get(tipo)?.delete(f) }
}

export function alCambiarConexion(f: Estado): () => void {
  estados.add(f)
  return () => { estados.delete(f) }
}
