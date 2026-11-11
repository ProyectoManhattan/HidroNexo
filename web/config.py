import os

# Dirección del backend. En docker compose sería http://api:8000
API_URL = os.environ.get("API_URL", "http://localhost:8000").rstrip("/")
WS_URL = API_URL.replace("http", "ws", 1) + "/ws"

PUERTO = int(os.environ.get("PUERTO_WEB", "8080"))

# Centro del mapa: Veracruz y Boca del Río
CENTRO_MAPA = (19.165, -96.135)
ZOOM_MAPA = 13
