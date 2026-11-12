"""Asignación de antecedentes de inundación (data/antecedentes/eventos_inundacion.json) a polígonos.

Las fuentes nombran COLONIAS; los polígonos son CÓDIGOS POSTALES. La correspondencia usa el catálogo
SEPOMEX (asentamiento → código postal). Reglas:
  - Un solo CP candidato y nombre idéntico al de la fuente        → asignación única, confianza alta
  - Un solo CP candidato por coincidencia parcial o alias          → asignación única, confianza media
  - Varios CP, pero uno es colonia/fraccionamiento con nombre exacto → ese CP, confianza media (resto como alternativas)
  - Varios CP sin criterio para elegir                             → ambigua: se anota en todos, confianza baja
  - Sin coincidencia                                               → no se asigna
Solo las asignaciones únicas cuentan en `eventos_registrados`.
"""
import json
import re
import unicodedata
from collections import defaultdict

import pandas as pd

from . import config
from .calidad import Bitacora

MUNICIPIOS = ["Veracruz", "Boca del Río", "Medellín de Bravo"]
PREFIJOS = r"^(colonia|col|fraccionamiento|fracc|unidad habitacional|u h)\s+"


def normalizar(texto: str) -> str:
    t = unicodedata.normalize("NFKD", str(texto)).encode("ascii", "ignore").decode().lower()
    t = re.sub(r"[^a-z0-9 ]", " ", t)
    t = re.sub(r"\s+", " ", t).strip()
    return re.sub(PREFIJOS, "", t)


def _catalogo(bitacora: Bitacora) -> pd.DataFrame | None:
    if not config.SEPOMEX.exists():
        bitacora.registrar("fuente_faltante", f"No está el catálogo SEPOMEX ({config.SEPOMEX}); los antecedentes no se asignan a polígonos")
        return None
    c = pd.read_csv(config.SEPOMEX, dtype=str)
    c = c[c["D_mnpio"].isin(MUNICIPIOS)].copy()
    c["norm"] = c["d_asenta"].map(normalizar)
    return c


def _buscar(cat: pd.DataFrame, mencion: dict) -> dict:
    municipios = [mencion["municipio"]] if mencion.get("municipio") else MUNICIPIOS
    sub = cat[cat["D_mnpio"].isin(municipios)]
    terminos = [(normalizar(mencion["nombre_fuente"]), False)] + [(normalizar(a), True) for a in mencion.get("alias", [])]
    filas, exacta_fuente = [], False
    for t, es_alias in terminos:
        exactas = sub[sub["norm"] == t]
        parciales = sub[sub["norm"].str.contains(rf"\b{re.escape(t)}\b", regex=True)]
        if len(exactas) and not es_alias:
            exacta_fuente = True
        for df, tipo in ((exactas, "exacta"), (parciales, "parcial")):
            for r in df.itertuples():
                filas.append({"cp": r.d_codigo, "asentamiento": r.d_asenta, "tipo_asentamiento": r.d_tipo_asenta,
                              "municipio": r.D_mnpio, "coincidencia": tipo, "por_alias": es_alias})
    if not filas:
        return {"estado": "sin_coincidencia", "cps": [], "confianza": None, "candidatos": []}
    cand = pd.DataFrame(filas).drop_duplicates(["cp", "asentamiento"])
    cps = sorted(cand["cp"].unique())
    if len(cps) == 1:
        return {"estado": "unica", "cps": cps, "confianza": "alta" if exacta_fuente else "media", "candidatos": cand.to_dict("records")}
    fuertes = cand[(cand["coincidencia"] == "exacta") & cand["tipo_asentamiento"].isin(["Colonia", "Fraccionamiento"])]
    if fuertes["cp"].nunique() == 1:
        return {"estado": "unica", "cps": [fuertes["cp"].iloc[0]], "confianza": "media", "candidatos": cand.to_dict("records")}
    return {"estado": "ambigua", "cps": cps, "confianza": "baja", "candidatos": cand.to_dict("records")}


def asignar(ids_poligonos: set[str], bitacora: Bitacora) -> dict:
    datos = json.loads(config.ANTECEDENTES.read_text(encoding="utf-8"))
    cat = _catalogo(bitacora)
    por_cp: dict[str, list] = defaultdict(list)
    menciones = []
    for ev in datos["eventos"]:
        fuentes = [f["url"] for f in ev["fuentes"]]
        if not ev["colonias"]:
            menciones.append({"evento": ev["id"], "colonia_fuente": None, "estado": "sin_colonias_en_fuente"})
        for m in ev["colonias"]:
            res = _buscar(cat, m) if cat is not None else {"estado": "sin_catalogo", "cps": [], "confianza": None, "candidatos": []}
            fuera = [cp for cp in res["cps"] if cp not in ids_poligonos]
            menciones.append({
                "evento": ev["id"], "fecha": ev["fecha"], "tipo": ev["tipo"], "colonia_fuente": m["nombre_fuente"],
                "municipio_fuente": m.get("municipio"), "estado": res["estado"], "confianza": res["confianza"],
                "codigos_postales": res["cps"], "cps_sin_poligono": fuera,
                "asentamientos_sepomex": sorted({f"{c['asentamiento']} ({c['cp']})" for c in res["candidatos"]}),
                "nota_alias": m.get("nota_alias"),
            })
            for cp in res["cps"]:
                if cp in ids_poligonos:
                    por_cp[cp].append({
                        "evento": ev["id"], "nombre": ev["nombre"], "fecha": ev["fecha"], "tipo": ev["tipo"],
                        "colonia_fuente": m["nombre_fuente"], "asignacion": res["estado"], "confianza": res["confianza"],
                        "alternativas": [c for c in res["cps"] if c != cp], "nota_alias": m.get("nota_alias"), "fuentes": fuentes,
                    })
    for m in menciones:
        if m["estado"] == "sin_coincidencia":
            bitacora.registrar("antecedente_sin_ubicar", f"'{m['colonia_fuente']}' ({m['evento']}) no aparece en SEPOMEX para el municipio indicado")
        elif m["estado"] == "ambigua":
            bitacora.registrar("antecedente_ambiguo", f"'{m['colonia_fuente']}' ({m['evento']}) puede ser los CP {', '.join(m['codigos_postales'])}")
    return {"por_cp": dict(por_cp), "menciones": menciones, "meta": {k: datos[k] for k in ("descripcion", "fecha_compilacion", "metodo")}}


def resumen_poligono(registros: list) -> dict:
    observados = {r["evento"] for r in registros if r["tipo"] == "evento_observado" and r["asignacion"] == "unica"}
    posibles = {r["evento"] for r in registros if r["tipo"] == "evento_observado" and r["asignacion"] == "ambigua"} - observados
    alertas = {r["evento"] for r in registros if r["tipo"] == "alerta_preventiva"}
    riesgo = {r["evento"] for r in registros if r["tipo"] == "riesgo_identificado"}
    return {
        "eventos_registrados": len(observados) or None,
        "eventos_posibles_por_nombre_ambiguo": len(posibles) or None,
        "alertas_preventivas": len(alertas) or None,
        "identificado_en_riesgo": bool(riesgo) or None,
        "registros": registros,
        "fuentes": sorted({u for r in registros for u in r["fuentes"]}),
    }
