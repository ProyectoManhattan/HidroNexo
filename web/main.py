"""Panel web de Protección Civil (NiceGUI).

    pip install -r requirements.txt
    python main.py

Variables: API_URL (por defecto http://localhost:8000), PUERTO_WEB (por defecto 8080).
"""
from nicegui import app, ui

import paginas.panel  # noqa: F401  (registra la página "/")
from api import tiempo_real
from config import PUERTO

app.on_startup(tiempo_real.escuchar)

if __name__ in {"__main__", "__mp_main__"}:
    ui.run(title="Agua y Lluvia · Panel", port=PUERTO, reload=False, show=False, favicon="💧")
