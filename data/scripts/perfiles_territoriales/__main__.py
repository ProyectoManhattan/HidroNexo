import argparse
import json
import sys

from . import config, perfiles, procesar, salida


def main(argv=None):
    ap = argparse.ArgumentParser(prog="perfiles_territoriales", description=__doc__)
    sub = ap.add_subparsers(dest="cmd")
    sub.add_parser("generar", help="Procesa y escribe data/perfiles/ (predeterminado)")
    f = sub.add_parser("ficha", help="Muestra la ficha de un polígono ya generado")
    f.add_argument("id_poligono")
    ll = sub.add_parser("lluvia", help="Evalúa qué tan inusual es una lluvia según el historial del SMN")
    ll.add_argument("mm", type=float)
    ll.add_argument("--mes", type=int, required=True)
    ll.add_argument("--estacion", default="30192")
    ll.add_argument("--ventana", choices=["24h", "72h"], default="24h")
    a = ap.parse_args(argv)
    if a.cmd == "lluvia":
        from . import climatologia
        mod = climatologia.modelo()
        if not mod or a.estacion not in mod["estaciones"]:
            sys.exit("No hay serie para esa estación en data/fuentes/smn/")
        r = climatologia.evaluar(a.mm, a.mes, mod["_series"][a.estacion], mod["estaciones"][a.estacion]["extremos"], a.ventana)
        e = mod["estaciones"][a.estacion]
        print(f"{a.mm} mm en {a.ventana} en {climatologia.MESES[a.mes - 1]} · estación {a.estacion} {e['nombre']}")
        print(f"  percentil en el mes: {r['percentil_en_el_mes']} | periodo de retorno anual: {r['periodo_retorno_anual_anios']} años | categoría: {r['categoria']}")
        print("  (describe qué tan inusual es según el historial; no es un pronóstico ni una probabilidad de inundación)")
        return
    if a.cmd == "ficha":
        datos = json.loads((config.SALIDA / "perfiles_territoriales.json").read_text(encoding="utf-8"))
        p = next((x for x in datos["perfiles"] if x["id_poligono"] == a.id_poligono), None)
        if p is None:
            sys.exit(f"No existe el polígono {a.id_poligono}")
        print(perfiles.ficha(p))
        return
    r = procesar.ejecutar()
    rutas = salida.escribir(r)
    print("Perfiles generados:", len(r["perfiles"]))
    for ruta in rutas:
        print(" ", ruta.relative_to(config.RAIZ))


if __name__ == "__main__":
    main()
