from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.tiempo_real import conexiones

router = APIRouter(tags=["tiempo real"])


@router.websocket("/ws")
async def websocket(ws: WebSocket):
    """Mensajes que recibe el panel: {"tipo": "<evento>", "datos": {...}}.

    Tipos: report.created, report.updated, zone.risk_updated, alert.drafted,
    alert.approved, weather.updated, official_alerts.updated
    """
    await ws.accept()
    conexiones.agregar(ws)
    try:
        while True:
            await ws.receive_text()  # El panel puede mandar "ping"; se ignora
    except WebSocketDisconnect:
        conexiones.quitar(ws)
