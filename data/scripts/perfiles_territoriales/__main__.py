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
    a = ap.parse_args(argv)
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
