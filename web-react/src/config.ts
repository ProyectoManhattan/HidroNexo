export const API_URL: string = (import.meta.env.VITE_API_URL as string | undefined) || 'http://localhost:8000'
export const WS_URL: string = API_URL.replace(/^http/, 'ws') + '/ws'
export const MAPTILER_KEY: string = (import.meta.env.VITE_MAPTILER_KEY as string | undefined) || ''
// OJO: toda variable VITE_* queda incrustada en el JavaScript público. Quien abra el
// panel puede leer esta clave y usarla contra la API. Es una barrera ligera, no
// seguridad real (ver README). Vacía = el panel solo puede leer.
export const CLAVE: string = (import.meta.env.VITE_CLAVE as string | undefined) || ''
export const POLL_MS = 15000
