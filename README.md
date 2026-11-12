# Agua y Lluvia · Veracruz

Plataforma de reportes ciudadanos, riesgo por zona y alertas ante lluvias e inundaciones en la ciudad de Veracruz. Proyecto del **Reto 3 · Agua y lluvia** (hackathon de 24 horas).

> **No sustituye al 911.** Ante un riesgo para la vida, llama a emergencias.

## Qué hace

1. La ciudadanía reporta inundaciones, encharcamientos, alcantarillas tapadas, fugas de agua y falta de agua desde una **app móvil**.
2. El **backend** cruza esos reportes con la lluvia observada y pronosticada ([Open-Meteo](https://open-meteo.com/)) y calcula un **índice de riesgo por zona** con una fórmula explicable (lluvia + reportes activos + vulnerabilidad base).
3. Cuando una zona sube a riesgo alto o crítico, el sistema redacta una **alerta con su guía de acción** (plantillas, o LLM si se configura una clave).
4. Un operador de Protección Civil la revisa en el **panel web** y la aprueba; solo entonces se envía a los dispositivos de la zona. **La IA propone, el humano decide.**

Sin cuentas ni roles: las acciones del operador (aprobar alertas, alerta manual, simulación) llevan una **clave única** en el header `X-Clave`. Es una barrera ligera, no seguridad real.

## Componentes

| Carpeta | Qué es | Tecnología |
| --- | --- | --- |
| [backend/](backend/) | API, riesgo, meteorología, alertas, tiempo real | FastAPI, PostgreSQL + PostGIS, Alembic, APScheduler, WebSocket |
| [web-react/](web-react/) | Panel de Protección Civil: mapa, reportes en vivo, bandeja de alertas | React, Vite, TypeScript, Tailwind, MapLibre |
| [movil/](movil/) | App ciudadana (solo Android) | Flutter |
| [data/](data/) | Zonas, reportes de prueba y guías de acción | GeoJSON y JSON |
| [docs/](docs/) | Plan, reparto, contrato de la API y diseño | Markdown |

El backend es un monolito modular con un bus de eventos en memoria, por eso corre con **un solo worker**.

```text
App móvil ──► API REST ──► Reportes ──► eventos ──► Riesgo ──► Alerta propuesta
Open-Meteo ──► tarea cada 15 min ──────────────────────┘            │
Panel web ◄── WebSocket (/ws) ◄─────────────────────────────────────┤
Panel web ──► aprobar (X-Clave) ──► notificación a la zona ──► App móvil
```

## Cómo levantarlo

**Requisitos:** Git, Docker (abierto) y Node.js 22. Con [mise](https://mise.jdx.dev/) basta `mise install` (también deja Python 3.12).

```bash
git clone https://github.com/ProyectoManhattan/Proyecto_Agua_Lluvia.git
cd Proyecto_Agua_Lluvia
cp .env.example .env
```

### 1. Backend (terminal 1)

Migra la base y arranca la API:

```bash
docker compose up --build
```

- Salud: <http://localhost:8000/health>
- Documentación interactiva (OpenAPI): <http://localhost:8000/docs>

### 2. Panel web (terminal 2)

```bash
cd web-react
npm install
npm run dev
```

Abrir <http://localhost:5173>.

### 3. Usarlo

El panel es exclusivo de Protección Civil y no pide clave: la lleva configurada (`VITE_CLAVE`, por defecto igual a `CLAVE_UNICA` de `.env`).

1. Al abrirlo por primera vez ya hay un reporte de ejemplo por zona (el backend los carga solo con la base vacía).
2. **Simular tormenta** → aparecen alertas propuestas → **Aprobar y enviar**.
3. **Enviar alerta manual** → Protección Civil redacta una alerta propia para una o varias zonas.
4. **⚙ → Cargar datos (seed)** vuelve a dejar todo como al inicio.

### 4. App móvil (opcional)

**AguaVer** requiere Flutter y un emulador o dispositivo Android, con el backend levantado (paso 1):

```bash
cd movil
flutter run                                              # emulador: usa http://10.0.2.2:8000
flutter run --dart-define=API_URL=http://192.168.1.10:8000   # celular físico: IP de tu computadora
flutter run --dart-define=USE_MOCK=true                  # sin backend, con datos de ejemplo
flutter test
```

Ya envía reportes y lee reportes, zonas y alertas aprobadas del backend. Mapa real (MapLibre) con riesgo por zona de `/zones/risk`. Pendiente: subir fotos (la API aún no recibe archivos), clima de la zona y notificaciones push (`POST /devices`).

**Apagar:** `docker compose down` (añade `-v` para borrar también la base de datos).

Más detalle y solución de problemas: [docs/como-ejecutar.md](docs/como-ejecutar.md).

## Pruebas

```bash
docker compose exec api pytest
```

Las pruebas de flujo usan una base aparte (`<base>_test`) y nunca la principal.

## Datos

- [data/colonias_veracruz.geojson](data/colonias_veracruz.geojson): límites reales por **código postal** (fuente SEPOMEX vía [open-mexico/mexico-geojson](https://github.com/open-mexico/mexico-geojson), licencia MIT), no por colonia. Cubre los municipios de **Veracruz, Boca del Río y Medellín de Bravo** (101 zonas); cada zona se asigna a su municipio con los límites del Marco Geoestadístico de INEGI vía [PhantomInsights/mexico-geojson](https://github.com/PhantomInsights/mexico-geojson) (MIT). Un código postal que cruza un límite municipal queda en el municipio de su punto interior. Se regeneran con `python3 data/scripts/generar_colonias.py`; para ampliar la zona se agregan municipios a `MUNICIPIOS` en ese script.
- La **vulnerabilidad base es modelada**: sale de la susceptibilidad física de [data/perfiles/](data/perfiles/) (relieve, cauces, distancia al mar) con `python3 data/scripts/asignar_vulnerabilidad.py`. Es un índice relativo sin calibrar que no incluye factores sociales.
- El seed ya no crea reportes de ejemplo. Los datos de `backend/tests/datos/` son ficticios y solo sirven para las pruebas.

## Estado actual

| Parte | Estado |
| --- | --- |
| Backend | Completo con 27 pruebas pasando. Pendientes: envío push real (FCM), redacción con LLM y calibración de pesos del riesgo |
| Panel web | Mapa por zona, reportes en vivo, alertas, simulación y reporte manual funcionando contra la API |
| App móvil | Reportes y alertas conectados al backend; faltan fotos, clima y push |
| Datos | Faltan guías de acción y reportes de prueba reales, y vulnerabilidad real por zona |

## Documentación

- [Plan de trabajo](docs/plan-de-trabajo.md): alcance, fases y riesgos.
- [Reparto de trabajo](docs/reparto.md): tareas por persona y reglas de Git.
- [Contrato de la API](docs/api.md): endpoints con cuerpos JSON.
- [Backend](backend/README.md) · [Panel web](web-react/README.md)
