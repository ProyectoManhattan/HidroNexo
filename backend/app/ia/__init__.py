"""Módulo de IA (Persona C).

Contrato con el resto del backend:
    redactar_alerta(colonia, nivel, motivo, tipo) -> (texto, "llm" | "plantilla")

La IA propone, el humano decide: el texto siempre pasa por aprobación en el panel.
Las guías de acción NO las redacta el LLM: vienen de data/guias/.
"""
