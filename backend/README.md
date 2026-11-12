# Backend · Agua y Lluvia

API en **FastAPI + PostgreSQL/PostGIS**. Un solo proceso: el bus de eventos vive en memoria.

## Levantar

Desde la raíz del repositorio:

```bash
cp .env.example .env
docker compose up --build
```

- Salud: http://localhost:8000/health
- Documentación interactiva (OpenAPI): http://localhost:8000/docs
- Contrato con JSON de ejemplo: [docs/api.md](../docs/api.md)

Las migraciones (`alembic upgrade head`) corren solas al arrancar el contenedor.

**Primera carga:** si la base no tiene colonias, la API carga únicamente el catálogo
geográfico de `data/colonias_veracruz.geojson`. Los reportes empiezan vacíos y llegan
por `POST /reports` desde Flutter o por el panel. `AUTO_SEED=true` queda reservado para
una demo desechable; en producción debe permanecer en `false`.

Crear una demo sintética explícita (borra todo antes; no usar en producción):

```bash
curl -X POST localhost:8000/admin/seed -H "X-Clave: cambiar-esta-clave"
```

## Pruebas

```bash
docker compose exec api pytest
```

Las pruebas de flujo usan una base aparte (`<base>_test`, se crea sola) y **nunca** la principal. Sin base de datos disponible, esas pruebas se saltan y corren solo las unitarias.

## Cómo está organizado

```
app/
├── main.py            Arranque, routers y tarea de Open-Meteo
├── config.py          Variables de entorno y parámetros (expiración, enfriamiento…)
├── catalogos.py       Categorías y severidades (datos, no enums: se cambian sin migración)
├── eventos.py         Bus de eventos en memoria
├── suscripciones.py   Quién escucha cada evento
├── seguridad.py       Clave única (header X-Clave)
├── reportes/          POST/GET /reports, colonia automática, expiración
├── colonias/          Punto → colonia, GET /zones y /zones/risk (GeoJSON)
├── riesgo/            calculo.py = fórmula pura; servicio.py = guarda y publica eventos
├── meteorologia/      Ingesta de Open-Meteo y tormenta simulada
├── alertas/           Borrador, edición, aprobación y descarte
├── ia/                Redacción de alertas (LLM + plantillas) y clasificador
├── guias/             Lee data/guias/<tipo>.json
├── dispositivos/      Registro de la app Flutter y su colonia
├── notificaciones/    Envío push (pendiente: FCM)
├── tiempo_real/       WebSocket /ws hacia el panel
└── admin/             seed, reset, simulate-storm
migraciones/           Alembic
tests/                 Unitarias y de flujo completo
```

Cada módulo tiene `modelos.py` (tablas), `esquemas.py` (entrada y salida de la API), `servicio.py` (lógica) y `router.py` (endpoints).

## Flujo

```
POST /reports ─► report.created ─► riesgo de la colonia
Open-Meteo / simulate-storm ─► weather.updated ─► riesgo de todas
riesgo sube a alto/crítico (con enfriamiento) ─► zone.threshold_crossed ─► la IA propone alerta
POST /alerts/{id}/approve (clave) ─► push a los dispositivos de la colonia ─► alert.approved
Todos los eventos relevantes ─► WebSocket /ws ─► panel web
```

Mensajes del WebSocket: `{"tipo": "<evento>", "datos": {...}}`.

## Endpoints

| Método | Ruta | Clave | Uso |
|---|---|---|---|
| GET | `/health` | | Salud |
| GET | `/reports/categories` | | Categorías y severidades |
| POST | `/reports` | | Reporte desde la app |
| POST | `/reports/manual` | ✔ | Reporte desde el panel |
| GET | `/reports` | | Filtros: `categoria`, `colonia_id`, `activos`, `bbox` |
| POST | `/reports/{id}/resolve` | ✔ | Marcar resuelto |
| GET | `/zones` | | Lista de colonias (para elegir en la app) |
| GET | `/zones/risk` | | GeoJSON con riesgo, nivel y motivo |
| GET | `/alerts` | | Bandeja (por defecto, `estado=propuesta`) |
| GET | `/alerts/active` | | Alertas aprobadas vigentes con su guía (respaldo del push) |
| PATCH | `/alerts/{id}` | ✔ | Editar texto |
| POST | `/alerts` | ✔ | Alerta manual a una o varias colonias (se envía de inmediato) |
| POST | `/alerts/{id}/approve` | ✔ | Aprobar y enviar |
| POST | `/alerts/{id}/discard` | ✔ | Descartar |
| GET | `/guides`, `/guides/{tipo}` | | Guías de acción |
| POST | `/devices` | | Registrar token push y colonia |
| POST | `/admin/seed`, `/admin/reset` | ✔ | Demo |
| POST, DELETE | `/admin/simulate-storm` | ✔ | Iniciar o terminar la simulación |
| GET | `/admin/weather` | ✔ | Lluvia que se está usando |
| WS | `/ws` | | Tiempo real para el panel |

## Datos que espera (`data/`)

| Archivo | Formato |
|---|---|
| `colonias_veracruz.geojson` | FeatureCollection de Polygon/MultiPolygon (EPSG:4326). Propiedades: `nombre` (obligatoria), `municipio`, `vulnerabilidad` (0–1), `vulnerabilidad_fuente` (`real`/`ejemplo`) |
| `reportes_prueba.json` | Lista de `{"categoria", "severidad", "lat", "lon", "descripcion"}` |
| `guias/<tipo>.json` | Una guía por categoría (`inundacion`, `encharcamiento`, `alcantarilla`, `fuga`, `sin_agua`) |

En `tests/datos/` hay ejemplos **ficticios** con ese formato.

## Pendientes (`TODO` en el código)

| Dónde | Qué | Quién |
|---|---|---|
| `riesgo/calculo.py` | Calibrar pesos, umbrales y saturación | A y B |
| `riesgo/servicio.py` | Ponderar reportes por confirmaciones y antigüedad | A |
| `colonias/servicio.py` | Colonia más cercana si el punto cae en un borde | A |
| `reportes/servicio.py` | Límite de solicitudes y confirmaciones | A |
| `alertas/servicio.py` | Elegir la guía según la categoría más reportada | A |
| `notificaciones/push.py` | Envío real con FCM (**probar antes de la hora 15**) | A con C |
| `ia/redactor_alertas.py` | Llamada al LLM | C |
| `ia/clasificador.py` | Clasificación con LLM | C |
