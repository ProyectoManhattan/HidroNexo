import { useCallback, useState } from 'react'
import { ApiError } from '../../api/client'
import { nivelInfo } from '../../constants'

export function NivelPill({ nivel }: { nivel?: string | null }) {
  const n = nivelInfo(nivel)
  return (
    <span className="inline-block rounded-full px-2 py-0.5 text-xs font-semibold" style={{ background: n.suave, color: n.color }}>
      {n.texto}
    </span>
  )
}

export function Badge({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return <span className={`inline-block rounded px-1.5 py-0.5 text-[11px] font-medium ${className}`}>{children}</span>
}

export function mensajeError(e: unknown): string {
  if (e instanceof ApiError) return e.estado === 0 ? 'Sin conexión con la API' : e.message
  return e instanceof Error ? e.message : 'Error desconocido'
}

/** Ejecuta acciones asincronas con estado de carga y error por clave. */
export function useAccion() {
  const [cargando, setCargando] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const ejecutar = useCallback(async (clave: string, fn: () => Promise<unknown>) => {
    setCargando(clave)
    setError(null)
    try {
      await fn()
    } catch (e) {
      setError(mensajeError(e))
    } finally {
      setCargando(null)
    }
  }, [])
  return { cargando, error, ejecutar, limpiar: () => setError(null) }
}

export function ErrorBox({ texto }: { texto: string | null }) {
  if (!texto) return null
  return <div className="mb-2 rounded border border-red-200 bg-red-50 px-2 py-1 text-xs text-red-700">{texto}</div>
}

export function Vacio({ icono, texto }: { icono: string; texto: string }) {
  return (
    <div className="flex flex-col items-center gap-1 py-10 text-gray-500">
      <span className="text-3xl">{icono}</span>
      <span className="text-sm">{texto}</span>
    </div>
  )
}
