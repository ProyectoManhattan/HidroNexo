import math

from nicegui import ui

from componentes.estado import Estado
from componentes.estilos import CATEGORIAS, MOTIVOS, NIVELES, SEVERIDADES, categoria, hace, nivel, segundos_desde
from config import ATRIBUCION_MAPA, CENTRO_MAPA, TEJAS_MAPA, ZOOM_MAPA


CSS = (
    """
.leaflet-tooltip.etiqueta-colonia { background: transparent; border: none; box-shadow: none;
  font-weight: 600; font-size: 12px; color: #1B2430; text-align: center; line-height: 1.2; }
.leaflet-tooltip.etiqueta-colonia::before { display: none; }
.leaflet-popup-content { margin: 14px 16px; }
.leaflet-container { background: #EEF1EA; }
"""
)


def _centro(geometria: dict | None) -> tuple[float, float] | None:
    if not geometria:
        return None
    puntos = []
    coords = geometria["coordinates"]
    anillos = [p[0] for p in coords] if geometria["type"] == "MultiPolygon" else [coords[0]]
    for anillo in anillos:
        puntos.extend(anillo)
    lon = sum(p[0] for p in puntos) / len(puntos)
    lat = sum(p[1] for p in puntos) / len(puntos)
    return lat, lon


def _popup_colonia(p: dict) -> str:
    n = nivel(p["nivel"])
    barras = ""
    for clave, etiqueta in (("lluvia", "Lluvia"), ("reportes", "Reportes"), ("vulnerabilidad", "Vulnerabilidad")):
        valor = (p.get("componentes") or {}).get(clave, 0)
        barras += (
            f'<div style="display:flex;align-items:center;gap:8px;margin:6px 0">'
            f'<span style="width:96px;color:#5B6675">{etiqueta}</span>'
            f'<span style="flex:1;height:8px;background:#EEF1F5;border-radius:4px">'
            f'<span style="display:block;height:8px;width:{valor * 100:.0f}%;background:#1E5AA8;border-radius:4px"></span></span>'
            f'<span style="width:36px;text-align:right;font-weight:600">{valor * 100:.0f}%</span></div>'
        )
    motivo = MOTIVOS.get(p.get("motivo"), "—")
    return (
        f'<div style="min-width:260px;font-family:inherit">'
        f'<div style="display:flex;justify-content:space-between;align-items:center;gap:12px">'
        f'<b style="font-size:15px">{p["nombre"]}</b>'
        f'<span style="background:{n["suave"]};color:{n["color"]};font-weight:700;font-size:11px;'
        f'padding:2px 10px;border-radius:10px">{n["texto"].upper()}</span></div>'
        f'<div style="color:#5B6675;font-size:12px;margin:2px 0 8px">Riesgo {p["riesgo"]:.2f} · '
        f'{hace(p.get("actualizado_en"))}</div>'
        f'<b style="font-size:12px">¿Por qué?</b>{barras}'
        f'<div style="color:#5B6675;font-size:11px;margin-top:6px">Motivo principal: {motivo}</div></div>'
    )


class Mapa:
    def __init__(self, estado: Estado, al_hacer_clic):
        self.estado = estado
        self.capas = []
        self.encuadrado = False
        ui.add_css(CSS)
        with ui.element("div").classes("relative w-full grow"):
            self.m = ui.leaflet(center=CENTRO_MAPA, zoom=ZOOM_MAPA).classes("absolute inset-0 w-full h-full")
            self.m.clear_layers()
            self.m.tile_layer(url_template=TEJAS_MAPA, options={"attribution": ATRIBUCION_MAPA, "maxZoom": 19})
            self.m.on("map-click", al_hacer_clic)
            self._leyenda()

    def _leyenda(self):
        with ui.card().classes("absolute left-3 bottom-6 z-[1000] p-3 gap-2 shadow-md"):
            ui.label("Riesgo por colonia").classes("text-xs font-bold")
            with ui.row().classes("gap-3"):
                for n in NIVELES.values():
                    with ui.row().classes("items-center gap-1"):
                        ui.element("div").classes("w-3.5 h-3.5 rounded").style(f"background:{n['color']};opacity:.8")
                        ui.label(n["texto"]).classes("text-xs text-gray-600")
            ui.label("Reportes (tamaño = severidad)").classes("text-xs font-bold mt-1")
            with ui.grid(columns=3).classes("gap-x-3 gap-y-1"):
                for c in CATEGORIAS.values():
                    with ui.row().classes("items-center gap-1 no-wrap"):
                        ui.element("div").classes("w-3 h-3 rounded-full").style(f"background:{c['color']}")
                        ui.label(c["texto"]).classes("text-xs text-gray-600")

    def centrar(self, colonia_id: int):
        for f in self.estado.riesgo.get("features", []):
            if f["properties"]["id"] == colonia_id:
                centro = _centro(f["geometry"])
                if centro:
                    self.m.set_center(centro)
                    self.m.set_zoom(15)

    def encuadrar(self):
        """Centra el mapa en las colonias (solo la primera vez que hay datos).

        Se usa set_center/set_zoom y no fitBounds: NiceGUI vuelve a aplicar su
        centro y zoom en cada actualización y desharía un fitBounds del navegador.
        """
        if self.encuadrado:
            return
        puntos = []
        for f in self.estado.riesgo.get("features", []):
            centro = _centro(f.get("geometry"))
            if centro:
                puntos.append(centro)
        if not puntos:
            return
        self.encuadrado = True
        lats, lons = [p[0] for p in puntos], [p[1] for p in puntos]
        span = max(max(lats) - min(lats), max(lons) - min(lons), 0.005) + 0.02
        # ~1000 px de ancho de mapa; 360° caben en 256 px a zoom 0
        zoom = max(10, min(16, math.floor(math.log2(1000 / 256 * 360 / span))))
        self.m.set_center(((min(lats) + max(lats)) / 2, (min(lons) + max(lons)) / 2))
        self.m.set_zoom(zoom)

    def dibujar(self):
        self.encuadrar()
        for capa in self.capas:
            self.m.remove_layer(capa)
        self.capas = []

        for f in self.estado.riesgo.get("features", []):
            if not f.get("geometry"):
                continue
            p = f["properties"]
            n = nivel(p["nivel"])
            critica = p["nivel"] in ("alto", "critico")
            capa = self.m.generic_layer(
                name="geoJSON",
                args=[f, {"style": {"color": n["color"], "weight": 3 if critica else 1.5,
                                    "fillColor": n["color"], "fillOpacity": 0.28}}],
            )
            capa.run_method("bindPopup", _popup_colonia(p))
            capa.run_method(
                "bindTooltip",
                f'{p["nombre"]}<br><span style="color:{n["color"]};font-size:10px;font-weight:700">'
                f'{n["texto"].upper()}</span>',
                {"permanent": True, "direction": "center", "className": "etiqueta-colonia"},
            )
            self.capas.append(capa)

        for r in self.estado.reportes_visibles():
            c = categoria(r["categoria"])
            if segundos_desde(r["creado_en"]) < 90:  # Resaltar reportes nuevos
                self.capas.append(self.m.generic_layer(
                    name="circleMarker",
                    args=[[r["lat"], r["lon"]], {"radius": 18 + r["severidad"] * 2, "stroke": False,
                                                 "fillColor": c["color"], "fillOpacity": 0.25}],
                ))
            punto = self.m.generic_layer(
                name="circleMarker",
                args=[[r["lat"], r["lon"]], {"radius": 5 + r["severidad"] * 2, "color": "#FFFFFF", "weight": 2,
                                             "fillColor": c["color"], "fillOpacity": 1}],
            )
            detalle = f"<b>{c['texto']}</b><br>Severidad {SEVERIDADES.get(r['severidad'], '')} · {hace(r['creado_en'])}"
            if r.get("descripcion"):
                detalle += f"<br><i>{r['descripcion']}</i>"
            punto.run_method("bindTooltip", detalle)
            self.capas.append(punto)
