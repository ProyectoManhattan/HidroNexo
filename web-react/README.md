# Panel web (React + Vite + TypeScript + MapLibre)

Panel de Protección Civil. Requiere el backend en `http://localhost:8000` (`docker compose up --build` desde la raíz).

```bash
cd web-react
cp .env.example .env   # opcional; VITE_API_URL por defecto es http://localhost:8000
npm install
npm run dev            # http://localhost:5173
npm run build          # compila a dist/
```

## Estructura
- `src/types.ts`: tipos de docs/api.md. `src/constants.ts`: colores y etiquetas.
- `src/api/client.ts`: funciones tipadas por endpoint; `src/api/realtime.ts`: WebSocket con reconexión.
- `src/store.ts`: estado global (`useStore(selector)`), acciones y sondeo cada 15 s.
- `src/components/*`: un archivo por zona del layout (cada uno lo edita un solo dueño).

## Clave de operador
El panel es exclusivo de Protección Civil, así que nunca pide clave: la envía solo en el encabezado `X-Clave` en los endpoints de operador. Se configura con `VITE_CLAVE` en `.env` (por defecto `cambiar-esta-clave`) y debe coincidir con la del backend. Ojo: la variable queda incluida en el JS compilado, por lo que es una barrera ligera, no seguridad real.
