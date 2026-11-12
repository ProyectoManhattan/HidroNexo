import { NARANJA_SIM } from '../constants'
import { abrirDialogoClave, setOperadorClave, useStore } from '../store'
import Chip from './bars/Chip'

export default function TopBar() {
  const lluvia3h = useStore((s) => s.lluvia3h)
  const apiOk = useStore((s) => s.apiOk)
  const wsOk = useStore((s) => s.wsOk)
  const clave = useStore((s) => s.operadorClave)
  const sim = useStore((s) => s.clima?.simulacion ?? false)
  const vivo = apiOk && wsOk

  return (
    <header className="flex flex-wrap items-center gap-x-4 gap-y-2 bg-[#1E5AA8] px-4 py-2 text-white shadow">
      <div className="mr-auto flex items-center gap-3">
        <span className="text-2xl" aria-hidden>💧</span>
        <div className="leading-tight">
          <h1 className="text-base font-bold">Agua y Lluvia · Veracruz</h1>
          <p className="text-xs text-white/80">Panel de Protección Civil</p>
        </div>
      </div>

      {sim && (
        <span
          className="rounded px-3 py-1 text-xs font-extrabold tracking-wider text-white"
          style={{ background: NARANJA_SIM }}
          title="Hay una tormenta simulada activa"
        >
          SIMULACIÓN
        </span>
      )}
      <Chip className="bg-white/15">Lluvia 3 h: {lluvia3h == null ? '—' : `${lluvia3h} mm`}</Chip>
      <Chip className={vivo ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}>
        <span className={`h-2 w-2 rounded-full ${vivo ? 'bg-green-600' : 'bg-red-600'}`} />
        {vivo ? 'En vivo' : 'Sin conexión'}
      </Chip>
      <Chip className="bg-white text-red-700">No sustituye al 911</Chip>

      {clave ? (
        <div className="flex items-center gap-2 rounded-full bg-white/15 py-1 pl-3 pr-1 text-xs font-semibold">
          <span className="h-2 w-2 rounded-full bg-green-400" />
          Operador: Protección Civil
          <button
            onClick={() => setOperadorClave(null)}
            className="rounded-full bg-white/20 px-2 py-0.5 hover:bg-white/30"
            title="Cerrar sesión de operador"
          >
            Salir
          </button>
        </div>
      ) : (
        <button
          onClick={() => abrirDialogoClave()}
          className="rounded-full bg-white px-3 py-1 text-xs font-semibold text-[#1E5AA8] hover:bg-blue-50"
        >
          Modo operador
        </button>
      )}
    </header>
  )
}
