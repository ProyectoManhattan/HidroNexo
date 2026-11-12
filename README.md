# AguaVer | Bitácora de uso de inteligencia artificial
**Instituto Tecnológico de Veracruz** · Hackathon Tech Week 2026 · Reto: **Agua y lluvia**
**Equipo:** Proyecto Manhattan  
**Repositorio:** [ProyectoManhattan/Proyecto_Agua_Lluvia](https://github.com/ProyectoManhattan/Proyecto_Agua_Lluvia)

## Integrantes
- Contreras Cornelio Melanie Isela
- García Suárez Rodrigo
- González Cruz Fernando Said
- Landero Arias Daniel
- Urdapilleta Prospero Dante

---

## 1. Introducción
AguaVer es la plataforma que se desarrolló como Proyecto Manhattan en el Hackathon Tech Week 2026, para el reto Agua y lluvia. El trabajo comenzó el 11 de noviembre de 2026, alrededor de las 2:00 p. m. En esta bitácora se anotan las herramientas de IA que se usaron, los prompts empleados y lo que se hizo con las respuestas obtenidas.
Dentro del proyecto, la IA no corre todavía. El riesgo por zona se calcula con una fórmula y las alertas salen de plantillas. La redacción de alertas con un modelo de lenguaje quedó diseñada, pero sin activar.

## 2. Herramientas utilizadas
Se usaron cuatro herramientas. Claude fue la más utilizada, seguida de ChatGPT. Gemini se usó pocas veces y Antigravity fue el entorno de programación con agentes, por lo que no tiene prompt propio. En todas se usó el modelo más avanzado del plan disponible.
| Herramienta | Proveedor | Uso | Tareas principales |
| --- | --- | --- | --- |
| Claude | Anthropic | Principal | Código y diseño del backend, fórmula de riesgo, ingesta meteorológica, perfiles territoriales, pruebas, panel web, app móvil y esta bitácora. |
| ChatGPT | OpenAI | Secundario | Plan de trabajo y reparto, prompt y plantillas de alerta, depuración en Flutter. |
| Gemini | Google | Ocasional | Búsqueda de fuentes abiertas de datos de lluvia y ríos. |
| Antigravity | Google | Complementario | Editor con agentes para escribir y editar código. |

## 3. Prompts utilizados
> **Nota:** Los prompts están resumidos a partir de las consultas realizadas y del trabajo que quedó en el repositorio; no son transcripciones literales.
### Índice de prompts
| ID | Herramienta | Finalidad | Artefacto |
| --- | --- | --- | --- |
| P-01 | ChatGPT | Ordenar alcance, fases y reparto | docs/plan-de-trabajo.md, docs/reparto.md |
| P-02 | Gemini | Identificar fuentes y sus límites | data/perfiles/calidad_datos.md |
| P-03 | Claude | Perfiles territoriales y vulnerabilidad base | data/scripts/perfiles_territoriales/, data/perfiles/ |
| P-04 | Claude | Reportes y clasificación por reglas | backend/app/reportes/, backend/app/ia/clasificador.py |
| P-05 | Claude | Panel web | web-react/src/components/ |
| P-06 | Claude | Aplicación móvil | movil/lib/ |
| P-07 | ChatGPT | Depuración de notificaciones | movil/lib/services/push_service.dart |
| P-08 | Claude | Índice de riesgo | backend/app/riesgo/calculo.py |
| P-09 | Claude | Ingesta meteorológica | backend/app/meteorologia/ingesta.py |
| P-10 | ChatGPT | Prompt y plantillas de alerta | backend/app/ia/prompts/, plantillas/ |
| P-11 | Claude | Pruebas automatizadas | backend/tests/ |

### Detalle de los prompts
<details>
<summary><strong>P-01 · ChatGPT — Ordenar alcance, fases y reparto</strong></summary>
**Finalidad:** Ordenar alcance, fases y reparto  
**Artefacto:** `docs/plan-de-trabajo.md, docs/reparto.md`
**Prompt utilizado:**
> Somos tres personas en un hackathon de 24 horas con el reto de agua y lluvia en Veracruz: colonias que se inundan y colonias con fugas o tandeo. Queremos una app móvil para reportes ciudadanos, un panel web para Protección Civil y un backend que calcule riesgo por colonia con lluvia, reportes y vulnerabilidad. Arma un plan por fases de 0 a 24 horas con hitos, qué entra al MVP y qué queda como extra, los riesgos principales con su respaldo y un reparto por persona para no pisarnos en el repositorio. Preferimos decisiones simples: sin cuentas de usuario y sin modelos entrenados, porque no tenemos datos históricos.
</details>
<details>
<summary><strong>P-02 · Gemini — Identificar fuentes y sus límites</strong></summary>
**Finalidad:** Identificar fuentes y sus límites  
**Artefacto:** `data/perfiles/calidad_datos.md`
**Prompt utilizado:**
> Necesito identificar fuentes abiertas de datos de lluvia, ríos y zonas inundables para Veracruz, Boca del Río y Medellín de Bravo: CONAGUA (Sistema de Información Hidrológica), SMN, INEGI y atlas de riesgos. Para cada una dime qué datos tiene, en qué formato se descarga, qué cobertura temporal tiene y qué limitaciones debo documentar. Si algo no lo puedes confirmar, dilo.
</details>
<details>
<summary><strong>P-03 · Claude — Perfiles territoriales y vulnerabilidad base</strong></summary>
**Finalidad:** Perfiles territoriales y vulnerabilidad base  
**Artefacto:** `data/scripts/perfiles_territoriales/, data/perfiles/`
**Prompt utilizado:**
> Tengo 101 polígonos de código postal de Veracruz, Boca del Río y Medellín de Bravo en GeoJSON, el modelo digital de elevación Copernicus GLO-30 y el catálogo de estaciones de CONAGUA. Escribe un script en Python que calcule por polígono la elevación, la elevación relativa a su entorno, la pendiente, la distancia al mar y a cauces modelados (hidrología D8 y HAND), y que guarde todo en JSON y CSV sin modificar los polígonos originales. Documenta la metodología, las fuentes y los problemas de calidad de datos. Si un dato no existe, déjalo en null y no lo estimes.
</details>
<details>
<summary><strong>P-04 · Claude — Reportes y clasificación por reglas</strong></summary>
**Finalidad:** Reportes y clasificación por reglas  
**Artefacto:** `backend/app/reportes/, backend/app/ia/clasificador.py`
**Prompt utilizado:**
> En el backend FastAPI quiero un módulo de reportes con las categorías inundación, encharcamiento, alcantarilla tapada, fuga y sin agua. Cada reporte debe asignarse a la zona que contiene su punto, llevar una severidad y expirar a las 6 horas. Agrega una función que sugiera la categoría a partir del texto libre con palabras clave del español de Veracruz, que devuelva None si no reconoce nada y que sirva de respaldo cuando conectemos un LLM.
</details>
<details>
<summary><strong>P-05 · Claude — Panel web</strong></summary>
**Finalidad:** Panel web  
**Artefacto:** `web-react/src/components/`
**Prompt utilizado:**
> Con React, TypeScript y MapLibre arma el panel para Protección Civil: mapa con las zonas coloreadas por riesgo y el motivo del riesgo, lista de reportes que se actualice por WebSocket, bandeja de alertas propuestas donde la persona operadora pueda editar, aprobar o descartar, y un diálogo para enviar una alerta manual a una o varias zonas. Cada alerta debe mostrar si la redactó una plantilla, la IA o una persona. El botón de simular tormenta debe indicar claramente que es una simulación.
</details>
<details>
<summary><strong>P-06 · Claude — Aplicación móvil</strong></summary>
**Finalidad:** Aplicación móvil  
**Artefacto:** `movil/lib/`
**Prompt utilizado:**
> En Flutter, solo para Android, construye la app ciudadana AguaVer: formulario de reporte en tres pasos (tipo, ubicación con pin ajustable y severidad), mapa MapLibre con el riesgo por zona que entrega /zones/risk, pantalla de alertas aprobadas y un aviso visible de que no sustituye al 911. Debe consumir la API del backend y tener un repositorio de datos de ejemplo para trabajar sin servidor (USE_MOCK). Separa controladores, modelos, servicios y widgets.
</details>
<details>
<summary><strong>P-07 · ChatGPT — Depuración de notificaciones</strong></summary>
**Finalidad:** Depuración de notificaciones  
**Artefacto:** `movil/lib/services/push_service.dart`
**Prompt utilizado:**
> Mi app Flutter no recibe las notificaciones push de Firebase Messaging cuando está en segundo plano en Android, y al tocar la notificación no abre la pantalla de alertas. Te pego el servicio y el manifiesto. Dime las causas más probables en orden y qué cambiarías en el código.
</details>
<details>
<summary><strong>P-08 · Claude — Índice de riesgo</strong></summary>
**Finalidad:** Índice de riesgo  
**Artefacto:** `backend/app/riesgo/calculo.py`
**Prompt utilizado:**
> Diseña una fórmula de riesgo por zona que sea explicable: riesgo = w1·lluvia + w2·reportes + w3·vulnerabilidad, con cada componente entre 0 y 1. Lluvia: acumulados de 1 h, 3 h y 24 h y pronóstico a 3 h ponderado por su probabilidad. Reportes: suma de severidades con saturación. Niveles bajo, medio, alto y crítico, con histéresis para que no oscile, y alerta solo en alto y crítico. Impleméntala como funciones puras en Python, sin base de datos, para poder probarlas. Deja marcados como pendientes los pesos y umbrales que haya que calibrar.
</details>
<details>
<summary><strong>P-09 · Claude — Ingesta meteorológica</strong></summary>
**Finalidad:** Ingesta meteorológica  
**Artefacto:** `backend/app/meteorologia/ingesta.py`
**Prompt utilizado:**
> Escribe la ingesta de Open-Meteo para FastAPI: cada 15 minutos consulta por lotes las coordenadas de las zonas y resume la lluvia de la última 1 h, 3 h y 24 h, el pronóstico de las próximas 3 h y la probabilidad máxima a 3 y 6 h. Si falla la red no debe caerse y debe conservar el último dato. Usa httpx y APScheduler.
</details>
<details>
<summary><strong>P-10 · ChatGPT — Prompt y plantillas de alerta</strong></summary>
**Finalidad:** Prompt y plantillas de alerta  
**Artefacto:** `backend/app/ia/prompts/, plantillas/`
**Prompt utilizado:**
> Redacta un prompt para que un modelo escriba avisos breves de Protección Civil para una colonia: máximo 280 caracteres, tono claro y sin alarmismo, sin inventar instrucciones de seguridad porque la guía de acción se adjunta aparte, y que cierre recordando llamar al 911. Escribe también dos plantillas de respaldo con los campos {colonia}, {nivel} y {motivo}, una para inundación y otra general, para usarlas cuando el modelo no esté disponible.
</details>
<details>
<summary><strong>P-11 · Claude — Pruebas automatizadas</strong></summary>
**Finalidad:** Pruebas automatizadas  
**Artefacto:** `backend/tests/`
**Prompt utilizado:**
> Escribe pruebas con pytest para el backend: la fórmula de riesgo (umbrales, histéresis, amplificación por lluvia, ponderación por probabilidad), el flujo completo de reporte, riesgo, alerta propuesta y aprobación, el enfriamiento de alertas, el registro de dispositivos por zona y el envío push con FCM simulado. Las pruebas de flujo deben usar una base de datos aparte y nunca la principal.
</details>

## 4. Resultados obtenidos
| Resultado | Artefacto en el repositorio | Herramienta | Verificación |
| --- | --- | --- | --- |
| Estructura del plan de trabajo y reparto | docs/plan-de-trabajo.md, docs/reparto.md | ChatGPT | Revisión conjunta del equipo |
| Lista de fuentes abiertas de datos | data/perfiles/calidad_datos.md | Gemini | Verificación en el sitio de cada fuente |
| Scripts y metodología de perfiles territoriales | data/scripts/, data/perfiles/ | Claude | Documento de calidad de datos |
| Módulo de reportes y clasificador por reglas | backend/app/reportes/, ia/clasificador.py | Claude | Pruebas de flujo y unitarias |
| Interfaz web | web-react/src/ | Claude | Prueba manual, npm run build, oxlint |
| Aplicación móvil | movil/lib/ | Claude, ChatGPT | movil/test/ y prueba en Android |
| Fórmula de riesgo | backend/app/riesgo/calculo.py | Claude | 27 pruebas (riesgo, probabilidad, prioridad) |
| Ingesta meteorológica | backend/app/meteorologia/ | Claude | test_meteo_colonia.py |
| Prompt y plantillas de alerta | backend/app/ia/ | ChatGPT | Aprobación humana de cada alerta |
| Pruebas del backend | backend/tests/ | Claude | pytest en contenedor |

## 5. Validación humana
Todo lo que salió de una IA pasó por el repositorio compartido. Se trabajó con una rama por frente (backend, web y móvil) y con pull requests revisados por quien es responsable de cada carpeta. El backend y la app móvil tienen pruebas automatizadas; el panel web se revisó a mano, con `npm run build` y `oxlint`. Los datos de ejemplo de las pruebas son ficticios.
En el producto, ninguna alerta se envía sin que una persona operadora de Protección Civil la apruebe, la edite o la descarte, y cada alerta indica si la escribió una plantilla, la IA o una persona.

## 6. Limitaciones
Los prompts de la sección 3 son reconstruidos, no copias exactas. Los pesos y umbrales de la fórmula de riesgo se diseñaron con ayuda de IA y siguen sin calibrar con datos históricos.

## 7. Conclusiones
La IA se usó como apoyo en la planeación, el código, el procesamiento de datos y las pruebas, principalmente con Claude y, en menor medida, con ChatGPT, Gemini y Antigravity. Las decisiones de diseño y lo que llega a la población siguieron a cargo del equipo: el riesgo se calcula con una fórmula explicable, las alertas se redactan con plantillas y cada una debe ser aprobada por una persona de Protección Civil. La redacción de alertas con un modelo de lenguaje quedó diseñada y pendiente de implementar.
