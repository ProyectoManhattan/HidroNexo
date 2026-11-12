export const API_URL: string = (import.meta.env.VITE_API_URL as string | undefined) || 'http://localhost:8000'
export const WS_URL: string = API_URL.replace(/^http/, 'ws') + '/ws'
export const CLAVE: string = (import.meta.env.VITE_CLAVE as string | undefined) || 'cambiar-esta-clave'
export const MAPTILER_KEY: string = (import.meta.env.VITE_MAPTILER_KEY as string | undefined) || ''
export const POLL_MS = 15000
