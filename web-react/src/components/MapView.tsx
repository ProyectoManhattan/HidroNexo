import * as maplibregl from 'maplibre-gl'
import type { GeoJSONSource, Map as MLMap } from 'maplibre-gl'
import maplibreWorkerUrl from 'maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url'
import { useEffect, useMemo, useRef, useState } from 'react'
import { MAPTILER_KEY } from '../config'
import { CATEGORIAS, NIVELES, UMBRAL_PROB_ALTA } from '../constants'
import { seleccionarColonia, useStore } from '../store'
import type { Reporte, ZonasGeoJSON } from '../types'
import Legend from './map/Legend'
import { popupColonia, popupReporte } from './map/popups'

// MapLibre v6 requiere registrar explícitamente el worker cuando se empaqueta con Vite.
maplibregl.setWorkerUrl(maplibreWorkerUrl)

const CENTRO: [number, number] = [-96.13, 19.17]
const ZOOM = 12
const VACIO = { type: 'FeatureCollection', features: [] } as const
const CAPAS_ZONA = ['zonas-volumen', 'zonas-fill']

const alturaNivel: maplibregl.ExpressionSpecification = [
  'match', ['get', 'nivel'],
  'bajo', 60,
  'medio', 400,
  'alto', 900,
  'critico', 1600,
  60,
] as unknown as maplibregl.ExpressionSpecification

const colorSusceptibilidad: maplibregl.ExpressionSpecification = [
  'interpolate', ['linear'], ['get', 'susceptibilidad'],
  0, '#2E8B57',
  33, '#E9C46A',
  66, '#F28C28',
  100, '#C62828',
] as unknown as maplibregl.ExpressionSpecification

const alturaSusceptibilidad: maplibregl.ExpressionSpecification = [
  'interpolate', ['linear'], ['get', 'susceptibilidad'],
  0, 60,
  33, 400,
  66, 900,
  100, 1600,
] as unknown as maplibregl.ExpressionSpecification

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

/** MapLibre convierte objetos anidados en texto: se copian prob_3h y pron_mm_3h al nivel superior. */
function conPronosticoPlano(zonas: ZonasGeoJSON) {
  return {
    ...zonas,
    features: zonas.features.map((f) => ({
      ...f,
      properties: {
        ...f.properties,
        prob_3h: f.properties.pronostico?.prob_3h ?? -1,
        pron_mm_3h: f.properties.pronostico?.mm_3h ?? 0,
        susceptibilidad: f.properties.perfil_territorial?.indice_susceptibilidad_preliminar ?? -1,
        elevacion_mediana_m: f.properties.perfil_territorial?.elevacion_mediana_m ?? null,
        hand_mediana_m: f.properties.perfil_territorial?.hand_mediana_m ?? null,
      },
    })),
  }
}

function reportesGeoJSON(reportes: Reporte[], zonas: ZonasGeoJSON | null) {
  const nombres = new Map(zonas?.features.map((f) => [f.properties.id, f.properties.nombre]))
  return {
    type: 'FeatureCollection' as const,
    features: reportes.map((r) => ({
      type: 'Feature' as const,
      id: r.id,
      geometry: { type: 'Point' as const, coordinates: [r.lon, r.lat] },
      properties: {
        id: r.id, categoria: r.categoria, severidad: r.severidad, descripcion: r.descripcion, foto_url: r.foto_url ?? null,
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
  const [modo3d, setModo3d] = useState(false)
  const [capa, setCapa] = useState<'riesgo' | 'territorio'>('riesgo')

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
    const estiloBase: maplibregl.StyleSpecification | string = MAPTILER_KEY
      ? `https://api.maptiler.com/maps/streets-v2/style.json?key=${MAPTILER_KEY}`
      : {
          version: 8,
          sources: {
            osm: {
              type: 'raster',
              tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
              tileSize: 256,
              maxzoom: 19,
              attribution: '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors',
            },
            'terreno-3d': {
              type: 'raster-dem',
              tiles: ['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'],
              tileSize: 256,
              encoding: 'terrarium',
              maxzoom: 14,
            },
            'terreno-sombra': {
              type: 'raster-dem',
              tiles: ['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'],
              tileSize: 256,
              encoding: 'terrarium',
              maxzoom: 14,
            },
          },
          layers: [
            { type: 'raster', id: 'osm', source: 'osm' },
            {
              type: 'hillshade',
              id: 'sombra-terreno',
              source: 'terreno-sombra',
              paint: {
                'hillshade-exaggeration': 0.85,
                'hillshade-shadow-color': '#0f172a',
                'hillshade-highlight-color': '#ffffff',
                'hillshade-accent-color': '#0284c7',
              },
            },
          ],
        }

    const map = new maplibregl.Map({
      container: cont.current,
      center: CENTRO,
      zoom: ZOOM,
      attributionControl: { compact: true },
      style: estiloBase,
    })
    mapRef.current = map
    map.addControl(new maplibregl.NavigationControl({ showCompass: true, visualizePitch: true }), 'top-right')

    const hover = new maplibregl.Popup({ closeButton: false, closeOnClick: false, offset: 8, maxWidth: '300px' })
    let popupReport: maplibregl.Popup | null = null

    map.on('load', () => {
      // Terreno 3D (MapTiler Terrain-RGB o AWS Terrarium DEM)
      if (!map.getSource('terreno-3d')) {
        map.addSource('terreno-3d', {
          type: 'raster-dem',
          url: MAPTILER_KEY
            ? `https://api.maptiler.com/tiles/terrain-rgb-v2/tiles.json?key=${MAPTILER_KEY}`
            : undefined,
          tiles: MAPTILER_KEY
            ? undefined
            : ['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'],
          tileSize: 256,
          encoding: MAPTILER_KEY ? 'mapbox' : 'terrarium',
          maxzoom: 14,
        })
      }
      if (!map.getSource('terreno-sombra')) {
        map.addSource('terreno-sombra', {
          type: 'raster-dem',
          url: MAPTILER_KEY
            ? `https://api.maptiler.com/tiles/terrain-rgb-v2/tiles.json?key=${MAPTILER_KEY}`
            : undefined,
          tiles: MAPTILER_KEY
            ? undefined
            : ['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'],
          tileSize: 256,
          encoding: MAPTILER_KEY ? 'mapbox' : 'terrarium',
          maxzoom: 14,
        })
      }

      // Sombreado de relieve (hillshade) para profundidad visual de cuencas y elevaciones
      if (!map.getLayer('sombra-terreno')) {
        map.addLayer({
          id: 'sombra-terreno',
          type: 'hillshade',
          source: 'terreno-sombra',
          paint: {
            'hillshade-exaggeration': 0.85,
            'hillshade-shadow-color': '#0f172a',
            'hillshade-highlight-color': '#ffffff',
            'hillshade-accent-color': '#0284c7',
          },
        })
      }

      // Edificios 3D si la fuente vectorial de MapTiler (openmaptiles) está activa
      if (map.getSource('openmaptiles') && !map.getLayer('edificios-3d')) {
        map.addLayer({
          id: 'edificios-3d',
          source: 'openmaptiles',
          'source-layer': 'building',
          type: 'fill-extrusion',
          minzoom: 13,
          paint: {
            'fill-extrusion-color': '#94a3b8',
            'fill-extrusion-height': ['coalesce', ['get', 'render_height'], 10],
            'fill-extrusion-base': ['coalesce', ['get', 'render_min_height'], 0],
            'fill-extrusion-opacity': 0.85,
          },
        })
      }

      map.addSource('zonas', { type: 'geojson', data: VACIO as never })
      map.addSource('reportes', { type: 'geojson', data: VACIO as never })
      map.addLayer({
        id: 'zonas-fill', type: 'fill', source: 'zonas',
        paint: { 'fill-color': colorNivel, 'fill-opacity': 0.45, 'fill-color-transition': { duration: 600 } },
        layout: { visibility: 'none' },
      })
      map.addLayer({
        id: 'zonas-volumen', type: 'fill-extrusion', source: 'zonas',
        paint: {
          'fill-extrusion-color': colorNivel,
          'fill-extrusion-height': alturaNivel,
          'fill-extrusion-base': 0,
          'fill-extrusion-opacity': 0.66,
          'fill-extrusion-vertical-gradient': true,
          'fill-extrusion-color-transition': { duration: 600 },
          'fill-extrusion-height-transition': { duration: 600 },
        },
      })
      map.addLayer({
        id: 'zonas-line', type: 'line', source: 'zonas',
        paint: { 'line-color': '#8A94A6', 'line-width': 1, 'line-dasharray': [2, 2] },
      })
      // Lluvia probable: borde azul punteado en zonas con probabilidad alta en las próximas 3 h
      map.addLayer({
        id: 'zonas-pronostico', type: 'line', source: 'zonas',
        filter: ['>=', ['get', 'prob_3h'], UMBRAL_PROB_ALTA],
        paint: { 'line-color': '#126783', 'line-width': 2.5, 'line-dasharray': [1.5, 1.5] },
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
      const zon = rep.length ? [] : map.queryRenderedFeatures(e.point, { layers: CAPAS_ZONA })
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
      const zon = map.queryRenderedFeatures(e.point, { layers: CAPAS_ZONA })
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
    ;(map.getSource('zonas') as GeoJSONSource).setData((zonas ? conPronosticoPlano(zonas) : VACIO) as never)
    if (zonas && !encuadrado.current) {
      const b = limites(zonas)
      if (b) {
        map.fitBounds(b, {
          padding: 40,
          duration: 0,
          maxZoom: 15,
          pitch: modo3d ? 58 : 0,
          bearing: modo3d ? -15 : 0,
        })
        // El encuadre territorial completo es el límite de alejamiento. El usuario
        // puede acercarse, pero no reducir el mapa hasta perder el área de servicio.
        map.setMinZoom(map.getZoom())
        encuadrado.current = true
      }
    }
  }, [zonas, listo, modo3d])

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

  // Vista operativa plana o perspectiva 3D. Las fuentes, filtros y eventos son los mismos.
  useEffect(() => {
    const map = mapRef.current
    if (!listo || !map) return
    map.setLayoutProperty('zonas-fill', 'visibility', modo3d ? 'none' : 'visible')
    map.setLayoutProperty('zonas-volumen', 'visibility', modo3d ? 'visible' : 'none')
    if (map.getLayer('sombra-terreno')) {
      map.setLayoutProperty('sombra-terreno', 'visibility', modo3d ? 'visible' : 'none')
    }
    if (map.getLayer('edificios-3d')) {
      map.setLayoutProperty('edificios-3d', 'visibility', modo3d ? 'visible' : 'none')
    }
    map.setTerrain(modo3d ? { source: 'terreno-3d', exaggeration: 4.5 } : null)
    map.easeTo({
      pitch: modo3d ? 58 : 0,
      bearing: modo3d ? -15 : 0,
      duration: 700,
    })
  }, [modo3d, listo])

  // Alterna entre el riesgo operativo en vivo y la susceptibilidad física estática.
  useEffect(() => {
    const map = mapRef.current
    if (!listo || !map) return
    const color = capa === 'territorio' ? colorSusceptibilidad : colorNivel
    const altura = capa === 'territorio' ? alturaSusceptibilidad : alturaNivel
    map.setPaintProperty('zonas-fill', 'fill-color', color)
    map.setPaintProperty('zonas-volumen', 'fill-extrusion-color', color)
    map.setPaintProperty('zonas-volumen', 'fill-extrusion-height', altura)
  }, [capa, listo])

  return (
    <div className="flex h-full w-full flex-col overflow-hidden">
      <div className="flex min-h-14 items-center gap-3 border-b border-[#dce6f5] bg-white px-4 text-[#0b2b70]">
        <svg viewBox="0 0 24 24" className="h-7 w-7 text-[#0d5ac7]" fill="none" stroke="currentColor" strokeWidth="2.1" aria-hidden><path d="m3 6 6-3 6 3 6-3v15l-6 3-6-3-6 3V6Z"/><path d="M9 3v15m6-12v15"/></svg>
        <h2 className="text-lg font-black">Información del territorio</h2>
        <span className="ml-auto hidden text-sm font-semibold text-slate-500 lg:block">{capa === 'riesgo' ? 'Cálculo operativo actualizado' : 'Índice físico preliminar · no es probabilidad'}</span>
      </div>
      <div className="relative min-h-0 flex-1 overflow-hidden">
        <div ref={cont} style={{ position: 'absolute', inset: 0 }} />
        <div className="absolute left-4 top-4 z-10 flex gap-2 max-sm:left-2 max-sm:right-2" role="group" aria-label="Capa del mapa">
          <button type="button" onClick={() => setCapa('riesgo')} aria-pressed={capa === 'riesgo'} className={`flex min-h-12 items-center gap-2 rounded-2xl border px-5 text-sm font-extrabold shadow-md ${capa === 'riesgo' ? 'border-[#0d5ac7] bg-[#0d5ac7] text-white' : 'border-[#d5e1f4] bg-white/95 text-[#0b2b70]'}`}>
            <span aria-hidden>△</span> Riesgo en vivo
          </button>
          <button type="button" onClick={() => setCapa('territorio')} aria-pressed={capa === 'territorio'} className={`flex min-h-12 items-center gap-2 rounded-2xl border px-5 text-sm font-extrabold shadow-md ${capa === 'territorio' ? 'border-[#0d5ac7] bg-[#0d5ac7] text-white' : 'border-[#d5e1f4] bg-white/95 text-[#0b2b70]'}`}>
            <span aria-hidden>▱</span> Susceptibilidad territorial
          </button>
        </div>
        <button type="button" onClick={() => setModo3d((v) => !v)} aria-pressed={modo3d} className="absolute right-16 top-4 z-10 flex min-h-12 items-center gap-2 rounded-2xl border border-[#d5e1f4] bg-white/95 px-4 text-sm font-extrabold text-[#0b2b70] shadow-md hover:bg-white max-sm:right-2 max-sm:top-20" title={modo3d ? 'Cambiar a vista operativa plana 2D' : 'Cambiar a perspectiva 3D con volumen'}>
          <span aria-hidden>▰</span> {modo3d ? 'Vista 3D' : 'Vista 2D'}
        </button>
        {capa === 'riesgo' ? (
          <Legend />
        ) : (
          <div className="control-group absolute bottom-3 left-3 z-10 p-3 text-sm max-sm:bottom-20 max-sm:left-2">
            <div className="mb-1 font-semibold text-slate-700">Susceptibilidad relativa</div>
            <div className="flex items-center gap-2">
              <span className="h-2.5 w-8 rounded" style={{ background: 'linear-gradient(90deg,#2E8B57,#E9C46A,#F28C28,#C62828)' }} />
              <span className="text-slate-500">Baja</span><span>→</span><span className="text-slate-500">Elevada</span>
            </div>
            <div className="mt-1 text-sm font-semibold text-slate-700">Índice preliminar, no probabilidad</div>
          </div>
        )}
      </div>
    </div>
  )
}
