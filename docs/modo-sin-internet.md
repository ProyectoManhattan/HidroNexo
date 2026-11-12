# Modo sin internet (malla Bluetooth) — prototipo experimental

## Qué es

Cuando no hay internet, los teléfonos con la app pueden pasarse **alertas** y **reportes**
de uno a otro por Bluetooth (Google Nearby Connections, estrategia `P2P_CLUSTER`,
service id `mx.veracruz.agua_lluvia.malla`). Cada teléfono guarda lo que recibe, lo lleva
consigo y lo reenvía a los vecinos que encuentre (guardar-llevar-reenviar). Un reporte
termina subiéndose cuando llega a un teléfono que sí tiene internet.

Pantalla: Inicio → tarjeta «Modo sin internet (experimental)».

## Cómo presentarlo con 2–3 teléfonos

1. Instalar el APK (`flutter build apk --debug`) en cada teléfono Android.
2. Activar Bluetooth en todos y abrir la app.
3. Entrar a «Modo sin internet (experimental)» y activar el interruptor; conceder los
   permisos (Bluetooth/dispositivos cercanos y ubicación).
4. Poner los teléfonos en **modo avión** (volver a encender Bluetooth si el avión lo apaga).
5. En cada uno fijar un CP distinto en «Mi CP (demo)» y pulsar «Fijar» (p. ej. A=91700,
   B=91701, C=91702). El CP fijado tiene prioridad sobre el GPS.
6. En el teléfono A escribir como «CP destino» el de C (91702) y pulsar «Crear alerta de
   prueba». Mirar el registro en vivo: B (fuera de zona) la guarda y la reenvía; C la muestra
   a pantalla completa con la etiqueta «SIMULACIÓN». Con el CP destino de A, B y C la guardan
   y la reenvían solo 2 saltos fuera de la zona; después se descartan («fuera de zona»).
7. «Crear reporte de prueba» crea un reporte de inundación: viaja por los teléfonos sin
   internet; si uno recupera internet (quitar modo avión/Wi-Fi), lo sube una sola vez.

Los vecinos se conectan solos en unos segundos (hasta ~30 s entre reconexiones con el
mismo vecino). Mantener las apps **abiertas en primer plano** y con la pantalla encendida.

## Reglas de reenvío

- Mensaje JSON < 1 KB: `id`, `tipo` (alerta/reporte), `cps`, `nivel`, `texto`, `creada_en`,
  `expira_en`, `ttl` (25), `saltos`, `saltos_fuera`, `payload` (reportes, sin foto) y `sim`.
- Id ya visto → se ignora. Expirado → se descarta. `saltos >= ttl` → no se reenvía.
- **Alerta**: si mi CP está en el destino → se guarda, se muestra a pantalla completa y se
  reenvía (`saltos_fuera = 0`). Si no, se guarda y reenvía solo si `saltos_fuera + 1 <= 2`;
  si no, se descarta. Con CP propio desconocido se reenvía (mismo presupuesto) sin mostrar.
- **Reporte**: sin filtro por CP. Con internet se sube con su `cliente_id` (el backend es
  idempotente) y se marca entregado (ya no se reenvía); sin internet se guarda y reenvía.
- Almacén local `mesh_messages` (SQLite, máx. 20; purga de vencidos). Al conectar con un
  vecino se le envían los mensajes vigentes guardados (el receptor deduplica). Máx. 3
  conexiones simultáneas, enfriamiento de 30 s por vecino y desconexión tras ~6 s.
- Origen: alertas reales (si hay internet se publican a la malla con el CP de su colonia),
  reporte pendiente de la cola local sin internet, y botones de demostración.
- Mi CP: el fijado a mano; si no, última ubicación (sin pedir permisos nuevos) dentro de los
  polígonos de zonas cacheados (nombres «C.P. 91690»).

## Límites y simplificaciones (prototipo)

- **Sin firma ni cifrado**: cualquiera con la app (o un cliente Nearby) podría falsificar
  alertas o reportes. Solo apto para demostración.
- **Solo con la app abierta** en primer plano; no hay servicio en segundo plano.
- Alcance ~100 m por salto; depende de la densidad de usuarios (sin vecinos no hay malla).
- Sin fotos en los reportes de la malla.
- El nodo con internet que sube un reporte no distingue reportes falsos o repetidos más allá
  del `cliente_id`.
- El CP por ubicación necesita zonas ya cacheadas (haber abierto la app con internet antes);
  para demos en interiores o en modo avión usar «Mi CP (demo)».
- Un mensaje descartado por «fuera de zona» no se recuerda: si llega de nuevo por otro camino
  se evalúa otra vez.
- Probado únicamente con la red en memoria (`InMemoryMeshNetwork`, tests en
  `movil/test/mesh_test.dart`). El transporte real Nearby compila pero **no se ha probado con
  teléfonos reales**; el comportamiento de permisos y la conexión simultánea entre teléfonos
  distintos puede requerir ajustes.
- Con `USE_MOCK=true` la pantalla usa la red en memoria (un solo nodo, sin vecinos).
