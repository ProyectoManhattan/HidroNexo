import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: { port: 5173, strictPort: true },
  // maplibre-gl v6 carga su worker por URL relativa; el prebundle de Vite la rompe
  optimizeDeps: { exclude: ['maplibre-gl'] },
})
