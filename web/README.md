# Panel web · Protección Civil

Panel en **NiceGUI** (todo en Python) conectado al backend. Sigue el boceto de `docs/diseno/panel-web.svg`; las capturas con la API funcionando están en `docs/diseno/capturas/`.

## Levantar

Primero el backend (ver `backend/README.md`). Luego:

```bash
cd web
pip install -r requirements.txt
python main.py
```

Abre http://localhost:8080.

| Variable | Por defecto | Uso |
|---|---|---|
| `API_URL` | `http://localhost:8000` | Dirección del backend |
| `PUERTO_WEB` | `8080` | Puerto del panel |

Para tener datos: en el panel, **⚙ → Cargar datos (seed)**, que carga lo que haya en `data/`. Mientras `data/` esté vacía, puedes levantar el backend con `DATA_DIR=backend/tests/datos` para usar los datos ficticios de las pruebas.

## Cómo está organizado

```
main.py                  Arranque y escucha del WebSocket del backend
config.py                URL de la API, centro del mapa
api/
├── cliente.py           Llamadas HTTP a la API (contrato en docs/api.md)
└── tiempo_real.py       Una conexión a /ws; cada evento sube un número de versión
componentes/
├── estado.py            Datos de cada pestaña del navegador (clave, filtro, reportes…)
├── estilos.py           Colores por nivel y categoría, "hace X min"
├── barra_superior.py    Título, lluvia, En vivo, 911, modo operador, banner de simulación
├── mapa.py              Colonias por riesgo con su "¿Por qué?", reportes y leyenda
├── bandeja_alertas.py   Alertas propuestas: editar, aprobar, descartar
├── lista_reportes.py    Reportes en vivo; resolver
├── ranking_colonias.py  Colonias ordenadas por riesgo; clic para centrar el mapa
├── barra_inferior.py    Filtro, reporte manual, simular tormenta, ⚙ seed/reset
└── dialogo_clave.py     Pide y valida la clave única
paginas/
└── panel.py             Une todo; recarga datos cuando llega un evento
```

**Tiempo real.** `api/tiempo_real.py` mantiene una sola conexión al WebSocket del backend. Cada navegador revisa cada 1.5 s si hubo eventos nuevos; si los hay, vuelve a pedir los datos y muestra un aviso ("Nuevo reporte…", "Nueva alerta propuesta…").

**Modo operador.** Sin clave, el panel solo se puede ver. Al entrar con la clave única se habilitan aprobar, descartar, editar, reporte manual, simulación y ⚙.

## Pendientes

- Mostrar la lluvia sin modo operador: hoy `GET /admin/weather` pide clave.
- Sonido al llegar una alerta propuesta.
- Historial de alertas enviadas.
