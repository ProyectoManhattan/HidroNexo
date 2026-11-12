import { MOTIVOS, SEVERIDADES, categoriaInfo, hace, nivelInfo } from '../../constants'

const esc = (s: unknown) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!)

export function popupColonia(p: Record<string, unknown>): string {
  const n = nivelInfo(p.nivel as string)
  const motivo = MOTIVOS[p.motivo as keyof typeof MOTIVOS] ?? '—'
  return (
    `<div style="min-width:180px;font-size:13px">` +
    `<div style="display:flex;justify-content:space-between;align-items:center;gap:10px">` +
    `<b>${esc(p.nombre)}</b>` +
    `<span style="background:${n.suave};color:${n.color};font-weight:700;font-size:10px;padding:2px 8px;border-radius:9px">${esc(n.texto.toUpperCase())}</span></div>` +
    `<div style="color:#5B6675;font-size:12px;margin-top:4px">Motivo principal: ${esc(motivo)}</div></div>`
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

