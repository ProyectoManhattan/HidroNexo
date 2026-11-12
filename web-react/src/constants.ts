import type { Categoria, Nivel } from './types'

export const AZUL = '#1E5AA8'
export const NARANJA_SIM = '#F28C28'

export const NIVELES: Record<Nivel, { color: string; suave: string; texto: string }> = {
  bajo: { color: '#2E9E5B', suave: '#DFF3E7', texto: 'Bajo' },
  medio: { color: '#E0A800', suave: '#FFF5D6', texto: 'Medio' },
  alto: { color: '#F07C1E', suave: '#FFE9D6', texto: 'Alto' },
  critico: { color: '#D63B3B', suave: '#FBE1E1', texto: 'Crítico' },
}

export const CATEGORIAS: Record<Categoria, { color: string; letra: string; texto: string; grupo: 'lluvia' | 'agua' }> = {
  inundacion: { color: '#1E5AA8', letra: 'I', texto: 'Inundación', grupo: 'lluvia' },
  encharcamiento: { color: '#3A8DDE', letra: 'E', texto: 'Encharcamiento', grupo: 'lluvia' },
  alcantarilla: { color: '#6B4FA0', letra: 'A', texto: 'Alcantarilla tapada', grupo: 'lluvia' },
  fuga: { color: '#0FA3A3', letra: 'F', texto: 'Fuga de agua', grupo: 'agua' },
  sin_agua: { color: '#8A5A2B', letra: 'T', texto: 'Sin agua / tandeo', grupo: 'agua' },
}

export const MOTIVOS = { lluvia: 'lluvia', reportes: 'reportes ciudadanos', vulnerabilidad: 'vulnerabilidad' } as const
export const SEVERIDADES = { 1: 'Baja', 2: 'Media', 3: 'Alta' } as const
export const FILTROS = { todo: 'Todo', lluvia: 'Lluvia', agua: 'Agua (fugas y tandeo)' } as const

export function nivelInfo(n?: string | null) {
  return NIVELES[(n as Nivel) ?? 'bajo'] ?? NIVELES.bajo
}
export function categoriaInfo(c: string) {
  return CATEGORIAS[c as Categoria] ?? { color: '#5B6675', letra: '?', texto: c, grupo: 'lluvia' as const }
}

/** "hace 5 min" a partir de una fecha ISO. */
export function hace(iso?: string | null): string {
  if (!iso) return ''
  const s = Math.floor((Date.now() - new Date(iso).getTime()) / 1000)
  if (s < 60) return `hace ${Math.max(s, 1)} s`
  if (s < 3600) return `hace ${Math.floor(s / 60)} min`
  return `hace ${Math.floor(s / 3600)} h`
}
