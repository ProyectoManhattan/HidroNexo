from nicegui import ui

from componentes.estado import Estado


def construir(estado: Estado, al_filtrar, al_reporte_manual, al_simular, al_seed, al_reset):
    with ui.footer(elevated=False).classes("bg-white text-gray-900 border-t px-4 py-2"):
        with ui.row().classes("w-full items-center gap-4 no-wrap"):
            ui.label("Mostrar:").classes("text-sm font-semibold text-gray-500")
            ui.toggle(
                {"todo": "Todo", "lluvia": "Lluvia", "agua": "Agua (fugas y tandeo)"},
                value=estado.filtro,
                on_change=lambda e: al_filtrar(e.value),
            ).props("no-caps unelevated rounded toggle-color=primary color=grey-2 text-color=grey-8")

            @ui.refreshable
            def resumen():
                ui.label(
                    f"{len(estado.reportes_visibles())} reportes activos · "
                    f"{estado.en_alto_o_critico()} colonias en alto o crítico"
                ).classes("text-sm text-gray-500")

            resumen()
            ui.space()
            ui.button("Reporte manual", icon="add_location_alt", on_click=al_reporte_manual).props(
                "outline no-caps color=dark"
            )

            @ui.refreshable
            def boton_simular():
                activa = (estado.clima or {}).get("simulacion")
                ui.button(
                    "Terminar simulación" if activa else "Simular tormenta",
                    icon="thunderstorm",
                    on_click=al_simular,
                ).props("unelevated no-caps").style("background:#F28C28 !important;color:white")

            boton_simular()
            with ui.button(icon="settings").props("outline round color=grey-8"):
                with ui.menu():
                    ui.menu_item("Cargar datos de data/ (seed)", on_click=al_seed)
                    ui.menu_item("Reiniciar demo (reset)", on_click=al_reset)
    return resumen, boton_simular
