import * as maplibregl from 'maplibre-gl'
import type { GeoJSONSource, Map as MLMap } from 'maplibre-gl'
import { useEffect, useMemo, useRef, useState } from 'react'
import { CATEGORIAS, NIVELES } from '../constants'
import { seleccionarColonia, useStore } from '../store'
import type { Reporte, ZonasGeoJSON } from '../types'
import Legend from './map/Legend'
import { popupColonia, popupReporte } from './map/popups'

const CENTRO: [number, number] = [-96.13, 19.17]
const ZOOM = 12
const VACIO = { type: 'FeatureCollection', features: [] } as const

const colorNivel: maplibregl.ExpressionSpecification = [
  'match', ['get', 'nivel'],
  ...Object.entries(NIVELES).flatMap(([k, v]) => [k, v.color]),
  NIVELES.bajo.color,
] as unknown as maplibregl.ExpressionSpecification
const colorCategoria: maplibregl.ExpressionSpecification = [
  'match', ['get', 'categoria'],
  ...Object.entries(CATEGORIAS).flatMap(([k, v]) => [k, v.color]),
  '#5B6675',
] as unknown as maplibregl.ExpressionSpecification

function reportesGeoJSON(reportes: Reporte[], zonas: ZonasGeoJSON | null) {
  const nombres = new Map(zonas?.features.map((f) => [f.properties.id, f.properties.nombre]))
  return {
    type: 'FeatureCollection' as const,
    features: reportes.map((r) => ({
      type: 'Feature' as const,
      id: r.id,
      geometry: { type: 'Point' as const, coordinates: [r.lon, r.lat] },
      properties: {
        id: r.id, categoria: r.categoria, severidad: r.severidad, descripcion: r.descripcion,
        creado_en: r.creado_en, colonia: r.colonia_id != null ? nombres.get(r.colonia_id) ?? null : null,
      },
    })),
  }
}

function limites(z: ZonasGeoJSON): maplibregl.LngLatBounds | null {
  const b = new maplibregl.LngLatBounds()
  let n = 0
  const rec = (c: unknown): void => {
    if (Array.isArray(c) && typeof c[0] === 'number') { b.extend(c as [number, number]); n++ }
    else if (Array.isArray(c)) c.forEach(rec)
  }
  z.features.forEach((f) => rec(f.geometry?.coordinates))
  return n ? b : null
}

export default function MapView() {
  const cont = useRef<HTMLDivElement>(null)
  const mapRef = useRef<MLMap | null>(null)
  const encuadrado = useRef(false)
  const [listo, setListo] = useState(false)

  const zonas = useStore((s) => s.zonas)
  const reportes = useStore((s) => s.reportes)
  const filtro = useStore((s) => s.filtro)
  const seleccionada = useStore((s) => s.coloniaSeleccionada)

  const visibles = useMemo(() => reportes.filter((r) => {
    if (filtro === 'todo') return true
    const lluvia = CATEGORIAS[r.categoria]?.grupo === 'lluvia'
    return (filtro === 'lluvia') === lluvia
  }), [reportes, filtro])

  // Creacion / limpieza del mapa
  useEffect(() => {
    if (!cont.current) return
    const map = new maplibregl.Map({
      container: cont.current,
      center: CENTRO,
      zoom: ZOOM,
      attributionControl: { compact: true },
      style: {
        version: 8,
        sources: {
          osm: {
            type: 'raster', tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'], tileSize: 256, maxzoom: 19,
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors',
          },
        },
        layers: [{ type: 'raster', id: 'osm', source: 'osm' }],
      },
    })
    mapRef.current = map
    map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right')

    const hover = new maplibregl.Popup({ closeButton: false, closeOnClick: false, offset: 8 })
    let popupReport: maplibregl.Popup | null = null

    map.on('load', () => {
      map.addSource('zonas', { type: 'geojson', data: VACIO as never })
      map.addSource('reportes', { type: 'geojson', data: VACIO as never })
      map.addLayer({
        id: 'zonas-fill', type: 'fill', source: 'zonas',
        paint: { 'fill-color': colorNivel, 'fill-opacity': 0.45, 'fill-color-transition': { duration: 600 } },
      })
      map.addLayer({
        id: 'zonas-line', type: 'line', source: 'zonas',
        paint: { 'line-color': '#8A94A6', 'line-width': 1, 'line-dasharray': [2, 2] },
      })
      map.addLayer({
        id: 'zonas-sel', type: 'line', source: 'zonas', filter: ['==', ['get', 'id'], -1],
        paint: { 'line-color': '#1B2430', 'line-width': 3.5 },
      })
      map.addLayer({
        id: 'zonas-sel-nivel', type: 'line', source: 'zonas', filter: ['==', ['get', 'id'], -1],
        paint: { 'line-color': colorNivel, 'line-width': 1.6 },
      })
      map.addLayer({
        id: 'reportes-circulos', type: 'circle', source: 'reportes',
        paint: {
          'circle-color': colorCategoria,
          'circle-radius': ['interpolate', ['linear'], ['get', 'severidad'], 1, 6, 2, 9, 3, 13],
          'circle-opacity': 0.9, 'circle-stroke-color': '#fff', 'circle-stroke-width': 2,
        },
      })
      setListo(true)
    })

    map.on('mousemove', (e) => {
      if (!map.getLayer('zonas-fill')) return
      const rep = map.queryRenderedFeatures(e.point, { layers: ['reportes-circulos'] })
      const zon = rep.length ? [] : map.queryRenderedFeatures(e.point, { layers: ['zonas-fill'] })
      map.getCanvas().style.cursor = rep.length || zon.length ? 'pointer' : ''
      if (zon.length) hover.setLngLat(e.lngLat).setHTML(popupColonia(zon[0].properties)).addTo(map)
      else hover.remove()
    })
    map.on('mouseout', () => hover.remove())

    map.on('click', (e) => {
      if (!map.getLayer('zonas-fill')) return
      const rep = map.queryRenderedFeatures(e.point, { layers: ['reportes-circulos'] })
      if (rep.length) {
        popupReport?.remove()
        popupReport = new maplibregl.Popup({ offset: 12, maxWidth: '280px' })
          .setLngLat((rep[0].geometry as unknown as { coordinates: number[] }).coordinates as [number, number])
          .setHTML(popupReporte(rep[0].properties))
          .addTo(map)
        return
      }
      const zon = map.queryRenderedFeatures(e.point, { layers: ['zonas-fill'] })
      if (zon.length) seleccionarColonia(Number(zon[0].properties.id))
    })

    const ro = new ResizeObserver(() => map.resize())
    ro.observe(cont.current)

    return () => {
      ro.disconnect()
      hover.remove()
      popupReport?.remove()
      map.remove()
      mapRef.current = null
      encuadrado.current = false
      setListo(false)
    }
  }, [])

  // Colonias
  useEffect(() => {
    const map = mapRef.current
    if (!listo || !map) return
    ;(map.getSource('zonas') as GeoJSONSource).setData((zonas ?? VACIO) as never)
    if (zonas && !encuadrado.current) {
      const b = limites(zonas)
      if (b) { map.fitBounds(b, { padding: 40, duration: 0, maxZoom: 15 }); encuadrado.current = true }
    }
  }, [zonas, listo])

  // Reportes
  useEffect(() => {
    const map = mapRef.current
    if (!listo || !map) return
    ;(map.getSource('reportes') as GeoJSONSource).setData(reportesGeoJSON(visibles, zonas) as never)
  }, [visibles, zonas, listo])

  // Colonia seleccionada
  useEffect(() => {
    const map = mapRef.current
    if (!listo || !map) return
    const f: maplibregl.FilterSpecification = ['==', ['get', 'id'], seleccionada ?? -1]
    map.setFilter('zonas-sel-nivel', f)
    map.setFilter('zonas-sel', f)
  }, [seleccionada, listo])

  return (
    <div className="relative h-full w-full overflow-hidden">
      <div ref={cont} style={{ position: 'absolute', inset: 0 }} />
      <Legend />
    </div>
  )
}
