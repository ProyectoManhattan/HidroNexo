import { useEffect, useState } from 'react'
import AlertsTray from './components/AlertsTray'
import BottomBar from './components/BottomBar'
import ColoniasRanking from './components/ColoniasRanking'
import KeyDialog from './components/KeyDialog'
import ManualReportDialog from './components/ManualReportDialog'
import MapView from './components/MapView'
import ReportsList from './components/ReportsList'
import TopBar from './components/TopBar'
import { iniciar, useStore } from './store'

const TABS = [
  { id: 'alertas', texto: 'Alertas', Vista: AlertsTray },
  { id: 'reportes', texto: 'Reportes', Vista: ReportsList },
  { id: 'colonias', texto: 'Colonias', Vista: ColoniasRanking },
] as const

export default function App() {
  const apiOk = useStore((s) => s.apiOk)
  const [tab, setTab] = useState<(typeof TABS)[number]['id']>('alertas')

  useEffect(() => iniciar(), [])

  const Activa = TABS.find((t) => t.id === tab)!.Vista

  return (
    <div className="flex h-full flex-col">
      <TopBar />
      {!apiOk && (
        <div className="bg-red-600 px-4 py-1 text-center text-sm text-white">
          Sin conexión con el servidor. Reintentando…
        </div>
      )}
      <div className="flex min-h-0 flex-1">
        <main className="relative min-w-0 flex-1">
          <MapView />
        </main>
        <aside className="flex w-96 shrink-0 flex-col border-l bg-white">
          <nav className="flex border-b">
            {TABS.map((t) => (
              <button
                key={t.id}
                onClick={() => setTab(t.id)}
                className={`flex-1 px-3 py-2 text-sm font-semibold ${
                  tab === t.id ? 'border-b-2 border-[#1E5AA8] text-[#1E5AA8]' : 'text-gray-500'
                }`}
              >
                {t.texto}
              </button>
            ))}
          </nav>
          <div className="min-h-0 flex-1 overflow-y-auto">
            <Activa />
          </div>
        </aside>
      </div>
      <BottomBar />
      <KeyDialog />
      <ManualReportDialog />
    </div>
  )
}
