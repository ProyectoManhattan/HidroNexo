from nicegui import ui

from componentes.estado import Estado
from componentes.estilos import MOTIVOS, nivel


def construir(estado: Estado, al_elegir):
    @ui.refreshable
    def ranking():
        colonias = sorted(estado.colonias, key=lambda c: c["riesgo"], reverse=True)
        if not colonias:
            ui.label("No hay colonias cargadas. Usa ⚙ → Cargar datos.").classes("text-sm text-gray-500 py-6")
            return
        for c in colonias:
            n = nivel(c["nivel"])
            with ui.row().classes("w-full items-center no-wrap gap-3 py-2 border-b cursor-pointer hover:bg-gray-50").on(
                "click", lambda c=c: al_elegir(c["id"])
            ):
                ui.element("div").classes("w-2 self-stretch rounded").style(f"background:{n['color']}")
                with ui.column().classes("gap-0 grow"):
                    ui.label(c["nombre"]).classes("text-sm font-semibold")
                    ui.label(f"Motivo: {MOTIVOS.get(c.get('motivo'), '—')}").classes("text-xs text-gray-500")
                with ui.column().classes("gap-0 items-end"):
                    ui.label(f"{c['riesgo']:.2f}").classes("text-sm font-bold")
                    ui.label(n["texto"]).classes("text-xs font-semibold").style(f"color:{n['color']}")

    ranking()
    return ranking
