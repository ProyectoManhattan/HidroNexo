from nicegui import ui

from componentes.estado import Estado
from componentes.estilos import MOTIVOS, hace, nivel


def construir(estado: Estado, aprobar, descartar):
    """aprobar(alerta, texto_editado) y descartar(alerta) son funciones async de la página."""

    @ui.refreshable
    def bandeja():
        if not estado.alertas:
            with ui.column().classes("w-full items-center py-10 gap-2 text-gray-500"):
                ui.icon("check_circle", size="40px", color="green")
                ui.label("Sin alertas pendientes").classes("text-sm")
            return
        ui.label("Propuestas por la IA · pendientes de aprobar").classes("text-xs font-semibold text-gray-500")
        for alerta in estado.alertas:
            _tarjeta(estado, alerta, aprobar, descartar)
        if not estado.operador:
            ui.label("Entra en modo operador para editar y aprobar.").classes("text-xs text-gray-500")

    bandeja()
    return bandeja


def _tarjeta(estado: Estado, alerta: dict, aprobar, descartar):
    n = nivel(alerta["nivel"])
    with ui.card().classes("w-full p-4 gap-2 shadow-none border").style(f"border-left: 6px solid {n['color']}"):
        with ui.row().classes("w-full items-center no-wrap"):
            ui.label(estado.nombre_colonia(alerta["colonia_id"])).classes("text-base font-bold")
            ui.space()
            ui.label(n["texto"].upper()).classes("text-xs font-bold rounded-full px-3 py-1").style(
                f"background:{n['suave']};color:{n['color']}"
            )
        ui.label(
            f"Motivo principal: {MOTIVOS.get(alerta['motivo'], '—')} · {hace(alerta['creada_en'])}"
        ).classes("text-xs text-gray-500")
        with ui.row().classes("gap-2"):
            if alerta["simulada"]:
                ui.label("Simulación").classes("text-xs font-semibold rounded-full px-3 py-0.5 bg-orange-50 text-orange-900")
            if alerta["redactada_por"] == "llm":
                ui.label("Redactada por IA").classes("text-xs font-semibold rounded-full px-3 py-0.5 bg-purple-50 text-purple-800")
            else:
                ui.label("Plantilla").classes("text-xs font-semibold rounded-full px-3 py-0.5 bg-gray-100 text-gray-600")
        texto = ui.textarea(value=alerta["texto"]).props("outlined autogrow dense").classes("w-full text-sm")
        texto.set_enabled(estado.operador)
        with ui.row().classes("w-full justify-end gap-2"):
            ui.button("Descartar", on_click=lambda a=alerta: descartar(a)).props("outline color=negative no-caps")
            ui.button("Aprobar y enviar", on_click=lambda a=alerta, t=texto: aprobar(a, t.value)).props("unelevated no-caps")
