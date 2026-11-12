import { MOTIVOS, SEVERIDADES, categoriaInfo, hace, nivelInfo, urlFotoSegura } from '../../constants'

const esc = (s: unknown) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!)

/** Usa las propiedades planas que agrega MapView (MapLibre convierte objetos anidados en texto). */
function lineaPronostico(p: Record<string, unknown>): string {
  const prob = Number(p.prob_3h)
  if (!Number.isFinite(prob) || prob < 0) return ''
  const mm = Number(p.pron_mm_3h ?? 0)
  return (
    `<div style="color:#126783;font-size:14px;margin-top:4px">` +
    `Pronóstico 3 h: ${esc(mm.toFixed(1))} mm · ${esc(Math.round(prob))} % de probabilidad</div>`
  )
}

function lineaTerritorio(p: Record<string, unknown>): string {
  const indice = Number(p.susceptibilidad)
  if (!Number.isFinite(indice) || indice < 0) return ''
  const elevacion = Number(p.elevacion_mediana_m)
  const hand = Number(p.hand_mediana_m)
  const puntuacion = Math.round(indice)
  const nivel = puntuacion < 33
    ? { texto: 'Baja', color: '#237a4b', fondo: '#eaf6ef' }
    : puntuacion < 66
      ? { texto: 'Media', color: '#8a5b00', fondo: '#fff5d9' }
      : puntuacion < 85
        ? { texto: 'Alta', color: '#b54708', fondo: '#fff0e5' }
        : { texto: 'Elevada', color: '#b4232c', fondo: '#fdeced' }
  const metrica = (etiqueta: string, valor: string) =>
    `<div style="display:flex;flex-direction:column;gap:1px;padding:7px 9px;border:1px solid #e2e8f0;border-radius:8px;background:#f8fafc">` +
    `<span style="color:#64748b;font-size:11px;font-weight:700;letter-spacing:.02em;text-transform:uppercase">${esc(etiqueta)}</span>` +
    `<strong style="color:#1e293b;font-size:14px;line-height:1.25">${esc(valor)}</strong></div>`
  return (
    `<div style="margin-top:9px;padding-top:9px;border-top:1px solid #e2e8f0">` +
    `<div style="display:flex;align-items:center;justify-content:space-between;gap:12px">` +
    `<span style="color:#475569;font-size:11px;font-weight:800;letter-spacing:.055em;text-transform:uppercase">Susceptibilidad territorial</span>` +
    `<span style="padding:2px 8px;border-radius:999px;background:${nivel.fondo};color:${nivel.color};font-size:11px;font-weight:800">${nivel.texto}</span></div>` +
    `<div style="display:flex;align-items:baseline;gap:3px;margin:3px 0 8px;color:#0b2b70">` +
    `<strong style="font-size:24px;line-height:1">${esc(puntuacion)}</strong>` +
    `<span style="color:#64748b;font-size:12px;font-weight:700">/ 100</span></div>` +
    `<div style="display:grid;gap:6px">` +
    (Number.isFinite(elevacion) ? metrica('Elevación mediana', `${elevacion.toFixed(1)} m s. n. m.`) : '') +
    (Number.isFinite(hand) ? metrica('Altura sobre drenaje (HAND)', `${hand.toFixed(1)} m`) : '') +
    `</div>` +
    `</div>`
  )
}

export function popupColonia(p: Record<string, unknown>): string {
  const n = nivelInfo(p.nivel as string)
  const motivo = MOTIVOS[p.motivo as keyof typeof MOTIVOS] ?? '—'
  return (
    `<div style="min-width:230px;font-size:14px">` +
    `<div style="display:flex;justify-content:space-between;align-items:center;gap:10px">` +
    `<b>${esc(p.nombre)}</b>` +
    `<span style="background:${n.suave};color:${n.color};font-weight:700;font-size:12px;padding:2px 8px;border-radius:9px">${esc(n.texto.toUpperCase())}</span></div>` +
    `<div style="color:#5B6675;font-size:13px;margin-top:4px">Motivo principal: ${esc(motivo)}</div>` +
    lineaPronostico(p) +
    lineaTerritorio(p) +
    `</div>`
  )
}

export function popupReporte(p: Record<string, unknown>): string {
  const c = categoriaInfo(p.categoria as string)
  const sev = SEVERIDADES[Number(p.severidad) as 1 | 2 | 3] ?? ''
  const desc = p.descripcion ? `<div style="margin:6px 0">${esc(p.descripcion)}</div>` : ''
  const col = p.colonia ? `<div style="color:#526273;font-size:14px">Zona postal: ${esc(p.colonia)}</div>` : ''
  const foto = urlFotoSegura(p.foto_url)
  const img = foto
    ? `<a href="${esc(foto)}" target="_blank" rel="noopener noreferrer" title="Ver foto ampliada">` +
      `<img src="${esc(foto)}" alt="Foto del reporte enviada por el ciudadano" loading="lazy" referrerpolicy="no-referrer" ` +
      `onerror="this.parentNode.style.display='none'" ` +
      `style="display:block;width:100%;height:120px;object-fit:cover;border-radius:8px;margin-top:8px;background:#e5e7eb"></a>`
    : ''
  return (
    `<div style="min-width:190px;max-width:260px;font-size:14px">` +
    `<div style="display:flex;align-items:center;gap:6px"><span style="width:10px;height:10px;border-radius:50%;background:${c.color}"></span>` +
    `<b>${esc(c.texto)}</b></div>` +
    `<div style="color:#5B6675;font-size:13px;margin-top:2px">Severidad ${esc(sev)} · ${esc(hace(p.creado_en as string))}</div>` +
    `${desc}${col}${img}</div>`
  )
}

