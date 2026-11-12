import { useSyncExternalStore } from 'react'
import * as api from './api/client'
import { alCambiarConexion, conectar, desconectar, suscribir } from './api/realtime'
import { POLL_MS } from './config'
import { getClave, onClaveChange, setClave } from './session'
import type { Alerta, AlertaActiva, Clima, Filtro, Reporte, ZonasGeoJSON } from './types'

export interface State {
  reportes: Reporte[]
  zonas: ZonasGeoJSON | null
  alertasPropuestas: Alerta[]
  alertasActivas: AlertaActiva[]
  clima: Clima | null
  lluvia3h: number | null
  apiOk: boolean
  wsOk: boolean
  operadorClave: string | null
  filtro: Filtro
  coloniaSeleccionada: number | null
  /** true mientras se espera un clic en el mapa para un reporte manual */
  eligiendoPunto: boolean
  /** Punto elegido para el reporte manual (lo fija el mapa, lo lee ManualReportDialog) */
  puntoManual: { lat: number; lon: number } | null
  /** Dialogos abiertos */
  dialogoClave: boolean
  dialogoManual: boolean
}

let state: State = {
  reportes: [], zonas: null, alertasPropuestas: [], alertasActivas: [], clima: null, lluvia3h: null,
  apiOk: false, wsOk: false, operadorClave: getClave(), filtro: 'todo', coloniaSeleccionada: null,
  eligiendoPunto: false, puntoManual: null, dialogoClave: false, dialogoManual: false,
}
const subs = new Set<() => void>()

function set(parcial: Partial<State>) {
  state = { ...state, ...parcial }
  subs.forEach((f) => f())
}
const subscribe = (f: () => void) => { subs.add(f); return () => { subs.delete(f) } }

export const getState = () => state
/** Hook: `const reportes = useStore(s => s.reportes)` */
export function useStore<T>(selector: (s: State) => T): T {
  return useSyncExternalStore(subscribe, () => selector(state))
}

// ---------------------------------------------------------------- refrescos
async function intentar<T>(p: Promise<T>): Promise<T | undefined> {
  try {
    const v = await p
    if (!state.apiOk) set({ apiOk: true })
    return v
  } catch (e) {
    if (e instanceof api.ApiError && e.estado === 0) set({ apiOk: false })
    return undefined
  }
}

export async function refrescarReportes() {
  const r = await intentar(api.getReportes())
  if (r) set({ reportes: r })
}
export async function refrescarZonas() {
  const z = await intentar(api.getZonasRiesgo())
  if (z) set({ zonas: z })
}
export async function refrescarAlertas() {
  const [p, a] = await Promise.all([intentar(api.getAlertas('propuesta')), intentar(api.getAlertasActivas())])
  if (p) set({ alertasPropuestas: p })
  if (a) set({ alertasActivas: a })
}
export async function refrescarClima() {
  // /admin/weather requiere clave; sin ella se espera el evento WS weather.updated
  if (!getClave()) return
  const c = await intentar(api.getClima())
  if (c) aplicarClima(c)
}
function aplicarClima(c: Clima) { set({ clima: c, lluvia3h: c.lluvia.mm_3h }) }

export async function refrescarTodo() {
  await Promise.all([refrescarReportes(), refrescarZonas(), refrescarAlertas(), refrescarClima()])
}

// ---------------------------------------------------------------- acciones de UI
export function setOperadorClave(c: string | null) { setClave(c) }
export const setFiltro = (filtro: Filtro) => set({ filtro })
export const seleccionarColonia = (id: number | null) => set({ coloniaSeleccionada: id })
export const abrirDialogoClave = (v = true) => set({ dialogoClave: v })
export const abrirDialogoManual = (v = true) => set({ dialogoManual: v, ...(v ? {} : { eligiendoPunto: false, puntoManual: null }) })
export const setEligiendoPunto = (v: boolean) => set({ eligiendoPunto: v })
export const setPuntoManual = (p: { lat: number; lon: number } | null) => set({ puntoManual: p, eligiendoPunto: false })

/** Ejecuta una accion de operador: pide clave si falta, refresca despues. Devuelve true si salio bien; lanza ApiError si la API falla. */
export async function comoOperador<T>(accion: () => Promise<T>): Promise<T | undefined> {
  if (!getClave()) { set({ dialogoClave: true }); return undefined }
  const r = await accion()
  await refrescarTodo()
  return r
}

// ---------------------------------------------------------------- tiempo real
function upsertReporte(r: Reporte) {
  const resto = state.reportes.filter((x) => x.id !== r.id)
  set({ reportes: r.estado === 'activo' ? [r, ...resto] : resto })
}

let iniciado = false
let poll: ReturnType<typeof setInterval> | undefined

/** Llamar una vez (App lo hace). Devuelve funcion para detener. */
export function iniciar(): () => void {
  if (iniciado) return () => {}
  iniciado = true
  const quitar = [
    onClaveChange(() => { set({ operadorClave: getClave() }); void refrescarClima() }),
    alCambiarConexion((wsOk) => { set({ wsOk }); if (wsOk) void refrescarTodo() }),
    suscribir('report.created', (m) => m.tipo === 'report.created' && upsertReporte(m.datos)),
    suscribir('report.updated', (m) => m.tipo === 'report.updated' && upsertReporte(m.datos)),
    suscribir('zone.risk_updated', () => void refrescarZonas()),
    suscribir('alert.drafted', () => void refrescarAlertas()),
    suscribir('alert.approved', () => void refrescarAlertas()),
    suscribir('weather.updated', (m) => m.tipo === 'weather.updated' && aplicarClima(m.datos)),
  ]
  conectar()
  void refrescarTodo()
  poll = setInterval(() => void refrescarTodo(), POLL_MS)
  return () => {
    quitar.forEach((q) => q())
    clearInterval(poll)
    desconectar()
    iniciado = false
  }
}

// ---------------------------------------------------------------- derivados
export function reportesVisibles(s: State = state): Reporte[] {
  if (s.filtro === 'todo') return s.reportes
  const lluvia = ['inundacion', 'encharcamiento', 'alcantarilla']
  return s.reportes.filter((r) => (s.filtro === 'lluvia') === lluvia.includes(r.categoria))
}
