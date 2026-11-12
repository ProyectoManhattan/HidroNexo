# Cómo ejecutar el proyecto

Backend (API + base de datos) en Docker y panel web en React.

**Requisitos:** Git, Docker Desktop (abierto) y Node.js 22 (`mise install` lo instala).

## 1. Bajar el proyecto

No hace falta crear carpetas: `git clone` crea `Proyecto_Agua_Lluvia/` donde estés.

```bash
git clone https://github.com/ProyectoManhattan/Proyecto_Agua_Lluvia.git
cd Proyecto_Agua_Lluvia
```

Si ya lo tenías clonado:

```bash
git pull origin main
```

## 2. Backend (terminal 1)

Crear el archivo de configuración (solo la primera vez):

```bash
cp .env.example .env        # Mac / Linux
copy .env.example .env      # Windows
```

Levantar base de datos y API:

```bash
docker compose up --build
```

Dejar esta terminal abierta. Comprobar: http://localhost:8000/health debe responder `{"status":"ok"}`. La documentación interactiva está en http://localhost:8000/docs.

## 3. Datos

Las zonas reales (101, de Veracruz, Boca del Río y Medellín de Bravo) ya están en `data/colonias_veracruz.geojson` (por código postal; ver el README principal). **No hay que cargar nada a mano**: con la base vacía, la API las carga sola al arrancar y crea un reporte de ejemplo por zona.

Las guías de acción (`data/guias/`) todavía no existen. Mientras tanto se pueden copiar las **ficticias** de las pruebas (**no subirlas con commit**):

```bash
# Mac / Linux
cp backend/tests/datos/guias/*.json data/guias/
```

```bash
# Windows
copy backend\tests\datos\guias\*.json data\guias\
```

## 4. Panel web (terminal 2)

```bash
cd web-react
npm install
npm run dev
```

## 5. Usarlo

1. Abrir http://localhost:5173
2. Al inicio no hay reportes: aparecen los que envía la app móvil o se crean desde la API. El panel no pide clave.
3. **Simular tormenta** → aparecen alertas propuestas; **Aprobar y enviar**.
4. **Enviar alerta manual** → elegir zonas, tipo, nivel y texto.
5. **⚙ → Cargar datos (seed)** reinicia todo; **Reiniciar (reset)** conserva las zonas y borra reportes y alertas.

## Problemas comunes

| Síntoma | Solución |
|---|---|
| El panel dice "Sin conexión" | El backend no está corriendo; revisar la terminal 1 |
| `port is already allocated` (5432 u 8000) | Otro programa usa el puerto: cerrar otro PostgreSQL local o cambiar el puerto en `docker-compose.yml` |
| Las acciones fallan con "Clave inválida" | `VITE_CLAVE` (en `web-react/.env`) debe coincidir con `CLAVE_UNICA` de `.env`; reiniciar `npm run dev` |
| Sigo viendo solo las zonas anteriores | La base ya tenía colonias y la carga automática solo corre con la base vacía. Usa **⚙ → Cargar datos (seed)** (borra reportes, alertas y dispositivos) o `docker compose down -v` |
| El mapa no muestra zonas | Falta `data/colonias_veracruz.geojson`, o la base se creó sin él: `docker compose down -v` y levantar de nuevo |
| Cambié `.env` y no se aplica | `docker compose down` y luego `docker compose up --build` |

Pruebas del backend:

```bash
docker compose exec api pytest
```
