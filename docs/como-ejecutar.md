# Cómo ejecutar el proyecto

Backend (API + base de datos) en Docker y panel web en Python.

**Requisitos:** Git, Docker Desktop (abierto) y Python 3.10 o más nuevo.

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

## 3. Datos de prueba (mientras `data/` esté vacía)

Copiar los datos **ficticios** de las pruebas (2 colonias). **No subirlos con commit**: los datos reales los prepara quien tiene `data/`.

```bash
# Mac / Linux
cp backend/tests/datos/*.geojson backend/tests/datos/*.json data/ && cp backend/tests/datos/guias/*.json data/guias/
```

```bash
# Windows
copy backend\tests\datos\*.geojson data\ && copy backend\tests\datos\*.json data\ && copy backend\tests\datos\guias\*.json data\guias\
```

## 4. Panel web (terminal 2)

```bash
cd web
python -m venv .venv
source .venv/bin/activate      # Mac / Linux
.venv\Scripts\activate         # Windows
pip install -r requirements.txt
python main.py
```

## 5. Usarlo

1. Abrir http://localhost:8080
2. **Modo operador** → clave `cambiar-esta-clave` (la de `CLAVE_UNICA` en `.env`).
3. **⚙ → Cargar datos (seed)**.
4. **Simular tormenta** → aparecen alertas propuestas; **Aprobar y enviar**.

## Problemas comunes

| Síntoma | Solución |
|---|---|
| El panel dice "Sin conexión" | El backend no está corriendo; revisar la terminal 1 |
| `port is already allocated` (5432 u 8000) | Otro programa usa el puerto: cerrar otro PostgreSQL local o cambiar el puerto en `docker-compose.yml` |
| "Clave incorrecta" | Usar el valor de `CLAVE_UNICA` del archivo `.env` |
| El mapa no muestra colonias | Falta el paso 3 o el seed (⚙ → Cargar datos) |
| Cambié `.env` y no se aplica | `docker compose down` y luego `docker compose up --build` |

Pruebas del backend:

```bash
docker compose exec api pytest
```
