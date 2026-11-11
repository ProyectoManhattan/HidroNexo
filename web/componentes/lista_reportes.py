from nicegui import ui

from componentes.estado import Estado
from componentes.estilos import SEVERIDADES, categoria, hace


def construir(estado: Estado, resolver):
    @ui.refreshable
    def lista():
        reportes = estado.reportes_visibles()
        if not reportes:
            ui.label("No hay reportes activos con este filtro.").classes("text-sm text-gray-500 py-6")
            return
        for r in reportes:
            c = categoria(r["categoria"])
            with ui.row().classes("w-full items-start no-wrap gap-3 py-2 border-b"):
                ui.label(c["letra"]).classes(
                    "w-8 h-8 rounded-full text-white text-xs font-bold flex items-center justify-center shrink-0"
                ).style(f"background:{c['color']}")
                with ui.column().classes("gap-0 grow"):
                    ui.label(c["texto"]).classes("text-sm font-semibold")
                    ui.label(
                        f"{estado.nombre_colonia(r['colonia_id'])} · severidad {SEVERIDADES.get(r['severidad'])}"
                    ).classes("text-xs text-gray-600")
                    if r.get("descripcion"):
                        ui.label(r["descripcion"]).classes("text-xs text-gray-500 italic")
                    ui.label(f"{hace(r['creado_en'])} · {r['origen']}").classes("text-xs text-gray-400")
                if estado.operador:
                    ui.button(icon="done", on_click=lambda r=r: resolver(r)).props(
                        "flat round dense color=positive"
                    ).tooltip("Marcar como resuelto")

    lista()
    return lista
