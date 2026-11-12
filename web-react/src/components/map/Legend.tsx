import { CATEGORIAS, NIVELES, UMBRAL_PROB_ALTA } from '../../constants'

export default function Legend() {
  return (
    <div className="control-group absolute bottom-3 left-3 z-10 p-3.5 text-sm max-sm:bottom-20 max-sm:left-2 max-sm:right-2">
      <div className="mb-2 font-extrabold text-slate-800">Riesgo por zona postal</div>
      <div className="flex flex-wrap gap-x-3 gap-y-1">
        {Object.values(NIVELES).map((n) => (
          <span key={n.texto} className="flex items-center gap-1 text-slate-600">
            <span className="h-3 w-3 rounded-sm opacity-80" style={{ background: n.color }} />
            {n.texto}
          </span>
        ))}
      </div>
      <div className="mt-2 flex items-center gap-1.5 text-slate-600">
        <span className="h-3 w-5 rounded-sm border-2 border-dashed border-[#126783]" />
        Lluvia probable (≥{UMBRAL_PROB_ALTA} % en 3 h)
      </div>
      <div className="mb-1.5 mt-3 font-bold text-slate-800 max-sm:hidden">Reportes ciudadanos</div>
      <div className="grid grid-cols-1 gap-y-1 max-sm:hidden">
        {Object.values(CATEGORIAS).map((c) => (
          <span key={c.texto} className="flex items-center gap-1.5 text-slate-600">
            <span className="h-3 w-3 rounded-full border border-white shadow" style={{ background: c.color }} />
            {c.texto}
          </span>
        ))}
      </div>
      <div className="mt-2 text-[13px] text-slate-500 max-sm:hidden">Tamaño = severidad · observaciones no confirmadas</div>
    </div>
  )
}
