import os

# Dirección del backend. En docker compose sería http://api:8000
API_URL = os.environ.get("API_URL", "http://localhost:8000").rstrip("/")
WS_URL = API_URL.replace("http", "ws", 1) + "/ws"

PUERTO = int(os.environ.get("PUERTO_WEB", "8080"))

# Centro del mapa: Veracruz y Boca del Río
CENTRO_MAPA = (19.165, -96.135)
ZOOM_MAPA = 13

# Fondo del mapa (calles). OpenStreetMap no pide API key.
# Para otro proveedor, definir TEJAS_MAPA y ATRIBUCION_MAPA en el entorno.
TEJAS_MAPA = os.environ.get("TEJAS_MAPA", "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
ATRIBUCION_MAPA = os.environ.get(
    "ATRIBUCION_MAPA", '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
)
