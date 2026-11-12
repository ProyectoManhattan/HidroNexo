import { useSyncExternalStore } from 'react'
import * as api from './api/client'
import { alCambiarConexion, conectar, desconectar, suscribir } from './api/realtime'
import { POLL_MS } from './config'
import type { Alerta, AlertaActiva, AvisosOficiales, Clima, Filtro, Reporte, ZonasGeoJSON } from './types'

export interface State {
  reportes: Reporte[]
  zonas: ZonasGeoJSON | null
  alertasPropuestas: Alerta[]
  alertasActivas: AlertaActiva[]
  clima: Clima | null
  avisosOficiales: AvisosOficiales | null
  lluvia3h: number | null
  prob3h: number | null
  apiOk: boolean
  wsOk: boolean
  filtro: Filtro
  coloniaSeleccionada: number | null
  /** Dialogo de alerta manual abierto */
  dialogoAlertaManual: boolean
}

let state: State = {
  reportes: [], zonas: null, alertasPropuestas: [], alertasActivas: [], clima: null, avisosOficiales: null, lluvia3h: null, prob3h: null,
  apiOk: false, wsOk: false, filtro: 'todo', coloniaSeleccionada: null,
  dialogoAlertaManual: false,
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
  const c = await intentar(api.getClima())
  if (c) aplicarClima(c)
}
export async function refrescarAvisosOficiales() {
  const avisos = await intentar(api.getAvisosOficiales())
  if (avisos) set({ avisosOficiales: avisos })
}
function aplicarClima(c: Clima) { set({ clima: c, lluvia3h: c.lluvia.mm_3h, prob3h: c.lluvia.prob_3h ?? null }) }

export async function refrescarTodo() {
  await Promise.all([refrescarReportes(), refrescarZonas(), refrescarAlertas(), refrescarClima(), refrescarAvisosOficiales()])
}

// ---------------------------------------------------------------- acciones de UI
export const setFiltro = (filtro: Filtro) => set({ filtro })
export const seleccionarColonia = (id: number | null) => set({ coloniaSeleccionada: id })
export const abrirDialogoAlertaManual = (v = true) => set({ dialogoAlertaManual: v })

/** Ejecuta una accion de operador y refresca todo despues. Lanza ApiError si la API falla. */
export async function comoOperador<T>(accion: () => Promise<T>): Promise<T> {
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
    alCambiarConexion((wsOk) => { set({ wsOk }); if (wsOk) void refrescarTodo() }),
    suscribir('report.created', (m) => m.tipo === 'report.created' && upsertReporte(m.datos)),
    suscribir('report.updated', (m) => m.tipo === 'report.updated' && upsertReporte(m.datos)),
    suscribir('zone.risk_updated', () => void refrescarZonas()),
    suscribir('alert.drafted', () => void refrescarAlertas()),
    suscribir('alert.approved', () => void refrescarAlertas()),
    suscribir('weather.updated', (m) => m.tipo === 'weather.updated' && aplicarClima(m.datos)),
    suscribir('official_alerts.updated', (m) => m.tipo === 'official_alerts.updated' && set({ avisosOficiales: m.datos })),
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
