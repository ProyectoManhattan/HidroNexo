from nicegui import ui

from api import tiempo_real
from componentes.estado import Estado
from componentes.estilos import AZUL


def construir(estado: Estado, al_entrar_operador, al_terminar_simulacion):
    with ui.header(elevated=False).classes("bg-white text-gray-900 border-b p-0 flex-col gap-0"):

        @ui.refreshable
        def contenido():
            with ui.row().classes("w-full items-center px-4 h-16 gap-4 no-wrap"):
                with ui.element("div").classes("rounded-full w-9 h-9 flex items-center justify-center bg-blue-50"):
                    ui.icon("water_drop", color=AZUL).classes("text-xl")
                with ui.column().classes("gap-0"):
                    ui.label("Agua y Lluvia · Veracruz").classes("text-lg font-bold leading-tight")
                    ui.label("Panel de Protección Civil").classes("text-xs text-gray-500")
                ui.space()

                lluvia = (estado.clima or {}).get("lluvia") or {}
                texto = f"Lluvia 3 h: {lluvia['mm_3h']:.0f} mm" if "mm_3h" in lluvia else "Lluvia: sin dato"
                with ui.row().classes("items-center gap-2 bg-gray-100 rounded-full px-4 py-1"):
                    ui.icon("water_drop", color="#3A8DDE")
                    ui.label(texto).classes("text-sm font-semibold")
                    if (estado.clima or {}).get("simulacion"):
                        ui.label("(sim.)").classes("text-sm font-semibold text-orange-500")

                en_vivo = tiempo_real.conectado and not estado.error
                color, etiqueta = ("green", "En vivo") if en_vivo else ("red", "Sin conexión")
                with ui.row().classes(f"items-center gap-2 bg-{color}-50 rounded-full px-4 py-1"):
                    ui.element("div").classes(f"w-2.5 h-2.5 rounded-full bg-{color}-600")
                    ui.label(etiqueta).classes(f"text-sm font-semibold text-{color}-700")

                ui.space()
                ui.label("No sustituye al 911").classes(
                    "text-xs font-semibold text-red-600 border border-red-200 rounded-full px-3 py-1"
                )
                if estado.operador:
                    with ui.row().classes("items-center gap-2 bg-blue-50 rounded-lg px-4 py-2"):
                        ui.label("Operador: Protección Civil").classes("text-sm font-semibold text-blue-800")
                        ui.element("div").classes("w-2 h-2 rounded-full bg-green-600")
                else:
                    ui.button("Modo operador", icon="lock", on_click=al_entrar_operador).props("unelevated")

            if (estado.clima or {}).get("simulacion"):
                with ui.row().classes("w-full items-center px-4 py-1.5 gap-3 bg-orange-50 border-t border-orange-200"):
                    ui.label("SIMULACIÓN").classes(
                        "text-xs font-bold text-white bg-orange-500 rounded px-3 py-0.5 tracking-wide"
                    )
                    ui.label("Tormenta simulada activa. Los datos de lluvia no son reales.").classes(
                        "text-sm text-orange-900"
                    )
                    ui.space()
                    if estado.operador:
                        ui.button("Terminar simulación", on_click=al_terminar_simulacion).props(
                            "flat dense no-caps color=orange-10"
                        ).classes("font-bold")

            if estado.error:
                with ui.row().classes("w-full items-center px-4 py-1.5 gap-2 bg-red-50 border-t border-red-200"):
                    ui.icon("cloud_off", color="red")
                    ui.label(f"{estado.error}. Se reintenta automáticamente.").classes("text-sm text-red-800")

        contenido()
    return contenido
