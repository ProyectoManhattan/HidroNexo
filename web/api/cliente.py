"""Llamadas al backend. Contrato en docs/api.md."""
import httpx

from config import API_URL


class ErrorApi(Exception):
    def __init__(self, estado: int, detalle: str):
        super().__init__(detalle)
        self.estado = estado
        self.detalle = detalle


async def _pedir(metodo: str, ruta: str, clave: str | None = None, **kwargs):
    headers = {"X-Clave": clave} if clave else {}
    try:
        async with httpx.AsyncClient(base_url=API_URL, timeout=8) as cliente:
            respuesta = await cliente.request(metodo, ruta, headers=headers, **kwargs)
    except httpx.HTTPError:
        raise ErrorApi(0, "No hay conexión con la API")
    if respuesta.status_code >= 400:
        try:
            detalle = respuesta.json().get("detail", respuesta.text)
        except ValueError:
            detalle = respuesta.text
        raise ErrorApi(respuesta.status_code, str(detalle))
    return respuesta.json()


# ---- lectura (pública)
async def categorias():
    return await _pedir("GET", "/reports/categories")


async def reportes(categoria: str | None = None):
    params = {"categoria": categoria} if categoria else {}
    return await _pedir("GET", "/reports", params=params)


async def riesgo():
    return await _pedir("GET", "/zones/risk")


async def alertas(estado: str = "propuesta"):
    return await _pedir("GET", "/alerts", params={"estado": estado})


# ---- operador (requieren clave)
async def clima(clave: str):
    return await _pedir("GET", "/admin/weather", clave)


async def reporte_manual(clave: str, datos: dict):
    return await _pedir("POST", "/reports/manual", clave, json=datos)


async def resolver_reporte(clave: str, reporte_id: int):
    return await _pedir("POST", f"/reports/{reporte_id}/resolve", clave)


async def editar_alerta(clave: str, alerta_id: int, texto: str):
    return await _pedir("PATCH", f"/alerts/{alerta_id}", clave, json={"texto": texto})


async def aprobar_alerta(clave: str, alerta_id: int):
    return await _pedir("POST", f"/alerts/{alerta_id}/approve", clave)


async def descartar_alerta(clave: str, alerta_id: int):
    return await _pedir("POST", f"/alerts/{alerta_id}/discard", clave)


async def simular_tormenta(clave: str, intensidad: float):
    return await _pedir("POST", "/admin/simulate-storm", clave, json={"intensidad": intensidad})


async def terminar_tormenta(clave: str):
    return await _pedir("DELETE", "/admin/simulate-storm", clave)


async def seed(clave: str):
    return await _pedir("POST", "/admin/seed", clave)


async def reset(clave: str):
    return await _pedir("POST", "/admin/reset", clave)
