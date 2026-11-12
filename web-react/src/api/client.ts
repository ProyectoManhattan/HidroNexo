import { API_URL } from '../config'
import { getClave, setClave } from '../session'
import type {
  Alerta, AlertaActiva, Categoria, Categorias, Clima, Colonia, Dispositivo, Guia, Guias, Reporte,
  ReporteNuevo, ZonasGeoJSON,
} from '../types'

export class ApiError extends Error {
  estado: number
  constructor(estado: number, detalle: string) {
    super(detalle)
    this.estado = estado
  }
}

function detalleDe(body: unknown): string {
  const d = (body as { detail?: unknown } | null)?.detail
  if (typeof d === 'string') return d
  if (Array.isArray(d)) return d.map((e) => (e as { msg?: string }).msg ?? '').join('; ')
  return 'Error desconocido'
}

async function request<T>(method: string, path: string, opts: { body?: unknown; operador?: boolean } = {}): Promise<T> {
  const headers: Record<string, string> = {}
  if (opts.body !== undefined) headers['Content-Type'] = 'application/json'
  if (opts.operador) {
    const clave = getClave()
    if (clave) headers['X-Clave'] = clave
  }
  let res: Response
  try {
    res = await fetch(API_URL + path, {
      method,
      headers,
      body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
    })
  } catch {
    throw new ApiError(0, 'No se pudo conectar con el servidor')
  }
  let data: unknown = null
  try { data = await res.json() } catch { /* sin cuerpo */ }
  if (!res.ok) {
    if (res.status === 401 && opts.operador) setClave(null)
    throw new ApiError(res.status, detalleDe(data))
  }
  return data as T
}

const op = { operador: true }
function qs(p: Record<string, string | number | boolean | undefined>): string {
  const u = new URLSearchParams()
  for (const [k, v] of Object.entries(p)) if (v !== undefined) u.set(k, String(v))
  const s = u.toString()
  return s ? '?' + s : ''
}

// Reportes
export const getCategorias = () => request<Categorias>('GET', '/reports/categories')
export const crearReporte = (r: ReporteNuevo) => request<Reporte>('POST', '/reports', { body: r })
export const crearReporteManual = (r: ReporteNuevo) => request<Reporte>('POST', '/reports/manual', { body: r, ...op })
export const getReportes = (f: { categoria?: Categoria; colonia_id?: number; activos?: boolean; bbox?: string } = {}) =>
  request<Reporte[]>('GET', '/reports' + qs(f))
export const resolverReporte = (id: number) => request<Reporte>('POST', `/reports/${id}/resolve`, op)

// Colonias y riesgo
export const getColonias = () => request<Colonia[]>('GET', '/zones')
export const getZonasRiesgo = () => request<ZonasGeoJSON>('GET', '/zones/risk')

// Alertas. estado '' = todas
export const getAlertas = (estado: 'propuesta' | 'aprobada' | 'descartada' | '' = 'propuesta') =>
  request<Alerta[]>('GET', '/alerts' + qs({ estado }))
export const getAlertasActivas = (colonia_id?: number) => request<AlertaActiva[]>('GET', '/alerts/active' + qs({ colonia_id }))
export const editarAlerta = (id: number, texto: string) => request<Alerta>('PATCH', `/alerts/${id}`, { body: { texto }, ...op })
export const aprobarAlerta = (id: number) => request<Alerta>('POST', `/alerts/${id}/approve`, op)
export const descartarAlerta = (id: number) => request<Alerta>('POST', `/alerts/${id}/discard`, op)

// Guias
export const getGuias = () => request<Guias>('GET', '/guides')
export const getGuia = (tipo: string) => request<Guia>('GET', `/guides/${tipo}`)

// Dispositivos
export const registrarDispositivo = (d: { token: string; colonia_id: number; plataforma: 'android' | 'ios' | 'web' }) =>
  request<Dispositivo>('POST', '/devices', { body: d })

// Admin y demo
export const adminSeed = () => request<{ colonias: number; reportes: number }>('POST', '/admin/seed', op)
export const adminReset = () => request<{ ok: boolean }>('POST', '/admin/reset', op)
export const simularTormenta = (intensidad = 1.0) => request<Clima>('POST', '/admin/simulate-storm', { body: { intensidad }, ...op })
export const terminarTormenta = () => request<Clima>('DELETE', '/admin/simulate-storm', op)
export const getClima = () => request<Clima>('GET', '/admin/weather', op)
