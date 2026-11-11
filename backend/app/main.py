import asyncio
import logging
from contextlib import asynccontextmanager
from datetime import datetime

from apscheduler.schedulers.background import BackgroundScheduler
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import suscripciones
from app.admin.router import router as admin_router
from app.alertas.router import router as alertas_router
from app.colonias.router import router as colonias_router
from app.config import settings
from app.dispositivos.router import router as dispositivos_router
from app.guias.router import router as guias_router
from app.meteorologia import ingesta
from app.reportes.router import router as reportes_router
from app.tiempo_real import conexiones
from app.tiempo_real.router import router as tiempo_real_router

logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def ciclo_de_vida(app: FastAPI):
    conexiones.fijar_loop(asyncio.get_running_loop())
    suscripciones.registrar()
    programador = BackgroundScheduler(timezone="UTC")
    if settings.meteo_activa:
        programador.add_job(
            ingesta.ejecutar, "interval", minutes=settings.meteo_intervalo_min, next_run_time=datetime.now()
        )
        programador.start()
    yield
    if programador.running:
        programador.shutdown(wait=False)


app = FastAPI(
    title="Agua y Lluvia · Veracruz",
    description=(
        "Reportes ciudadanos, riesgo por colonia y alertas. **No sustituye al 911.**\n\n"
        "Las acciones que modifican requieren el header `X-Clave`."
    ),
    version="0.1.0",
    lifespan=ciclo_de_vida,
)

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


@app.get("/health", tags=["sistema"])
def health():
    return {"status": "ok"}


for router in (
    reportes_router,
    colonias_router,
    alertas_router,
    guias_router,
    dispositivos_router,
    admin_router,
    tiempo_real_router,
):
    app.include_router(router)
