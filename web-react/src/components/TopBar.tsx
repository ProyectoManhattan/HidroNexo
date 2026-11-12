import { NARANJA_SIM, UMBRAL_PROB_ALTA } from '../constants'
import { useStore } from '../store'

function Marca() {
  return (
    <div className="brand-mark" aria-hidden>
      <svg viewBox="0 0 48 48" className="h-9 w-9" fill="none">
        <path d="M24 5C18 14 12 20 12 29a12 12 0 0 0 24 0C36 20 30 14 24 5Z" stroke="currentColor" strokeWidth="3" />
        <path d="M17 30c3.8 3 10.2 3 14 0" stroke="currentColor" strokeWidth="3" strokeLinecap="round" />
        <path d="M19 24c2.8 2 7.2 2 10 0" stroke="currentColor" strokeWidth="2" strokeLinecap="round" opacity=".65" />
      </svg>
    </div>
  )
}

function Dato({ etiqueta, valor, ayuda }: { etiqueta: string; valor: string; ayuda?: string }) {
  return (
    <div className="header-datum" title={ayuda}>
      <span className="header-datum-label">{etiqueta}</span>
      <strong className="header-datum-value">{valor}</strong>
    </div>
  )
}

export default function TopBar() {
  const clima = useStore((s) => s.clima)
  const lluvia3h = useStore((s) => s.lluvia3h)
  const prob3h = useStore((s) => s.prob3h)
  const apiOk = useStore((s) => s.apiOk)
  const wsOk = useStore((s) => s.wsOk)
  const cargando = useStore((s) => s.cargandoInicial)
  const zonas = useStore((s) => s.zonas?.features.length ?? 0)
  const sim = clima?.simulacion ?? false
  const vivo = apiOk && wsOk
  const hora = clima?.actualizado_en
    ? new Intl.DateTimeFormat('es-MX', { hour: '2-digit', minute: '2-digit' }).format(new Date(clima.actualizado_en))
    : 'Pendiente'

  return (
    <header className="brand-header z-30 text-white">
      <div className="brand-header-inner">
        <div className="flex min-w-0 items-center gap-3.5">
          <Marca />
          <div className="min-w-0">
            <div className="mb-0.5 flex items-center gap-2 text-[12px] font-bold uppercase tracking-[.16em] text-cyan-200">
              <span>Sistema territorial</span><span className="h-1 w-1 rounded-full bg-cyan-300" /> <span>Veracruz</span>
            </div>
            <h1 className="truncate text-xl font-extrabold tracking-[-.02em] md:text-[1.45rem]">Agua y Lluvia</h1>
            <p className="truncate text-[13px] font-medium text-slate-300">Monitoreo hidrometeorológico · {zonas || '—'} zonas postales</p>
          </div>
        </div>

        <div className="header-data-strip" aria-label="Resumen meteorológico">
          <Dato etiqueta="Lluvia acumulada · 3 h" valor={lluvia3h == null ? '—' : `${lluvia3h} mm`} ayuda="Lluvia acumulada usada por el sistema" />
          <Dato etiqueta="Pronóstico de lluvia · 3 h" valor={prob3h == null ? '—' : `${Math.round(prob3h)} %`} ayuda={`Probabilidad meteorológica. ${UMBRAL_PROB_ALTA}% o más se destaca en el mapa; no es una alerta oficial.`} />
          <Dato etiqueta="Última lectura" valor={hora} ayuda="Hora de la última lectura meteorológica recibida" />
        </div>

        <div className="flex shrink-0 items-center gap-2.5">
          {sim && <span className="rounded-md px-3 py-1.5 text-xs font-extrabold tracking-wide text-white" style={{ background: NARANJA_SIM }}>Simulación</span>}
          <div className="header-status" title={`API ${apiOk ? 'conectada' : 'sin conexión'} · tiempo real ${wsOk ? 'conectado' : 'reconectando'}`}>
            <span className={`h-2.5 w-2.5 rounded-full ${vivo ? 'bg-cyan-300 shadow-[0_0_0_4px_rgb(103_232_249/.12)]' : 'bg-amber-300'}`} aria-hidden />
            <span>
              <span className="block text-[11px] font-bold uppercase tracking-wider text-slate-400">Estado del sistema</span>
              <strong className="block text-[13px] text-white">{cargando ? 'Cargando datos' : vivo ? 'Datos en vivo' : apiOk ? 'Reconectando' : 'Últimos datos'}</strong>
            </span>
          </div>
        </div>
      </div>
    </header>
  )
}
