"""Catálogos como datos, no como enums de base de datos.

Así se pueden agregar categorías (por ejemplo, para el requisito nuevo del jueves)
sin migraciones. Ver plan, sección 7.
"""

CATEGORIAS = {
    "inundacion": "Inundación",
    "encharcamiento": "Encharcamiento",
    "alcantarilla": "Alcantarilla tapada",
    "fuga": "Fuga de agua",
    "sin_agua": "Sin agua / tandeo",
}

# Severidad visual en la app: 1 = baja, 2 = media, 3 = alta
SEVERIDADES = {1: "Baja", 2: "Media", 3: "Alta"}

NIVELES_RIESGO = ["bajo", "medio", "alto", "critico"]
