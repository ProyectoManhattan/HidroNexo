import { useEffect, useState } from 'react'
import AlertsTray from './components/AlertsTray'
import BottomBar from './components/BottomBar'
import ColoniasRanking from './components/ColoniasRanking'
import MapView from './components/MapView'
import OfficialAlertsBanner from './components/OfficialAlertsBanner'
import ReportsList from './components/ReportsList'
import TopBar from './components/TopBar'
import { iniciar, useStore } from './store'

const TABS = [
  { id: 'alertas', texto: 'Alertas', Vista: AlertsTray },
  { id: 'reportes', texto: 'Reportes', Vista: ReportsList },
  { id: 'colonias', texto: 'Zonas postales', Vista: ColoniasRanking },
] as const

export default function App() {
  const apiOk = useStore((s) => s.apiOk)
  const cargandoInicial = useStore((s) => s.cargandoInicial)
  const reportes = useStore((s) => s.reportes.length)
  const alertas = useStore((s) => s.alertasActivas.length)
  const colonias = useStore((s) => s.zonas?.features.length ?? 0)
  const [tab, setTab] = useState<(typeof TABS)[number]['id']>('alertas')
  const [panelMovil, setPanelMovil] = useState(false)

  useEffect(() => iniciar(), [])
  const Activa = TABS.find((t) => t.id === tab)!.Vista
  const cantidades = { alertas, reportes, colonias }

  const tabs = (
    <nav className="grid grid-cols-3 border-b border-[var(--color-border)]" aria-label="Información del territorio">
      {TABS.map((t) => (
        <button
          key={t.id}
          type="button"
          onClick={() => setTab(t.id)}
          aria-selected={tab === t.id}
          role="tab"
          className={`min-h-14 border-b-2 px-2 text-[15px] font-bold transition-colors ${
            tab === t.id
              ? 'border-[var(--color-action-primary)] text-[var(--color-action-primary)]'
              : 'border-transparent text-[var(--color-text-secondary)] hover:bg-slate-50 hover:text-slate-900'
          }`}
        >
          {t.texto} <span className="ml-1 text-sm font-medium text-slate-400">{cantidades[t.id]}</span>
        </button>
      ))}
    </nav>
  )

  return (
    <div className="flex h-full min-h-0 flex-col overflow-hidden bg-[var(--color-background)]">
      <a href="#mapa-principal" className="sr-only-focusable z-50 rounded bg-white px-4 py-2 text-blue-800">Saltar al mapa</a>
      <TopBar />
      {!apiOk && !cargandoInicial && (
        <div className="flex items-center justify-center gap-2 border-b border-amber-300 bg-amber-50 px-4 py-2 text-center text-xs font-medium text-amber-950" role="status">
          <span aria-hidden>◷</span>
          Sin conexión con el servidor. Se conserva la última información recibida mientras reintentamos.
        </div>
      )}
      <OfficialAlertsBanner />
      <div className="relative flex min-h-0 flex-1 gap-4 p-4 max-md:p-0 max-md:pt-3">
        <main id="mapa-principal" className="relative min-w-0 flex-1 overflow-hidden rounded-2xl border border-[#d5e1f4] bg-white shadow-[0_8px_28px_rgb(30_64_175/.09)] max-md:rounded-none max-md:border-x-0">
          <MapView />
          {cargandoInicial && (
            <div className="absolute inset-0 z-30 grid place-items-center bg-slate-100/75 backdrop-blur-[2px]" role="status" aria-live="polite">
              <div className="surface flex items-center gap-3 px-4 py-3 text-sm font-semibold text-slate-700">
                <span className="h-4 w-4 animate-spin rounded-full border-2 border-slate-300 border-t-blue-700 motion-reduce:animate-none" aria-hidden />
                Cargando información territorial…
              </div>
            </div>
          )}
          <button
            type="button"
            onClick={() => setPanelMovil(true)}
            className="absolute bottom-4 left-1/2 z-20 min-h-11 -translate-x-1/2 rounded-full bg-[var(--color-action-primary)] px-5 text-sm font-bold text-white shadow-lg md:hidden"
            aria-expanded={panelMovil}
          >
            Ver información · {cantidades[tab]}
          </button>
        </main>

        <aside className="hidden w-[29%] min-w-[24rem] max-w-[31rem] shrink-0 flex-col overflow-hidden rounded-2xl border border-[#d5e1f4] bg-white shadow-[0_8px_28px_rgb(30_64_175/.09)] md:flex" aria-label="Panel de información">
          <div className="flex min-h-14 items-center gap-3 border-b border-[#e0e8f5] px-4 text-[#0b2b70]">
            <span className="grid h-9 w-9 place-items-center rounded-full bg-[#eef3ff] text-[#0d5ac7]" aria-hidden>
              <svg viewBox="0 0 24 24" className="h-6 w-6" fill="none" stroke="currentColor" strokeWidth="2"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9Z"/><path d="M10 21h4"/></svg>
            </span>
            <h2 className="text-lg font-black">Alertas</h2>
            <span className="ml-auto text-sm font-bold text-[#0d5ac7]">Información vigente</span>
          </div>
          {tabs}
          <div className="min-h-0 flex-1 overflow-y-auto" role="tabpanel"><Activa /></div>
        </aside>

        {panelMovil && (
          <div className="fixed inset-0 z-40 bg-slate-950/35 md:hidden" onClick={() => setPanelMovil(false)}>
            <aside
              className="absolute inset-x-0 bottom-0 flex max-h-[78dvh] flex-col overflow-hidden rounded-t-2xl bg-white shadow-2xl"
              aria-label="Panel de información"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex min-h-11 items-center justify-center border-b border-slate-200">
                <span className="h-1 w-10 rounded-full bg-slate-300" aria-hidden />
                <button type="button" onClick={() => setPanelMovil(false)} className="absolute right-3 min-h-11 px-3 text-sm font-semibold text-slate-600" aria-label="Cerrar panel">Cerrar</button>
              </div>
              {tabs}
              <div className="min-h-0 flex-1 overflow-y-auto" role="tabpanel"><Activa /></div>
            </aside>
          </div>
        )}
      </div>
      <BottomBar />
    </div>
  )
}
