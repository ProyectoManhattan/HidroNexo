import { NARANJA_SIM, UMBRAL_PROB_ALTA } from '../constants'
import { useStore } from '../store'

type Icono = 'agua' | 'lluvia' | 'pronostico' | 'reloj'

function Icon({ tipo, className = 'h-8 w-8' }: { tipo: Icono; className?: string }) {
  if (tipo === 'agua') return (
    <svg viewBox="0 0 48 48" className={className} fill="none" aria-hidden>
      <path d="M24 5C18 14 12 20 12 29a12 12 0 0 0 24 0C36 20 30 14 24 5Z" stroke="currentColor" strokeWidth="2.8" />
      <path d="M17.5 29.5c4 3.2 9 3.2 13 0M19.5 24.5c2.8 2 6.2 2 9 0" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
    </svg>
  )
  if (tipo === 'lluvia') return (
    <svg viewBox="0 0 48 48" className={className} fill="none" stroke="currentColor" strokeWidth="2.8" strokeLinecap="round" aria-hidden>
      <path d="M13 30h23a8 8 0 0 0 0-16 12 12 0 0 0-23-2A9 9 0 0 0 13 30Z" />
      <path d="m15 37-2 3m11-3-2 3m11-3-2 3" />
    </svg>
  )
  if (tipo === 'pronostico') return (
    <svg viewBox="0 0 48 48" className={className} fill="none" stroke="currentColor" strokeWidth="2.8" strokeLinecap="round" aria-hidden>
      <path d="M24 5C18 14 12 20 12 29a12 12 0 0 0 24 0C36 20 30 14 24 5Z" />
      <path d="M18 29c3.5 2.5 8.5 2.5 12 0" />
    </svg>
  )
  return (
    <svg viewBox="0 0 48 48" className={className} fill="none" stroke="currentColor" strokeWidth="2.8" strokeLinecap="round" aria-hidden>
      <circle cx="24" cy="24" r="17" /><path d="M24 13v12l8 5" />
    </svg>
  )
}

function Dato({ icono, etiqueta, detalle, valor, ayuda }: { icono: Icono; etiqueta: string; detalle?: string; valor: string; ayuda?: string }) {
  return (
    <div className="weather-card" title={ayuda}>
      <Icon tipo={icono} className="h-10 w-10 shrink-0 text-[#0d5ac7]" />
      <span className="min-w-0">
        <span className="block text-sm leading-tight font-semibold text-[#17326b]">
          <span className="block">{etiqueta}</span>
          {detalle && <span className="block font-medium text-[#3b5486]">{detalle}</span>}
        </span>
        <strong className="block text-[1.55rem] leading-tight font-extrabold tracking-tight text-[#0b2b70]">{valor}</strong>
      </span>
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
  const sim = clima?.simulacion ?? false
  const vivo = apiOk && wsOk
  const hora = clima?.actualizado_en
    ? new Intl.DateTimeFormat('es-MX', { hour: '2-digit', minute: '2-digit', hour12: true }).format(new Date(clima.actualizado_en))
    : 'Pendiente'

  return (
    <header className="app-header z-30">
      <div className="flex min-w-[22rem] items-center gap-4">
        <div className="brand-tile">
          <img src="/hidronexo-logo.png" alt="Logo de HidroNexo" className="h-[6rem] w-[6rem] object-contain" />
        </div>
        <div className="min-w-0 text-[#0b2b70]">
          <h1 className="truncate text-[2.75rem] leading-none font-black tracking-tight">HidroNexo</h1>
        </div>
      </div>

      <div className="weather-strip" aria-label="Resumen meteorológico">
        <Dato icono="lluvia" etiqueta="Lluvia acumulada" detalle="últimas 3 h" valor={lluvia3h == null ? '—' : `${lluvia3h} mm`} ayuda="Lluvia acumulada usada por el sistema" />
        <Dato icono="pronostico" etiqueta="Pronóstico de lluvia" detalle="próximas 3 h" valor={prob3h == null ? '—' : `${Math.round(prob3h)} %`} ayuda={`Probabilidad meteorológica. ${UMBRAL_PROB_ALTA}% o más se destaca en el mapa; no es una alerta oficial.`} />
        <Dato icono="reloj" etiqueta="Última lectura" valor={hora} ayuda="Hora de la última lectura meteorológica recibida" />
      </div>

      <div className="system-card">
        <span className={`h-3 w-3 rounded-full ${vivo ? 'bg-emerald-500 shadow-[0_0_0_6px_rgb(34_197_94/.12)]' : 'bg-amber-500'}`} aria-hidden />
        <span>
          <span className="block text-sm font-medium text-[#17326b]">Estado del sistema</span>
          <strong className={`block text-base ${vivo ? 'text-emerald-700' : 'text-amber-700'}`}>{cargando ? 'Cargando datos' : vivo ? 'Datos en vivo' : apiOk ? 'Reconectando' : 'Últimos datos'}</strong>
        </span>
        {sim && <span className="ml-2 rounded-md px-2 py-1 text-xs font-extrabold text-white" style={{ background: NARANJA_SIM }}>Simulación</span>}
      </div>
    </header>
  )
}
