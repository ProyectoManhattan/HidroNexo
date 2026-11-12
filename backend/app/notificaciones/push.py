"""Push con Firebase Cloud Messaging (FCM).

Sin `FCM_CREDENCIALES_JSON` el envío es simulado (solo log): así funcionan dev y
pruebas, y la app tiene el respaldo GET /alerts/active.
"""
import json
import logging
import time
from dataclasses import dataclass

from sqlalchemy import update
from sqlalchemy.orm import Session

from app.alertas.modelos import EntregaAlerta
from app.config import settings
from app.dispositivos.modelos import Dispositivo
from app.dispositivos.servicio import dispositivos_destino
from app.utiles import ahora

log = logging.getLogger(__name__)

LOTE = 500
REINTENTOS = 2  # reintentos ante fallos transitorios (además del primer intento)
ESPERA_REINTENTO_S = 1.0

_app = None


@dataclass
class Resultado:
    estado: str  # "enviado" | "fallido" | "token_invalido"
    error: str | None = None
    transitorio: bool = False


def fcm_activo() -> bool:
    return bool(settings.fcm_credenciales_json.strip())


def _app_firebase():
    global _app
    if _app is None:
        import firebase_admin
        from firebase_admin import credentials

        credencial = credentials.Certificate(json.loads(settings.fcm_credenciales_json))
        _app = firebase_admin.initialize_app(credencial)
    return _app


def _multicast(tokens: list[str], titulo: str, cuerpo: str, datos: dict):
    """Llamada real a FCM; devuelve la lista de respuestas (una por token). Aislada para poder mockearla."""
    from firebase_admin import messaging

    mensaje = messaging.MulticastMessage(
        tokens=tokens,
        notification=messaging.Notification(title=titulo, body=cuerpo),
        data=datos,
        android=messaging.AndroidConfig(priority="high"),
    )
    return messaging.send_each_for_multicast(mensaje, app=_app_firebase()).responses


def _clasificar(excepcion) -> Resultado:
    from firebase_admin import exceptions, messaging

    texto = f"{excepcion.__class__.__name__}: {excepcion}"[:500]
    if isinstance(excepcion, (messaging.UnregisteredError, messaging.SenderIdMismatchError, exceptions.InvalidArgumentError)):
        return Resultado("token_invalido", texto)
    transitorio = isinstance(
        excepcion,
        (exceptions.UnavailableError, exceptions.InternalError, exceptions.DeadlineExceededError, messaging.QuotaExceededError),
    )
    return Resultado("fallido", texto, transitorio)


def _enviar_tokens(tokens: list[str], titulo: str, cuerpo: str, datos: dict) -> list[Resultado]:
    """Envía a FCM por lotes de 500, reintentando solo los fallos transitorios."""
    resultados: list[Resultado | None] = [None] * len(tokens)
    pendientes = list(range(len(tokens)))
    for intento in range(REINTENTOS + 1):
        if intento:
            time.sleep(ESPERA_REINTENTO_S * intento)
        siguientes = []
        for ini in range(0, len(pendientes), LOTE):
            indices = pendientes[ini : ini + LOTE]
            try:
                respuestas = _multicast([tokens[i] for i in indices], titulo, cuerpo, datos)
            except Exception as error:  # fallo de toda la llamada (red, credenciales…)
                log.exception("FCM: fallo del lote")
                respuestas = None
                for i in indices:
                    resultados[i] = Resultado("fallido", f"{error.__class__.__name__}: {error}"[:500], True)
                siguientes.extend(indices)
                continue
            for i, r in zip(indices, respuestas):
                if r.success:
                    resultados[i] = Resultado("enviado")
                else:
                    resultados[i] = _clasificar(r.exception)
                    if resultados[i].transitorio:
                        siguientes.append(i)
        pendientes = siguientes
        if not pendientes:
            break
    return resultados  # type: ignore[return-value]


def enviar_alerta(db: Session, alerta) -> dict:
    """Envía la alerta a sus dispositivos destino, audita cada entrega y devuelve el resumen."""
    dispositivos = dispositivos_destino(db, alerta)
    titulo = f"Alerta {alerta.nivel}" + (" (SIMULACIÓN)" if alerta.simulada else "")
    datos = {"alerta_id": str(alerta.id), "tipo": alerta.tipo, "nivel": alerta.nivel}

    if not dispositivos:
        resultados: list[Resultado] = []
    elif fcm_activo():
        resultados = _enviar_tokens([d.token for d in dispositivos], titulo, alerta.texto, datos)
    else:
        log.info("PUSH (simulado) a %d dispositivo(s): %s", len(dispositivos), titulo)
        resultados = [Resultado("enviado") for _ in dispositivos]

    momento = ahora()
    invalidos = []
    for dispositivo, r in zip(dispositivos, resultados):
        db.add(
            EntregaAlerta(
                alerta_id=alerta.id,
                dispositivo_id=dispositivo.id,
                estado=r.estado,
                error=r.error,
                enviada_en=momento,
            )
        )
        if r.estado == "token_invalido":
            invalidos.append(dispositivo.id)
    if invalidos:
        db.flush()
        # Conserva la auditoría sin referencia y elimina los tokens muertos
        db.execute(update(EntregaAlerta).where(EntregaAlerta.dispositivo_id.in_(invalidos)).values(dispositivo_id=None))
        db.execute(Dispositivo.__table__.delete().where(Dispositivo.id.in_(invalidos)))
    db.commit()
    return resumen_de(resultados)


def resumen_de(resultados: list[Resultado]) -> dict:
    estados = [r.estado for r in resultados]
    return {
        "total": len(estados),
        "enviados": estados.count("enviado"),
        "fallidos": estados.count("fallido"),
        "token_invalidos": estados.count("token_invalido"),
    }
