// Tipos del contrato docs/api.md
export type Categoria = 'inundacion' | 'encharcamiento' | 'alcantarilla' | 'fuga' | 'sin_agua'
export type Severidad = 1 | 2 | 3
export type Nivel = 'bajo' | 'medio' | 'alto' | 'critico'
export type Motivo = 'lluvia' | 'reportes' | 'vulnerabilidad'
export type Filtro = 'todo' | 'lluvia' | 'agua'

export interface Reporte {
  id: number
  categoria: Categoria
  severidad: Severidad
  lat: number
  lon: number
  descripcion: string | null
  foto_url: string | null
  colonia_id: number | null
  origen: 'app' | 'panel' | 'seed'
  estado: 'activo' | 'resuelto'
  creado_en: string
  expira_en: string
  /** Severidad ajustada por la lluvia local; null si el backend no la calculó (p. ej. respuesta de POST) */
  prioridad?: number | null
}

export interface ReporteNuevo {
  categoria: Categoria
  severidad: Severidad
  lat: number
  lon: number
  descripcion?: string | null
  foto_url?: string | null
  dispositivo_id?: string | null
}

export interface Categorias {
  categorias: Record<Categoria, string>
  severidades: Record<string, string>
}

export interface Colonia {
  id: number
  nombre: string
  municipio: string
  vulnerabilidad: number
  vulnerabilidad_fuente: string
}

export interface Componentes {
  lluvia: number
  reportes: number
  vulnerabilidad: number
}

export interface ZonaProps {
  id: number
  nombre: string
  municipio: string
  vulnerabilidad: number
  riesgo: number
  nivel: Nivel
  motivo: Motivo
  componentes: Componentes
  actualizado_en: string
  pronostico?: Pronostico
}

/** Pronóstico de lluvia de la zona (Open-Meteo). prob_* en %, null si no hay dato. */
export interface Pronostico {
  mm_3h: number
  prob_3h: number | null
  prob_6h: number | null
  mm_3h_efectivos: number
}

export interface ZonaFeature {
  type: 'Feature'
  id: number
  geometry: { type: 'Polygon' | 'MultiPolygon'; coordinates: number[][][] | number[][][][] }
  properties: ZonaProps
}

export interface ZonasGeoJSON {
  type: 'FeatureCollection'
  features: ZonaFeature[]
}

export interface Alerta {
  id: number
  colonia_id: number
  tipo: string
  nivel: Nivel
  motivo: Motivo
  texto: string
  estado: 'propuesta' | 'aprobada' | 'descartada'
  redactada_por: 'plantilla' | 'llm' | 'manual'
  simulada: boolean
  creada_en: string
  aprobada_en: string | null
}

export interface AlertaManualNueva {
  colonia_ids: number[]
  tipo: string
  nivel: 'medio' | 'alto' | 'critico'
  texto: string
}

export interface Guia {
  titulo: string
  pasos: string[]
  [extra: string]: unknown
}

export interface AlertaActiva extends Alerta {
  guia: Guia | null
}

export type Guias = Record<string, Guia>

export interface Clima {
  lluvia: { mm_1h: number; mm_3h: number; mm_24h: number; pronostico_3h: number; prob_3h?: number; prob_6h?: number }
  simulacion: boolean
  actualizado_en: string
}

export interface Dispositivo {
  id: number
  colonia_id: number
  plataforma: 'android' | 'ios' | 'web'
}

// WebSocket
export interface ZonaRiesgoWS {
  colonia_id: number
  nombre: string
  valor: number
  nivel: Nivel
  motivo: Motivo
  componentes: Componentes
}

export type MensajeWS =
  | { tipo: 'report.created'; datos: Reporte }
  | { tipo: 'report.updated'; datos: Reporte }
  | { tipo: 'zone.risk_updated'; datos: ZonaRiesgoWS }
  | { tipo: 'alert.drafted'; datos: Alerta }
  | { tipo: 'alert.approved'; datos: Alerta & { dispositivos_notificados: number } }
  | { tipo: 'weather.updated'; datos: Clima }

export type TipoWS = MensajeWS['tipo']
