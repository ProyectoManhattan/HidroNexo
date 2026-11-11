# Plan de trabajo · Plataforma de alertas por agua y lluvia (Veracruz)

> Hackathon de 24 horas · Reto 3: Agua y lluvia · Última actualización: 2026-11-11

## 1. Contexto

**Reto.** Veracruz vive dos extremos: colonias que se inundan en temporada de lluvias y colonias con tandeo o fugas de agua. La información existe dispersa y casi nunca llega a tiempo a quien la necesita.

**Qué busca el reto.** Una solución que use datos e IA para anticipar, alertar o reducir problemas de agua: alertas de encharcamiento por colonia, detección de fugas a partir de reportes, guía de qué hacer ante una inundación o tablero de riesgo. Se vale cualquier tecnología.

**Para quién.** Familias de colonias vulnerables, Protección Civil y organismos operadores de agua.

**Requisito nuevo.** El jueves a las 7:00 el reto recibe un requisito adicional. Ver [sección 7](#7-reserva-para-el-requisito-nuevo).

**Nota.** La plataforma no sustituye al 911. La app lo indica de forma visible.

## 2. Solución

Dos aplicaciones conectadas por un backend común, **sin roles ni cuentas de usuario**.

| Componente | Descripción |
|---|---|
| **App móvil (ciudadanía)** | Emitir reportes, elegir colonia, ver mapa de afectaciones y riesgo, recibir alertas con guía de acción rápida |
| **Página web (Protección Civil)** | Mapa interactivo por colonia con reportes en vivo y riesgo, bandeja de alertas propuestas, aprobación y envío, simulación de tormenta |
| **Backend común** | API, datos geoespaciales, ingesta meteorológica, modelo de riesgo, borrador de alertas con IA y notificaciones |

**Modelo simple.** Un índice de riesgo por colonia que combina datos meteorológicos, reportes ciudadanos y vulnerabilidad base. Cuando una colonia cruza el umbral, la IA redacta una alerta con su plan de acción y un operador la aprueba antes del envío (**la IA propone, el humano decide**).

## 3. Decisiones tomadas

| Decisión | Motivo |
|---|---|
| Sin roles ni JWT | Simplifica el MVP; la autenticación completa va al roadmap |
| **Clave única** para acciones que modifican (aprobar alerta, `/admin/*`, reporte manual, editar guías) | Un panel totalmente abierto permite que cualquiera envíe alertas o reinicie la demo. Se implementa con una variable de entorno y un header, no con roles |
| Unidad de alerta: **colonia** | El reto lo pide así y la gente conoce su colonia. Internamente se puede usar una cuadrícula si ayuda al cálculo |
| La persona **elige su colonia** de una lista | Más simple y fiable que el GPS; evita guardar ubicación exacta |
| Cubrir **lluvia y fugas/tandeo** | El reto tiene dos extremos; el sistema de reportes ya es genérico |
| Monolito modular con bus de eventos en memoria, **un solo worker** | Evita complejidad operativa; el bus en memoria no funciona con varios procesos |
| Modelo de riesgo = fórmula explicable, no modelo entrenado | No hay datos históricos propios todavía |

## 4. Alcance

### 4.1 Núcleo (obligatorio)

**App móvil**
- Reportar: inundación, encharcamiento, alcantarilla tapada, fuga de agua, sin agua / tandeo
- Ubicación con ajuste manual del pin, severidad visual, foto opcional (solo se almacena y muestra)
- Elegir colonia al registrarse
- Mapa de reportes activos y riesgo por colonia
- Recepción de alertas con guía de acción rápida
- Última guía guardada en caché para consultarla sin conexión

**Página web**
- Mapa por colonia con color de riesgo y **motivo** del riesgo (lluvia, reportes, vulnerabilidad)
- Reportes en tiempo real (WebSocket)
- Bandeja de alertas propuestas, edición y aprobación
- Filtro por categoría (útil para el organismo operador de agua)
- Botón "Simular tormenta", rotulado visiblemente como simulación

**Backend**
- Reportes con asignación automática de colonia y expiración
- Meteorología (Open-Meteo) cada 15 minutos
- Cálculo de riesgo con histéresis y enfriamiento
- Borrador de alerta con plantilla y LLM opcional, aprobación y envío
- Guías por tipo de problema
- Registro de dispositivos
- `seed`, `simulate-storm`, `reset`

### 4.2 Si sobra tiempo

- Detección automática de fugas por agrupación de reportes (radio + ventana de tiempo)
- Clasificación de reportes con LLM
- Edición de guías desde el panel
- Capa estática de refugios temporales
- Categoría "paso a desnivel inundado"

### 4.3 Fuera del MVP (roadmap)

Roles y autenticación completa, modo offline completo, despacho a cuadrillas, historial detallado de estados, análisis de fotos, modelo entrenado con histórico, integración de sensores, factor costero (nortes y marea).

## 5. Arquitectura resumida

```
App móvil ──► API REST ──► Reportes ──► (evento) ──► Riesgo / IA / Tiempo real
                                                        │
Open-Meteo ──► Tarea programada ──► Meteorología ──► Riesgo
                                                        │
                        Colonia cruza umbral ──► IA redacta alerta
                                                        │
Página web ◄── WebSocket ◄──────────── Alerta propuesta
Página web ──► Aprobar (clave única) ──► Notificación ──► App móvil
```

**Eventos internos:** `report.created`, `report.updated`, `weather.updated`, `zone.risk_updated`, `zone.threshold_crossed`, `alert.drafted`, `alert.approved`.

**Stack propuesto:** FastAPI, PostgreSQL + PostGIS, Alembic, WebSockets, APScheduler, Open-Meteo, Docker Compose, React + MapLibre o Leaflet (web), Expo o Flutter (móvil).

**Índice de riesgo:**

```
riesgo_colonia = w1 · lluvia (1 h, 3 h, 24 h + pronóstico)
               + w2 · densidad de reportes activos (ponderada por severidad y confirmaciones)
               + w3 · vulnerabilidad base
```

Niveles: bajo, medio, alto, crítico. Función pura y con pruebas.

## 6. Plan por fases (24 horas)

Cuatro frentes: **Backend**, **Móvil**, **Web**, **IA y datos**. Con menos personas, una persona cubre dos frentes. Las horas son relativas al inicio del hackathon.

### Fase 0 · Fundaciones (h 0–2)

| Frente | Tareas |
|---|---|
| Todos | Acordar el contrato OpenAPI (con las categorías de fuga y tandeo); definir la clave única |
| Backend | Repositorio, Docker Compose, base de datos y migraciones, `GET /health` |
| IA y datos | **Conseguir polígonos de colonias de Veracruz** (verificar fuente y calidad); definir vulnerabilidad base con fuente real o rotulada como ejemplo; preparar 30–50 reportes de prueba |
| Móvil y Web | Crear proyectos y consumir datos simulados según el contrato |

**Hito:** la API levanta con un comando y los clientes compilan contra el mismo contrato.

### Fase 1 · Reportes de punta a punta (h 2–8)

| Frente | Tareas |
|---|---|
| Backend | Colonias y función "punto → colonia"; `POST/GET /reports` con filtros espaciales; expiración de reportes; WebSocket hacia el panel |
| Móvil | Formulario de reporte en tres pasos; elección de colonia; mapa con reportes activos |
| Web | Mapa con reportes actualizado en vivo |
| IA y datos | Probar prompts de clasificación y de borrador de alerta con ejemplos |

**Hito (el más importante):** un reporte enviado desde el celular aparece en el panel en segundos. **Si no está a la hora 8, todo lo demás espera.**

### Fase 2 · Índice de riesgo (h 8–13)

| Frente | Tareas |
|---|---|
| Backend | Ingesta de Open-Meteo (3–4 puntos de la ciudad); cálculo de riesgo con histéresis y enfriamiento; `GET /zones/risk` (GeoJSON); aviso por WebSocket |
| IA y datos | Calibrar pesos y umbrales con datos de ejemplo; definir el texto del "motivo del riesgo" |
| Móvil y Web | Capa de colonias coloreadas por riesgo; el panel muestra el motivo |
| Web | Formulario de reporte manual |

**Hito:** el mapa muestra colonias coloreadas que cambian con datos nuevos.

### Fase 3 · Alertas, guías y notificaciones (h 13–18)

| Frente | Tareas |
|---|---|
| Backend | Guías por tipo (inundación, encharcamiento, alcantarilla, fuga, tandeo); borrador de alerta con plantilla y LLM; aprobación con clave única; registro de dispositivos y envío por colonia |
| Web | Bandeja de alertas propuestas con edición y aprobación; filtro por categoría |
| Móvil | Registro del dispositivo; recepción de notificación; pantalla de alerta con guía; caché de la última guía |
| IA y datos | Guías basadas en lineamientos oficiales de Protección Civil (no redactadas por el LLM); respaldo por plantillas si el LLM falla |

**Hito:** colonia en riesgo → la IA propone la alerta → Protección Civil aprueba → llega la notificación al celular.

> **Probar el envío de una notificación de prueba antes de la hora 15.** Si falla a la hora 17, la demo pierde su cierre.

### Fase 4 · Simulación e integración (h 18–21)

- Backend: `POST /admin/simulate-storm`, `seed` y `reset`.
- Todos: pruebas de caminos críticos (creación de reportes, cálculo de riesgo, flujo de alerta) y corrección de errores de integración.
- Si hubo tiempo: detección de fugas por agrupación.

**Hito:** la demo completa corre tres veces seguidas sin fallos.

### Fase 5 · Pulido y pitch (h 21–24)

- Congelar código a la hora 22; después solo correcciones críticas.
- Diagrama de arquitectura y documentación OpenAPI navegable.
- Grabar un video de la demo como respaldo.
- Ensayar el pitch al menos dos veces.

## 7. Reserva para el requisito nuevo

El jueves a las 7:00 aparece un requisito adicional en el reto.

- **No asignar el 100 % del tiempo.** Dejar un bloque de 2 a 3 horas sin comprometer después de las 7:00.
- Mantener categorías y guías **como datos**, no como código rígido, para absorber cambios sin migraciones grandes.
- En cuanto aparezca: leerlo en equipo y decidir en **15 minutos** qué se recorta de la sección 4.2 para acomodarlo.
- Actualizar este documento con el requisito y la decisión tomada.

**Requisito recibido:** _pendiente_

## 8. Riesgos y respaldos

| Riesgo | Respaldo |
|---|---|
| Falla Open-Meteo | Riesgo calculado solo con reportes y vulnerabilidad base |
| Open-Meteo tiene poca resolución espacial (la lluvia es casi igual en toda la ciudad) | El contraste entre colonias viene de vulnerabilidad y reportes; consultar varios puntos; decirlo en el pitch |
| Fallan el LLM o su tiempo de respuesta | Clasificación por reglas y alertas con plantillas |
| No se consiguen polígonos de colonias a tiempo | Asignar cada hexágono a la colonia que más lo cubre, o usar zonas aproximadas rotuladas como tales |
| Falla la notificación push | Mostrar la alerta dentro de la app consultando `GET /alerts/active`; probar el envío temprano |
| Falla la red durante la demo | Video grabado de la demo |
| No llueve el día de la presentación | "Simular tormenta" |
| Alguien abre el panel y rompe la demo | Clave única en acciones que modifican |
| Reportes falsos | Confirmaciones de dispositivos distintos, límite de solicitudes, foto opcional |
| Alertas repetidas por oscilación del umbral | Histéresis y enfriamiento por colonia |
| Reportes que nunca expiran y mantienen el riesgo alto | Expiración por tiempo y estado resuelto |
| Integración tardía entre clientes y backend | Contrato OpenAPI desde la hora 0 y despliegue funcionando desde el inicio |

## 9. Criterios de "terminado" del MVP

- [ ] `docker compose up` levanta API y base de datos; OpenAPI accesible
- [ ] Un reporte del celular aparece en el panel sin recargar
- [ ] El reporte queda asociado a su colonia y expira
- [ ] El mapa colorea colonias por riesgo y muestra el motivo
- [ ] Una colonia crítica genera un borrador de alerta (sin repetirse)
- [ ] La aprobación con clave única envía la alerta y llega al celular con su guía
- [ ] "Simular tormenta" desencadena el flujo completo y está rotulada como simulación
- [ ] Las pruebas del cálculo de riesgo y de creación de reportes pasan
- [ ] La demo corre tres veces seguidas sin fallos
- [ ] Video de respaldo grabado

## 10. Guion de demo (aprox. 2 minutos)

1. Mapa en calma con algunos reportes activos.
2. Desde el celular se envía un reporte de inundación; aparece en vivo en el panel.
3. Se activa "Simular tormenta" (rotulada como simulación): sube la lluvia y las colonias cambian de color, con el motivo visible.
4. La IA propone una alerta con su plan de acción; Protección Civil la aprueba.
5. Llega la notificación al celular con la guía de acción rápida.
6. Cierre: el mismo sistema cubre fugas y tandeo con otra categoría, otra guía y el organismo operador como destinatario.

## 11. Evidencia técnica para el jurado

- Diagrama de arquitectura con módulos, eventos y flujo de datos.
- Documentación OpenAPI navegable.
- Migraciones versionadas.
- Pruebas en caminos críticos.
- Explicación de escalabilidad: qué módulo se separa primero (ingesta meteorológica y riesgo) y por qué el bus en memoria exige un solo worker hoy.
- Decisión de diseño "la IA propone, el humano decide".
- Honestidad sobre datos: qué es real, qué es simulado y qué es fórmula frente a IA generativa.

## 12. Roadmap posterior

Roles y autenticación, modo offline, canal alterno (WhatsApp o web ligera), seguimiento de reportes con estados, despacho a cuadrillas y organismos operadores, modelo de riesgo entrenado con histórico, nowcasting con radar, sensores municipales, factor costero (nortes y marea), refugios y rutas, y acuerdo institucional con Protección Civil.
