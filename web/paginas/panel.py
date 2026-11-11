"""Panel de Protección Civil: une los componentes y habla con la API."""
import asyncio

from nicegui import Client, ui

from api import cliente, tiempo_real
from componentes import barra_inferior, barra_superior, bandeja_alertas, lista_reportes, ranking_colonias
from componentes.dialogo_clave import pedir_clave
from componentes.estado import Estado
from componentes.estilos import CATEGORIAS, categoria
from componentes.mapa import Mapa


@ui.page("/")
async def panel(client: Client):
    ui.page_title("Agua y Lluvia · Panel")
    ui.colors(primary="#1E5AA8")
    ui.query("body").style("background:#F4F6F9")
    ui.query(".q-page").classes("flex")
    ui.query(".nicegui-content").classes("p-0 grow flex flex-col")

    estado = Estado()

    # ------------------------------------------------------------ utilidades
    async def ejecutar(accion, exito: str | None = None) -> bool:
        """Corre una llamada a la API, muestra el error si falla y recarga."""
        try:
            await accion()
        except cliente.ErrorApi as e:
            if e.estado == 401:
                estado.clave = None
            ui.notify(e.detalle, type="negative", position="top")
            return False
        if exito:
            ui.notify(exito, type="positive", position="top")
        await recargar()
        return True

    async def asegurar_operador() -> bool:
        if not estado.operador:
            clave = await pedir_clave()
            if not clave:
                return False
            estado.clave = clave
            await recargar()
        return True

    # ------------------------------------------------------------ acciones
    async def entrar_operador():
        await asegurar_operador()

    async def aprobar(alerta, texto):
        if not await asegurar_operador():
            return

        async def accion():
            if texto.strip() != alerta["texto"]:
                await cliente.editar_alerta(estado.clave, alerta["id"], texto.strip())
            await cliente.aprobar_alerta(estado.clave, alerta["id"])

        await ejecutar(accion, "Alerta aprobada y enviada")

    async def descartar(alerta):
        if await asegurar_operador():
            await ejecutar(lambda: cliente.descartar_alerta(estado.clave, alerta["id"]), "Alerta descartada")

    async def resolver(reporte):
        await ejecutar(lambda: cliente.resolver_reporte(estado.clave, reporte["id"]), "Reporte resuelto")

    async def filtrar(valor):
        estado.filtro = valor
        redibujar()

    async def iniciar_reporte_manual():
        if await asegurar_operador():
            estado.eligiendo_punto = True
            ui.notify("Haz clic en el mapa donde ocurre el problema", position="top")

    async def clic_en_mapa(e):
        if not estado.eligiendo_punto:
            return
        estado.eligiendo_punto = False
        punto = e.args["latlng"]
        await dialogo_reporte(punto["lat"], punto["lng"])

    async def dialogo_reporte(lat, lon):
        with ui.dialog() as dialogo, ui.card().classes("w-96 gap-3"):
            ui.label("Reporte manual").classes("text-lg font-bold")
            ui.label(f"Ubicación: {lat:.5f}, {lon:.5f}").classes("text-xs text-gray-500")
            tipo = ui.select({k: v["texto"] for k, v in CATEGORIAS.items()}, value="inundacion",
                             label="Tipo").classes("w-full")
            severidad = ui.toggle({1: "Baja", 2: "Media", 3: "Alta"}, value=2).props("no-caps")
            descripcion = ui.textarea("Descripción (opcional)").props("outlined autogrow").classes("w-full")
            with ui.row().classes("w-full justify-end"):
                ui.button("Cancelar", on_click=dialogo.close).props("flat")

                async def enviar():
                    datos = {"categoria": tipo.value, "severidad": severidad.value, "lat": lat, "lon": lon,
                             "descripcion": descripcion.value or None}
                    if await ejecutar(lambda: cliente.reporte_manual(estado.clave, datos), "Reporte creado"):
                        dialogo.close()

                ui.button("Enviar", on_click=enviar)
        dialogo.open()

    async def simular():
        if not await asegurar_operador():
            return
        if (estado.clima or {}).get("simulacion"):
            await terminar_simulacion()
            return
        with ui.dialog() as dialogo, ui.card().classes("w-96 gap-3"):
            ui.label("Simular tormenta").classes("text-lg font-bold")
            ui.label("Solo para la demo. Las alertas generadas quedan marcadas como simulación.").classes(
                "text-sm text-gray-600"
            )
            ui.label("Intensidad")
            intensidad = ui.slider(min=0.2, max=2.0, step=0.1, value=1.0).props("label-always")
            with ui.row().classes("w-full justify-end"):
                ui.button("Cancelar", on_click=dialogo.close).props("flat")

                async def iniciar():
                    dialogo.close()
                    await ejecutar(lambda: cliente.simular_tormenta(estado.clave, intensidad.value),
                                   "Simulación activada")

                ui.button("Iniciar", on_click=iniciar).style("background:#F28C28 !important")
        dialogo.open()

    async def terminar_simulacion():
        await ejecutar(lambda: cliente.terminar_tormenta(estado.clave), "Simulación terminada")

    async def confirmar(titulo, texto) -> bool:
        with ui.dialog() as dialogo, ui.card():
            ui.label(titulo).classes("text-lg font-bold")
            ui.label(texto).classes("text-sm")
            with ui.row().classes("w-full justify-end"):
                ui.button("Cancelar", on_click=lambda: dialogo.submit(False)).props("flat")
                ui.button("Continuar", on_click=lambda: dialogo.submit(True)).props("color=negative")
        return bool(await dialogo)

    async def seed():
        if await asegurar_operador() and await confirmar("Cargar datos", "Se borra todo y se cargan los datos de data/."):
            await ejecutar(lambda: cliente.seed(estado.clave), "Datos cargados")

    async def reset():
        if await asegurar_operador() and await confirmar("Reiniciar demo", "Se borran reportes, alertas y riesgo."):
            await ejecutar(lambda: cliente.reset(estado.clave), "Demo reiniciada")

    # ------------------------------------------------------------ interfaz
    superior = barra_superior.construir(estado, entrar_operador, terminar_simulacion)
    resumen, boton_simular = barra_inferior.construir(estado, filtrar, iniciar_reporte_manual, simular, seed, reset)

    with ui.right_drawer(fixed=True, value=True).props("width=400 bordered").classes("bg-white p-0"):
        with ui.tabs().props("align=left no-caps active-color=primary indicator-color=primary").classes(
            "w-full border-b text-gray-600"
        ) as pestanas:
            with ui.tab("alertas", label="Alertas"):
                contador_alertas = ui.badge(color="red").props("floating")
            with ui.tab("reportes", label="Reportes"):
                contador_reportes = ui.badge(color="grey-4", text_color="grey-9").props("floating")
            ui.tab("colonias", label="Colonias")
        with ui.tab_panels(pestanas, value="alertas").classes("w-full"):
            with ui.tab_panel("alertas").classes("gap-3"):
                bandeja = bandeja_alertas.construir(estado, aprobar, descartar)
            with ui.tab_panel("reportes").classes("p-3"):
                reportes_ui = lista_reportes.construir(estado, resolver)
            with ui.tab_panel("colonias").classes("p-3"):
                ranking = ranking_colonias.construir(estado, lambda cid: mapa.centrar(cid))

    mapa = Mapa(estado, clic_en_mapa)

    # ------------------------------------------------------------ datos
    def redibujar():
        superior.refresh()
        resumen.refresh()
        boton_simular.refresh()
        bandeja.refresh()
        reportes_ui.refresh()
        ranking.refresh()
        contador_alertas.set_text(str(len(estado.alertas)))
        contador_alertas.set_visibility(bool(estado.alertas))
        contador_reportes.set_text(str(len(estado.reportes_visibles())))
        mapa.dibujar()

    async def recargar():
        try:
            estado.riesgo, estado.reportes, estado.alertas = await asyncio.gather(
                cliente.riesgo(), cliente.reportes(), cliente.alertas()
            )
            if estado.operador:
                estado.clima = await cliente.clima(estado.clave)
            elif tiempo_real.ultimo_clima:
                estado.clima = tiempo_real.ultimo_clima
            estado.error = None
        except cliente.ErrorApi as e:
            estado.error = e.detalle
        redibujar()

    def avisar(evento):
        tipo, datos = evento.get("tipo"), evento.get("datos") or {}
        if tipo == "report.created":
            c = categoria(datos.get("categoria", ""))
            ui.notify(f"Nuevo reporte · {c['texto']} en {estado.nombre_colonia(datos.get('colonia_id'))}",
                      position="top-right", color="primary", icon="campaign")
        elif tipo == "alert.drafted":
            ui.notify(f"Nueva alerta propuesta · {estado.nombre_colonia(datos.get('colonia_id'))}",
                      position="top-right", type="warning", icon="notification_important")
        elif tipo == "alert.approved":
            ui.notify(f"Alerta enviada a {datos.get('dispositivos_notificados', 0)} dispositivos",
                      position="top-right", type="positive")

    ciclos = 0

    async def revisar():
        nonlocal ciclos
        ciclos += 1
        if tiempo_real.version != estado.version_vista or ciclos % 20 == 0:  # cada ~30 s refresca "hace X"
            nuevos = tiempo_real.eventos_desde(estado.evento_visto)
            estado.version_vista = estado.evento_visto = tiempo_real.version
            await recargar()
            for evento in nuevos[-5:]:
                avisar(evento)

    try:
        await client.connected(timeout=15)
    except TimeoutError:
        return
    estado.evento_visto = tiempo_real.version
    await revisar()
    ui.timer(1.5, revisar)
