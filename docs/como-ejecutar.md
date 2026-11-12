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

Las zonas reales ya están en `data/colonias_veracruz.geojson` (por código postal; ver el README principal). Si todavía no hay reportes de prueba ni guías en `data/`, copiar los **ficticios** de las pruebas. **No subirlos con commit.** Ojo: no copiar el `.geojson` de pruebas, porque pisaría las zonas reales.

```bash
# Mac / Linux
cp backend/tests/datos/reportes_prueba.json data/ && cp backend/tests/datos/guias/*.json data/guias/
```

```bash
# Windows
copy backend\tests\datos\reportes_prueba.json data\ && copy backend\tests\datos\guias\*.json data\guias\
```

## 4. Panel web (terminal 2)

```bash
cd web-react
npm install
npm run dev
```

## 5. Usarlo

1. Abrir http://localhost:5173
2. **Modo operador** → clave `cambiar-esta-clave` (la de `CLAVE_UNICA` en `.env`).
3. **⚙ → Cargar datos (seed)**.
4. **Simular tormenta** → aparecen alertas propuestas; **Aprobar y enviar**.

## Problemas comunes

| Síntoma | Solución |
|---|---|
| El panel dice "Sin conexión" | El backend no está corriendo; revisar la terminal 1 |
| `port is already allocated` (5432 u 8000) | Otro programa usa el puerto: cerrar otro PostgreSQL local o cambiar el puerto en `docker-compose.yml` |
| "Clave incorrecta" | Usar el valor de `CLAVE_UNICA` del archivo `.env` |
| El mapa no muestra zonas | Falta el seed (⚙ → Cargar datos) o `data/colonias_veracruz.geojson` |
| Cambié `.env` y no se aplica | `docker compose down` y luego `docker compose up --build` |

Pruebas del backend:

```bash
docker compose exec api pytest
```
