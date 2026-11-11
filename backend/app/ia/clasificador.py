"""Clasificación de reportes (si sobra tiempo, plan 4.2).

TODO (Persona C): sugerir la categoría a partir de la descripción con LLM,
con respaldo por reglas (palabras clave) si el LLM falla.
"""

PALABRAS_CLAVE = {
    "fuga": ["fuga", "tubo roto", "brota", "chorro"],
    "sin_agua": ["sin agua", "tandeo", "no hay agua", "no llega el agua"],
    "alcantarilla": ["alcantarilla", "coladera", "drenaje tapado"],
    "inundacion": ["inunda", "se metió el agua", "casa con agua"],
    "encharcamiento": ["charco", "encharca"],
}


def clasificar_por_reglas(texto: str) -> str | None:
    texto = texto.lower()
    for categoria, palabras in PALABRAS_CLAVE.items():
        if any(p in texto for p in palabras):
            return categoria
    return None
