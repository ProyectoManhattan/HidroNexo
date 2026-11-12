import { useEffect, useRef, useState, type FormEvent } from 'react'
import { ApiError, getClima } from '../api/client'
import { abrirDialogoClave, setOperadorClave, useStore } from '../store'

export default function KeyDialog() {
  const abierto = useStore((s) => s.dialogoClave)
  if (!abierto) return null
  return <Contenido />
}

function Contenido() {
  const [clave, setClave] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [cargando, setCargando] = useState(false)
  const ref = useRef<HTMLInputElement>(null)
  const cerrar = () => abrirDialogoClave(false)

  useEffect(() => {
    ref.current?.focus()
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') abrirDialogoClave(false) }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  async function enviar(e: FormEvent) {
    e.preventDefault()
    if (!clave.trim() || cargando) return
    setCargando(true)
    setError(null)
    setOperadorClave(clave.trim())
    try {
      await getClima()
      abrirDialogoClave(false)
    } catch (err) {
      setOperadorClave(null)
      setError(err instanceof ApiError && err.estado === 0 ? 'No se pudo conectar con el servidor' : 'Clave incorrecta')
      ref.current?.select()
    } finally {
      setCargando(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onMouseDown={(e) => e.target === e.currentTarget && cerrar()}>
      <form onSubmit={enviar} role="dialog" aria-modal="true" aria-label="Modo operador" className="w-full max-w-sm rounded-lg bg-white p-5 shadow-xl">
        <h2 className="text-lg font-bold text-gray-900">Modo operador</h2>
        <p className="mt-1 text-sm text-gray-600">Ingresa la clave de Protección Civil para continuar.</p>
        <input
          ref={ref}
          type="password"
          autoFocus
          value={clave}
          onChange={(e) => setClave(e.target.value)}
          placeholder="Clave"
          autoComplete="current-password"
          className="mt-4 w-full rounded-md border border-gray-300 px-3 py-2 focus:border-[#1E5AA8] focus:outline-none focus:ring-1 focus:ring-[#1E5AA8]"
        />
        {error && <p className="mt-2 text-sm font-medium text-red-700" role="alert">{error}</p>}
        <div className="mt-4 flex justify-end gap-2">
          <button type="button" onClick={cerrar} className="rounded-md px-3 py-1.5 text-sm font-semibold text-gray-700 hover:bg-gray-100">Cancelar</button>
          <button type="submit" disabled={cargando || !clave.trim()} className="rounded-md bg-[#1E5AA8] px-4 py-1.5 text-sm font-semibold text-white disabled:opacity-60">
            {cargando ? 'Verificando…' : 'Entrar'}
          </button>
        </div>
      </form>
    </div>
  )
}
