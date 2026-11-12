import { CATEGORIAS, NIVELES, UMBRAL_PROB_ALTA } from '../../constants'

export default function Legend() {
  return (
    <div className="absolute bottom-6 left-3 z-10 rounded-xl bg-white/95 p-3 text-xs shadow-md ring-1 ring-black/5 backdrop-blur">
      <div className="mb-1.5 font-bold text-slate-800">Riesgo por colonia</div>
      <div className="flex flex-wrap gap-x-3 gap-y-1">
        {Object.values(NIVELES).map((n) => (
          <span key={n.texto} className="flex items-center gap-1 text-slate-600">
            <span className="h-3 w-3 rounded-sm opacity-80" style={{ background: n.color }} />
            {n.texto}
          </span>
        ))}
      </div>
      <div className="mt-2 flex items-center gap-1.5 text-slate-600">
        <span className="h-3 w-5 rounded-sm border-2 border-dashed border-[#1E5AA8]" />
        Lluvia probable (≥{UMBRAL_PROB_ALTA} % en 3 h)
      </div>
      <div className="mb-1.5 mt-3 font-bold text-slate-800">Reportes</div>
      <div className="grid grid-cols-1 gap-y-1">
        {Object.values(CATEGORIAS).map((c) => (
          <span key={c.texto} className="flex items-center gap-1.5 text-slate-600">
            <span className="h-3 w-3 rounded-full border border-white shadow" style={{ background: c.color }} />
            {c.texto}
          </span>
        ))}
      </div>
      <div className="mt-2 text-[11px] text-slate-500">Tamaño = severidad</div>
    </div>
  )
}
