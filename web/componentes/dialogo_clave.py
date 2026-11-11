from nicegui import ui

from api import cliente


async def pedir_clave() -> str | None:
    """Pide la clave única y la valida contra la API. Devuelve la clave o None."""
    with ui.dialog() as dialogo, ui.card().classes("w-96 gap-3"):
        ui.label("Modo operador").classes("text-lg font-bold")
        ui.label("Las acciones que modifican (aprobar alertas, simular, reportes manuales) "
                 "requieren la clave única del equipo.").classes("text-sm text-gray-600")
        campo = ui.input("Clave", password=True, password_toggle_button=True).classes("w-full")
        error = ui.label().classes("text-sm text-red-600")

        async def validar():
            try:
                await cliente.clima(campo.value)
                dialogo.submit(campo.value)
            except cliente.ErrorApi as e:
                error.text = "Clave incorrecta" if e.estado == 401 else e.detalle

        campo.on("keydown.enter", validar)
        with ui.row().classes("w-full justify-end"):
            ui.button("Cancelar", on_click=lambda: dialogo.submit(None)).props("flat")
            ui.button("Entrar", on_click=validar)
    resultado = await dialogo
    dialogo.clear()
    return resultado
