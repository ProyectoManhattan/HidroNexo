import { MOTIVOS, SEVERIDADES, categoriaInfo, hace, nivelInfo } from '../../constants'

const esc = (s: unknown) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!)

/** Usa las propiedades planas que agrega MapView (MapLibre convierte objetos anidados en texto). */
function lineaPronostico(p: Record<string, unknown>): string {
  const prob = Number(p.prob_3h)
  if (!Number.isFinite(prob) || prob < 0) return ''
  const mm = Number(p.pron_mm_3h ?? 0)
  return (
    `<div style="color:#1E5AA8;font-size:12px;margin-top:4px">` +
    `Pronóstico 3 h: ${esc(mm.toFixed(1))} mm · ${esc(Math.round(prob))} % de probabilidad</div>`
  )
}

function lineaTerritorio(p: Record<string, unknown>): string {
  const indice = Number(p.susceptibilidad)
  if (!Number.isFinite(indice) || indice < 0) return ''
  const elevacion = Number(p.elevacion_mediana_m)
  const hand = Number(p.hand_mediana_m)
  const distancia = Number(p.distancia_agua_m)
  const datos = [
    Number.isFinite(elevacion) ? `elevación ${elevacion.toFixed(1)} m` : '',
    Number.isFinite(hand) ? `HAND ${hand.toFixed(1)} m` : '',
    Number.isFinite(distancia) ? `agua a ${Math.round(distancia)} m` : '',
  ].filter(Boolean).join(' · ')
  return (
    `<div style="color:#334155;font-size:12px;margin-top:5px">` +
    `Susceptibilidad territorial: <b>${esc(Math.round(indice))}/100</b>` +
    (datos ? `<br><span style="color:#64748b">${esc(datos)}</span>` : '') +
    `</div>`
  )
}

export function popupColonia(p: Record<string, unknown>): string {
  const n = nivelInfo(p.nivel as string)
  const motivo = MOTIVOS[p.motivo as keyof typeof MOTIVOS] ?? '—'
  return (
    `<div style="min-width:180px;font-size:13px">` +
    `<div style="display:flex;justify-content:space-between;align-items:center;gap:10px">` +
    `<b>${esc(p.nombre)}</b>` +
    `<span style="background:${n.suave};color:${n.color};font-weight:700;font-size:10px;padding:2px 8px;border-radius:9px">${esc(n.texto.toUpperCase())}</span></div>` +
    `<div style="color:#5B6675;font-size:12px;margin-top:4px">Motivo principal: ${esc(motivo)}</div>` +
    lineaPronostico(p) +
    lineaTerritorio(p) +
    `</div>`
  )
}

export function popupReporte(p: Record<string, unknown>): string {
  const c = categoriaInfo(p.categoria as string)
  const sev = SEVERIDADES[Number(p.severidad) as 1 | 2 | 3] ?? ''
  const desc = p.descripcion ? `<div style="margin:6px 0">${esc(p.descripcion)}</div>` : ''
  const col = p.colonia ? `<div style="color:#5B6675;font-size:12px">Colonia: ${esc(p.colonia)}</div>` : ''
  return (
    `<div style="min-width:190px;max-width:260px;font-size:13px">` +
    `<div style="display:flex;align-items:center;gap:6px"><span style="width:10px;height:10px;border-radius:50%;background:${c.color}"></span>` +
    `<b>${esc(c.texto)}</b></div>` +
    `<div style="color:#5B6675;font-size:12px;margin-top:2px">Severidad ${esc(sev)} · ${esc(hace(p.creado_en as string))}</div>` +
    `${desc}${col}</div>`
  )
}

