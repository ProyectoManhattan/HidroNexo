import { API_URL, CLAVE } from '../config'
import type {
  Alerta, AlertaActiva, AlertaManualNueva, AvisosOficiales, Categoria, Clima, Colonia, Reporte, ZonasGeoJSON,
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
  if (opts.operador && CLAVE) headers['X-Clave'] = CLAVE
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
export const crearAlertaManual = (b: AlertaManualNueva) => request<Alerta[]>('POST', '/alerts', { body: b, ...op })
export const getClima = () => request<Clima>('GET', '/weather')

// Alertamientos oficiales de Protección Civil para Veracruz
export const getAvisosOficiales = () => request<AvisosOficiales>('GET', '/official-alerts')
