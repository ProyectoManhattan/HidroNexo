# Base de datos real y despliegue

## Decisión recomendada

Usar **Supabase para PostgreSQL/PostGIS y Storage**, y **Railway para FastAPI**.
Flutter no debe escribir directamente en las tablas: debe consumir `POST /reports`
y `POST /devices`, porque el backend asigna la colonia, fija caducidad, publica eventos
y recalcula el riesgo.

Supabase encaja mejor como base geoespacial porque ofrece PostGIS como extensión,
además de Storage para las fotografías. Railway encaja bien para ejecutar el contenedor
FastAPI. Una base PostgreSQL estándar de Railway no trae PostGIS; habría que usar una
imagen o plantilla PostGIS y esa personalización queda fuera del soporte administrado
normal de su plantilla.

## Opciones

### A. Supabase DB + Storage, Railway API — recomendada

- PostGIS soportado por Supabase.
- Storage resuelve `foto_url`: Flutter sube la imagen y manda su URL al API.
- Plan gratuito útil para prototipo: 500 MB de base, 1 GB de archivos y 5 GB de egress;
  el proyecto puede pausarse tras una semana de inactividad.
- Pro parte de USD 25/mes e incluye 8 GB de disco y respaldos diarios conservados 7 días.
- FastAPI sigue siendo la única puerta de escritura para conservar toda la lógica actual.

Documentación oficial: [precios de Supabase](https://supabase.com/pricing),
[PostGIS en Supabase](https://supabase.com/docs/guides/database/extensions) y
[conexiones a Postgres](https://supabase.com/docs/guides/database/connecting-to-postgres).

### B. Todo en Railway

- Un servicio FastAPI y otro servicio basado en `postgis/postgis` dentro del mismo proyecto.
- Red privada entre API y base, despliegue sencillo y cobro por uso.
- Hobby tiene un compromiso mínimo de USD 5/mes que se aplica al consumo.
- Hay respaldos manuales y programados, pero hay que activarlos.
- La plantilla PostgreSQL oficial no instala extensiones como PostGIS; Railway remite a
  plantillas especializadas. Cambiar la imagen hace que la base sea más responsabilidad
  del equipo.

Documentación oficial: [PostgreSQL en Railway](https://docs.railway.com/databases/postgresql),
[bases administradas](https://docs.railway.com/databases),
[respaldos](https://docs.railway.com/volumes/backups) y
[facturación](https://docs.railway.com/pricing/understanding-your-bill).

### C. Solo Supabase, sin FastAPI — no recomendada ahora

Exigiría reescribir en funciones, triggers o Edge Functions la asignación espacial,
caducidad, cálculo de riesgo, alertas y WebSocket. También cambiaría el contrato que ya
consumen el panel y que consumirá Flutter.

## Tablas exigidas por `docs/api.md`

| Tabla | Campos persistidos |
|---|---|
| `colonias` | `id`, `nombre`, `municipio`, `geom MultiPolygon(4326)`, `vulnerabilidad`, `vulnerabilidad_fuente` |
| `reportes` | `id`, `categoria`, `severidad`, `lat`, `lon`, `ubicacion Point(4326)`, `descripcion`, `foto_url`, `dispositivo_id`, `colonia_id`, `origen`, `estado`, `creado_en`, `expira_en` |
| `dispositivos` | `id`, `token`, `colonia_id`, `plataforma`, `actualizado_en` |
| `alertas` | `id`, `colonia_id`, `tipo`, `nivel`, `motivo`, `texto`, `estado`, `redactada_por`, `simulada`, `creada_en`, `aprobada_en` |
| `riesgo_colonias` | `colonia_id`, `valor`, `nivel`, `motivo`, `componentes JSON`, `actualizado_en`, `ultima_alerta_en` |

`prioridad`, `pronostico` y `guia` son valores calculados o adjuntos de respuesta; no
necesitan columnas nuevas. Las alertas oficiales consultadas a México Preparado se
mantienen como caché temporal y tampoco necesitan persistirse todavía.

La migración `0002` agrega restricciones para categorías, severidad, coordenadas,
estados, plataformas y longitudes, hace obligatorias las geometrías y limpia los datos
sintéticos conocidos sin borrar las colonias.

## Flujo de carga desde Flutter

1. `GET /reports/categories` carga las opciones del formulario.
2. `GET /zones` permite seleccionar la colonia para notificaciones.
3. `POST /devices` registra el token FCM y la colonia.
4. Si hay foto, Flutter la sube a Storage y obtiene `foto_url`.
5. `POST /reports` envía categoría, severidad, GPS, descripción, URL e identificador del dispositivo.
6. FastAPI asigna `colonia_id`, crea la geometría, fija seis horas de vigencia y actualiza el riesgo.

## Variables para producción

```env
DATABASE_URL=postgresql+psycopg://USUARIO:CLAVE@HOST:5432/postgres?sslmode=require
CLAVE_UNICA=una-clave-larga-y-aleatoria
DATA_DIR=/data
AUTO_LOAD_REFERENCE_DATA=true
AUTO_SEED=false
SUPABASE_URL=https://PROYECTO.supabase.co
SUPABASE_SERVICE_KEY=la-service-role-key
SUPABASE_BUCKET=reportes-fotos
METEO_ACTIVA=true
AVISOS_OFICIALES_ACTIVOS=true
```

Hay dos rutas excluyentes para preparar Supabase:

- `supabase/bootstrap.sql` habilita PostGIS y Alembic crea después las tablas.
- `supabase/deploy.sql` crea PostGIS y todo el esquema desde el SQL Editor; también marca
  la versión Alembic `0002`, por lo que el backend no intentará recrearlo.

No se deben ejecutar ambas rutas sobre el mismo proyecto. Railway usa el
`Dockerfile` de la raíz, seleccionado explícitamente por `railway.json`.

## Fotos de reportes (Supabase Storage)

`POST /reports/photo` sube las fotos a Supabase Storage. Sin `SUPABASE_URL` y
`SUPABASE_SERVICE_KEY` el backend guarda en disco local (`MEDIA_DIR`, servido en `/media`):
solo sirve para desarrollo, porque el disco de Railway es efímero y las fotos se perderían.

1. En Supabase: Storage > New bucket, nombre `reportes-fotos`, marcar **Public bucket**.
2. Opcional: limitar el bucket a 5 MB y a los tipos `image/jpeg`, `image/png`, `image/webp`.
3. En Railway, añadir `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` (Settings > API > `service_role`)
   y `SUPABASE_BUCKET` (`reportes-fotos` por defecto).
4. El backend solo acepta en `foto_url` URLs que empiecen por
   `SUPABASE_URL/storage/v1/object/public/<bucket>/`.

**La service key va únicamente en Railway.** Nunca en la app móvil, en Vercel/web ni en el
repositorio: salta todas las políticas de acceso. El backend no la registra ni la devuelve.

Riesgo conocido: `POST /reports/photo` es público y no tiene límite de frecuencia ni
moderación de contenido; cualquiera puede subir imágenes (hasta 5 MB cada una) al bucket.

## Pendientes antes de abrirlo al público

- Implementar el formulario Flutter; actualmente `movil/` sigue siendo la plantilla inicial.
- Añadir autenticación o App Check, rate limiting y deduplicación para evitar spam.
- Configurar FCM real y no almacenar el token push en registros ni logs públicos.
- Usar un bucket privado o URLs firmadas para fotos; eliminar metadatos EXIF si no son necesarios.
- Restringir CORS y rotar `CLAVE_UNICA`; la clave administrativa nunca debe incluirse en Flutter.
- Activar respaldos y hacer una prueba real de restauración.
