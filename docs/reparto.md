# Reparto de trabajo · 3 personas

> Basado en [plan-de-trabajo.md](plan-de-trabajo.md). El plan tiene 4 frentes; con 3 personas, **IA y datos se divide** entre Web (datos) y Móvil (IA y guías). Backend es el frente más cargado, por eso no recibe tareas extra.

## Resumen

| Persona | Frente principal | Frente extra | Rama | Carpeta |
|---|---|---|---|---|
| **A** | Backend | Contrato OpenAPI (lo coordina) | `backend/*` | `backend/` |
| **B** | Página web (Protección Civil) | Datos: colonias, vulnerabilidad, seed | `web/*` | `web/`, `data/` |
| **C** | App móvil (ciudadanía) | IA: prompts, plantillas y guías | `movil/*` | `movil/`, `backend/app/ia/` |

Cada quien trabaja en su carpeta para evitar conflictos. Los cambios a carpetas ajenas van por PR y los revisa el dueño de esa carpeta.

## Persona A · Backend

| Fase | Tareas |
|---|---|
| 0 (h 0–2) | Estructura del repo, Docker Compose (FastAPI + PostgreSQL/PostGIS), Alembic, `GET /health`. **Publicar el contrato OpenAPI** (incluye categorías de fuga y tandeo) y definir la clave única |
| 1 (h 2–8) | Tabla de colonias, función punto → colonia, `POST/GET /reports` con filtros, expiración, WebSocket al panel |
| 2 (h 8–13) | Ingesta de Open-Meteo (APScheduler, 15 min), cálculo de riesgo (función pura con pruebas, histéresis y enfriamiento), `GET /zones/risk` en GeoJSON |
| 3 (h 13–18) | Endpoints de guías, borrador de alerta (integra el módulo de IA de C), aprobación con clave única, registro de dispositivos, envío por colonia |
| 4 (h 18–21) | `POST /admin/simulate-storm`, `seed`, `reset`, pruebas de caminos críticos |

## Persona B · Web + Datos

| Fase | Tareas |
|---|---|
| 0 (h 0–2) | **Conseguir polígonos de colonias de Veracruz** (GeoJSON en `data/`), vulnerabilidad base (fuente real o rotulada como ejemplo), 30–50 reportes de prueba. Crear el proyecto web en Python con datos simulados |
| 1 (h 2–8) | Mapa con reportes en vivo por WebSocket |
| 2 (h 8–13) | Capa de colonias por riesgo con el **motivo**; formulario de reporte manual; calibrar pesos y umbrales junto con A |
| 3 (h 13–18) | Bandeja de alertas propuestas: edición y aprobación con clave única; filtro por categoría |
| 4 (h 18–21) | Botón "Simular tormenta" (rotulado como simulación), integración y pruebas |

## Persona C · Móvil + IA

| Fase | Tareas |
|---|---|
| 0 (h 0–2) | Crear el proyecto móvil en **Flutter** (`flutter create` dentro de `movil/`) con datos simulados según el contrato |
| 1 (h 2–8) | Reporte en 3 pasos (tipo, ubicación con pin ajustable, severidad, foto opcional), elegir colonia, mapa de reportes. En ratos libres: probar prompts de clasificación y borrador de alerta |
| 2 (h 8–13) | Capa de colonias por riesgo. Escribir guías por tipo (inundación, encharcamiento, alcantarilla, fuga, tandeo) basadas en lineamientos oficiales de Protección Civil, como datos (JSON) |
| 3 (h 13–18) | Registro del dispositivo, notificación push (**prueba antes de la h 15**), pantalla de alerta con guía, caché de la última guía. Entregar a A el módulo de borrador con LLM + respaldo por plantillas |
| 4 (h 18–21) | Integración y pruebas en celular real |

## Todos

- **h 0–2:** acordar el contrato OpenAPI juntos antes de programar.
- **h 8:** punto de control. Si el reporte del celular no llega al panel, todos ayudan a A.
- **Jueves 7:00:** leer el requisito nuevo y decidir en 15 minutos qué se recorta (sección 7 del plan).
- **h 21–24:** congelar código a la h 22, grabar video de respaldo y ensayar el pitch.

## Reglas de Git

1. Antes de empezar: `git pull origin main`.
2. Ramas por tarea con el prefijo de tu frente, por ejemplo `backend/reportes`, `web/mapa`, `movil/formulario`.
3. Commits pequeños y `push` seguido.
4. Integrar a `main` mediante pull request.

## Estructura del repositorio

Backend y web se trabajan en **Python**; la app móvil, en **Flutter**. Las carpetas ya están creadas (vacías, con `.gitkeep`):

```
backend/                 # Persona A
├── app/
│   ├── reportes/        # POST/GET /reports, colonia y expiración
│   ├── colonias/        # punto → colonia, GET /zones/risk
│   ├── meteorologia/    # Ingesta de Open-Meteo
│   ├── riesgo/          # Cálculo de riesgo (función pura)
│   ├── alertas/         # Borrador, aprobación y envío
│   ├── dispositivos/    # Registro y notificaciones push
│   ├── tiempo_real/     # WebSocket hacia el panel
│   ├── admin/           # simulate-storm, seed, reset
│   └── ia/              # Persona C: prompts/ y plantillas/
├── migraciones/
└── tests/
data/                    # Persona B: colonias, vulnerabilidad, reportes de prueba
└── guias/               # Persona C: guías por tipo de problema (como datos)
web/                     # Persona B: api/, componentes/, paginas/, static/
movil/                   # Persona C: proyecto Flutter (lo genera `flutter create`)
docs/                    # Plan, reparto y contrato de la API
```
