# API · Agua y Lluvia

Contrato entre el backend, el panel web y la app Flutter. El código está en `backend/`; la documentación interactiva está en `http://localhost:8000/docs` con la API corriendo.

**Reglas generales**
- Base: `http://localhost:8000`.
- Fechas en ISO 8601 y en UTC, por ejemplo `"2026-11-11T22:15:00Z"`.
- 🔒 = requiere el header `X-Clave: <clave única>`. Sin ella responde `401 {"detail": "Clave inválida"}`.

**Quién usa qué**

| Cliente | Endpoints |
|---|---|
| App Flutter | `GET /reports/categories`, `GET /zones`, `POST /reports`, `GET /reports`, `GET /zones/risk`, `POST /devices`, `GET /alerts/active`, `GET /guides` |
| Panel web | Todos los demás, más `WS /ws` |

---

## 1. Reportes

### `GET /reports/categories`

Opciones válidas para el formulario.

```json
{
  "categorias": {
    "inundacion": "Inundación",
    "encharcamiento": "Encharcamiento",
    "alcantarilla": "Alcantarilla tapada",
    "fuga": "Fuga de agua",
    "sin_agua": "Sin agua / tandeo"
  },
  "severidades": { "1": "Baja", "2": "Media", "3": "Alta" }
}
```

### `POST /reports`

Crear un reporte desde la app.

```json
{
  "categoria": "inundacion",
  "severidad": 3,
  "lat": 19.1745,
  "lon": -96.1342,
  "descripcion": "El agua ya entró a las casas",
  "foto_url": null,
  "dispositivo_id": "abc123"
}
```

| Campo | Obligatorio | Regla |
|---|---|---|
| `categoria` | Sí | Una de las 5 categorías |
| `severidad` | Sí | 1, 2 o 3 |
| `lat`, `lon` | Sí | Coordenadas del pin |
| `descripcion` | No | Máximo 500 caracteres |
| `foto_url` | No | Texto con la URL de la foto |
| `dispositivo_id` | No | Texto |

Respuesta `201`. Es el mismo objeto que devuelven todos los endpoints de reportes:

```json
{
  "id": 15,
  "categoria": "inundacion",
  "severidad": 3,
  "lat": 19.1745,
  "lon": -96.1342,
  "descripcion": "El agua ya entró a las casas",
  "foto_url": null,
  "colonia_id": 4,
  "origen": "app",
  "estado": "activo",
  "creado_en": "2026-11-11T22:15:00Z",
  "expira_en": "2026-11-12T04:15:00Z"
}
```

- `colonia_id` lo asigna el sistema; es `null` si el punto cae fuera de todas las colonias.
- `origen`: `app`, `panel` o `seed`.
- `estado`: `activo` o `resuelto`. El reporte expira a las 6 horas.

### `POST /reports/manual` 🔒

Reporte desde el panel. Mismo cuerpo y respuesta que `POST /reports`, con `"origen": "panel"`.

### `GET /reports`

Listar reportes. Parámetros opcionales en la URL:

| Parámetro | Ejemplo | Qué hace |
|---|---|---|
| `categoria` | `fuga` | Solo esa categoría |
| `colonia_id` | `4` | Solo esa colonia |
| `activos` | `true` | Por defecto `true`; con `false` incluye resueltos y expirados |
| `bbox` | `-96.14,19.17,-96.13,19.18` | Solo lo que cae en el rectángulo: lon mín, lat mín, lon máx, lat máx |

Respuesta: lista de reportes.

### `POST /reports/{id}/resolve` 🔒

Sin cuerpo. Devuelve el reporte con `"estado": "resuelto"`.

---

## 2. Colonias y riesgo

### `GET /zones`

Lista de colonias para que la app deje elegir una.

```json
[
  {
    "id": 4,
    "nombre": "Formando Hogar",
    "municipio": "Veracruz",
    "vulnerabilidad": 0.6,
    "vulnerabilidad_fuente": "ejemplo"
  }
]
```

### `GET /zones/risk`

Mapa de riesgo en GeoJSON.

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "id": 4,
      "geometry": { "type": "MultiPolygon", "coordinates": [[[[-96.14, 19.17], [-96.13, 19.17], [-96.13, 19.18], [-96.14, 19.17]]]] },
      "properties": {
        "id": 4,
        "nombre": "Formando Hogar",
        "municipio": "Veracruz",
        "vulnerabilidad": 0.6,
        "riesgo": 0.62,
        "nivel": "alto",
        "motivo": "lluvia",
        "componentes": { "lluvia": 1.0, "reportes": 0.45, "vulnerabilidad": 0.6 },
        "actualizado_en": "2026-11-11T22:15:00Z"
      }
    }
  ]
}
```

- `nivel`: `bajo`, `medio`, `alto` o `critico`.
- `motivo`: `lluvia`, `reportes` o `vulnerabilidad`.
- `componentes`: valores de 0 a 1 para las barras del "¿Por qué?".

---

## 3. Alertas

Objeto de alerta que devuelven todos los endpoints de esta sección:

```json
{
  "id": 7,
  "colonia_id": 4,
  "tipo": "inundacion",
  "nivel": "alto",
  "motivo": "lluvia",
  "texto": "Aviso para la colonia Formando Hogar: riesgo alto de inundación…",
  "estado": "propuesta",
  "redactada_por": "plantilla",
  "simulada": true,
  "creada_en": "2026-11-11T22:15:00Z",
  "aprobada_en": null
}
```

- `estado`: `propuesta`, `aprobada` o `descartada`.
- `redactada_por`: `plantilla` o `llm`.
- `simulada`: `true` si se generó durante "Simular tormenta".

### `GET /alerts`

Bandeja del panel. Por defecto trae solo las propuestas (`?estado=propuesta`). Con `?estado=aprobada` o `?estado=descartada` filtra por esos estados; con `?estado=` vacío trae todas.

### `GET /alerts/active?colonia_id=4`

Alertas aprobadas en las últimas 12 horas, con su guía. Es el respaldo de la app si falla el push.

```json
[
  {
    "id": 7,
    "colonia_id": 4,
    "tipo": "inundacion",
    "nivel": "alto",
    "motivo": "lluvia",
    "texto": "…",
    "estado": "aprobada",
    "redactada_por": "plantilla",
    "simulada": true,
    "creada_en": "2026-11-11T22:15:00Z",
    "aprobada_en": "2026-11-11T22:17:00Z",
    "guia": { "titulo": "Qué hacer ante una inundación", "pasos": ["…", "…"] }
  }
]
```

### `PATCH /alerts/{id}` 🔒

Editar el texto. Solo si la alerta está `propuesta`; si no, responde `409`.

```json
{ "texto": "Texto revisado por Protección Civil…" }
```

El texto debe tener entre 10 y 1000 caracteres.

### `POST /alerts` 🔒

Alerta **manual** de Protección Civil para una o varias colonias. No pasa por la bandeja: se aprueba y se envía de inmediato (una alerta por colonia). Responde `201` con la lista creada, con `"redactada_por": "manual"` y `"motivo": "manual"`.

```json
{
  "colonia_ids": [4, 7],
  "tipo": "inundacion",
  "nivel": "alto",
  "texto": "Evita la avenida principal; hay encharcamiento severo."
}
```

- `tipo`: una categoría de `GET /reports/categories` (define la guía que se adjunta).
- `nivel`: `medio`, `alto` o `critico`.
- `texto`: entre 10 y 1000 caracteres. `colonia_ids` no puede ir vacío; si alguna colonia no existe, responde `404`.

### `POST /alerts/{id}/approve` 🔒

Sin cuerpo. Aprueba la alerta, envía el push a los dispositivos de la colonia y la devuelve con `"estado": "aprobada"`.

### `POST /alerts/{id}/discard` 🔒

Sin cuerpo. Devuelve la alerta con `"estado": "descartada"`.

---

## 4. Guías

### `GET /guides`

Todas las guías; la app las guarda para consultarlas sin conexión.

```json
{
  "inundacion": { "titulo": "…", "pasos": ["…"] },
  "fuga": { "titulo": "…", "pasos": ["…"] }
}
```

### `GET /guides/{tipo}`

Una guía. Responde `404` si no existe.

> **Formato por acordar.** `{ "titulo", "pasos" }` es una propuesta. El backend devuelve tal cual el contenido de `data/guias/<tipo>.json`, así que se pueden agregar campos como `"telefonos"` o `"fuente"`.

---

## 5. Dispositivos (app Flutter)

### `POST /devices`

Registrar el celular y su colonia. Si el token ya existía, solo actualiza la colonia.

```json
{
  "token": "token-de-firebase-del-celular",
  "colonia_id": 4,
  "plataforma": "android"
}
```

- `token`: entre 10 y 500 caracteres.
- `plataforma`: `android`, `ios` o `web`.

Respuesta:

```json
{ "id": 12, "colonia_id": 4, "plataforma": "android" }
```

---

## 6. Admin y demo 🔒

| Método y ruta | Cuerpo | Respuesta |
|---|---|---|
| `POST /admin/seed` | — | `{"colonias": 11, "reportes": 40}`. Borra todo y carga lo que haya en `data/` |
| `POST /admin/reset` | — | `{"ok": true}`. Borra reportes, alertas y riesgo; conserva colonias |
| `POST /admin/simulate-storm` | `{"intensidad": 1.0}` (0 a 2; 1.0 = lluvia fuerte) | Estado del clima |
| `DELETE /admin/simulate-storm` | — | Estado del clima |
| `GET /admin/weather` | — | Estado del clima |

Estado del clima:

```json
{
  "lluvia": { "mm_1h": 20.0, "mm_3h": 40.0, "mm_24h": 80.0, "pronostico_3h": 40.0 },
  "simulacion": true,
  "actualizado_en": "2026-11-11T22:00:00Z"
}
```

---

## 7. Tiempo real (panel web)

### `WS /ws`

El panel se conecta y recibe mensajes con esta forma:

```json
{ "tipo": "report.created", "datos": { } }
```

| `tipo` | Qué trae `datos` |
|---|---|
| `report.created`, `report.updated` | Un reporte |
| `zone.risk_updated` | `{colonia_id, nombre, valor, nivel, motivo, componentes}` |
| `alert.drafted` | Una alerta propuesta |
| `alert.approved` | La alerta, más `dispositivos_notificados` |
| `weather.updated` | El estado del clima |

---

## Errores

| Código | Cuándo | Forma |
|---|---|---|
| 401 | Falta la clave o es incorrecta | `{"detail": "Clave inválida"}` |
| 404 | No existe el recurso | `{"detail": "Alerta no encontrada"}` |
| 409 | Aprobar o editar una alerta que ya no está propuesta | `{"detail": "La alerta ya está aprobada"}` |
| 422 | Datos inválidos | `{"detail": [{"loc": ["body", "severidad"], "msg": "…"}]}` |

---

Si cambian un endpoint en `backend/`, actualicen también este archivo en el mismo commit.
