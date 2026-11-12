import 'package:agua_lluvia/data/local/local_database.dart';
import 'package:agua_lluvia/data/mock_report_repository.dart';
import 'package:agua_lluvia/models/active_alert.dart';
import 'package:agua_lluvia/models/coordinates.dart';
import 'package:agua_lluvia/models/new_report.dart';
import 'package:agua_lluvia/services/connectivity_service.dart';
import 'package:agua_lluvia/services/mesh/in_memory_mesh.dart';
import 'package:agua_lluvia/services/mesh/mesh_message.dart';
import 'package:agua_lluvia/services/mesh/mesh_node.dart';
import 'package:agua_lluvia/services/mesh/mesh_store.dart';
import 'package:agua_lluvia/services/mesh/postal_code_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Repo extends MockReportRepository {
  final List<NewReport> submitted = [];

  @override
  Future<String> submit(NewReport report) async {
    submitted.add(report);
    return 'AV-${submitted.length}';
  }
}

class _Harness {
  final net = InMemoryMeshNetwork();
  final nodes = <String, MeshNode>{};
  final stores = <String, MemoryMeshStore>{};
  final shown = <String, List<ActiveAlert>>{};
  final repos = <String, _Repo>{};
  final nets = <String, FakeConnectivityService>{};
  DateTime now = DateTime(2026, 11, 12, 10);

  Future<MeshNode> add(String id, String? cp, {bool online = false}) async {
    shown[id] = [];
    final repo = repos[id] = _Repo();
    final conn = nets[id] = FakeConnectivityService()..online = online;
    final store = stores[id] = MemoryMeshStore();
    final node = nodes[id] = MeshNode(
      transport: net.node(id),
      store: store,
      cpResolver: PostalCodeResolver(manualStore: MemoryManualCpStore(cp)),
      repository: repo,
      connectivity: conn,
      onShowAlert: shown[id]!.add,
      now: () => now,
      linger: null,
      label: id,
    );
    await node.start();
    return node;
  }

  /// Nodos A..E en cadena con los CP dados.
  Future<void> chain(List<String?> cps, {String names = 'ABCDE'}) async {
    for (var i = 0; i < cps.length; i++) {
      await add(names[i], cps[i]);
    }
    for (var i = 0; i < cps.length - 1; i++) {
      net.link(names[i], names[i + 1]);
    }
    await settle();
  }

  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await pumpEventQueue();
      await Future.wait(nodes.values.map((n) => n.idle()));
    }
  }

  Future<int> stored(String id) async => (await stores[id]!.all()).length;
}

const _cps = ['91700', '91701', '91702', '91703', '91704'];

void main() {
  late _Harness h;
  setUp(() => h = _Harness());

  group('alertas', () {
    test('llega y se muestra solo en el CP destino; aguanta 2 saltos fuera y se descarta después', () async {
      await h.chain(_cps);
      await h.nodes['A']!.publishAlert(cps: ['91700'], level: 'alto', text: 'Prueba', simulated: true);
      await h.settle();

      expect(h.shown['A'], hasLength(1)); // quien la crea en su zona la ve
      expect(h.shown['A']!.single.simulated, isTrue);
      for (final id in ['B', 'C', 'D', 'E']) {
        expect(h.shown[id], isEmpty, reason: id);
      }
      expect(await h.stored('B'), 1); // 1.er salto fuera
      expect(await h.stored('C'), 1); // 2.º salto fuera
      expect(await h.stored('D'), 0); // 3.º: descartada
      expect(await h.stored('E'), 0);
      expect(h.nodes['D']!.discarded, 1);
      expect(h.nodes['D']!.log.any((e) => e.text.contains('fuera de zona')), isTrue);
      expect(h.nodes['E']!.received, 0);
    });

    test('un nodo fuera de zona la lleva hasta el destino al otro lado', () async {
      await h.chain(_cps);
      await h.nodes['A']!.publishAlert(cps: ['91702'], level: 'critico', text: 'Hola');
      await h.settle();

      expect(h.shown['C'], hasLength(1));
      expect(h.shown['C']!.single.level, AlertLevel.critico);
      expect(h.shown['C']!.single.zoneName, 'C.P. 91702');
      for (final id in ['A', 'B', 'D', 'E']) {
        expect(h.shown[id], isEmpty, reason: id);
      }
      // C reinicia el colchón: D y E (1.º y 2.º salto fuera) también la guardan.
      expect(await h.stored('D'), 1);
      expect(await h.stored('E'), 1);
    });

    test('CP desconocido: reenvía pero no muestra', () async {
      await h.chain(['91700', null, '91702', '91703', '91704']);
      await h.nodes['A']!.publishAlert(cps: ['91702'], level: 'alto', text: 'x');
      await h.settle();
      expect(h.shown['B'], isEmpty);
      expect(h.shown['C'], hasLength(1)); // pasó por B
      expect(h.nodes['B']!.log.any((e) => e.text.contains('desconocido')), isTrue);
    });

    test('dedupe: en un anillo no hay bucles ni se muestra dos veces', () async {
      for (final e in {'A': '91700', 'B': '91700', 'C': '91700'}.entries) {
        await h.add(e.key, e.value);
      }
      h.net
        ..link('A', 'B')
        ..link('B', 'C')
        ..link('C', 'A');
      await h.nodes['A']!.publishAlert(cps: ['91700'], level: 'alto', text: 'x');
      await h.settle();
      expect(h.shown['B'], hasLength(1));
      expect(h.shown['C'], hasLength(1));
      final totalSent = h.nodes.values.fold<int>(0, (s, n) => s + n.sent);
      expect(totalSent, lessThanOrEqualTo(6)); // acotado: nada de ciclos
      expect(h.nodes.values.any((n) => n.log.any((e) => e.text.contains('duplicado'))), isTrue);
    });

    test('expirada: no se reenvía y el receptor la descarta', () async {
      await h.add('A', '91700');
      await h.add('B', '91700');
      await h.nodes['A']!.publishAlert(cps: ['91700'], level: 'alto', text: 'x', validity: const Duration(seconds: 30));
      h.now = h.now.add(const Duration(minutes: 5));
      h.net.link('A', 'B'); // al conectar, A no envía la vencida
      await h.settle();
      expect(h.nodes['B']!.received, 0);

      // Una vencida que llega igual (reloj distinto) se descarta.
      final old = MeshMessage(
        id: 'viejo',
        kind: MeshKind.alerta,
        cps: const ['91700'],
        createdAt: h.now.millisecondsSinceEpoch ~/ 1000 - 100,
        expiresAt: h.now.millisecondsSinceEpoch ~/ 1000 - 10,
      );
      await h.net.node('A').send('B', old.toBytes());
      await h.settle();
      expect(h.nodes['B']!.discarded, 1);
      expect(h.shown['B'], isEmpty);
      expect(h.nodes['B']!.log.first.text, contains('venció'));
    });

    test('ttl: no se reenvía al llegar al límite de saltos', () async {
      await h.chain(List.filled(5, '91700'));
      await h.nodes['A']!.publishAlert(cps: ['91700'], level: 'alto', text: 'x', ttl: 2);
      await h.settle();
      expect(h.shown['B'], hasLength(1)); // hops 1
      expect(h.shown['C'], hasLength(1)); // hops 2 = ttl: se muestra pero no sigue
      expect(h.shown['D'], isEmpty);
      expect(h.shown['E'], isEmpty);
    });

    test('máximo 20 mensajes guardados (se borra el más antiguo)', () async {
      await h.add('A', '91700');
      for (var i = 0; i < 25; i++) {
        h.now = h.now.add(const Duration(seconds: 1));
        await h.nodes['A']!.publishAlert(cps: ['99999'], level: 'bajo', text: 'm$i', id: 'm$i');
      }
      final ids = (await h.stores['A']!.all()).map((e) => e.message.id).toSet();
      expect(ids, hasLength(20));
      expect(ids.contains('m0'), isFalse);
      expect(ids.contains('m24'), isTrue);
      expect(h.nodes['A']!.storedCount, 20);
    });

    test('al conectar con un vecino se le envían los mensajes guardados', () async {
      await h.add('A', '91700');
      await h.add('B', '91700');
      await h.nodes['A']!.publishAlert(cps: ['91700'], level: 'alto', text: 'x');
      h.net.link('A', 'B');
      await h.settle();
      expect(h.shown['B'], hasLength(1));
    });
  });

  group('reportes', () {
    test('viaja por nodos sin internet hasta uno con internet que lo sube una sola vez', () async {
      await h.chain(_cps);
      h.nets['E']!.online = true;
      await h.nodes['A']!.publishReportPayload({
        'cliente_id': 'cliente-123',
        'categoria': 'inundacion',
        'severidad': 2,
        'lat': 19.19,
        'lon': -96.13,
        'descripcion': 'Calle inundada',
        'direccion': 'Centro',
      });
      await h.settle();

      expect(h.repos['E']!.submitted, hasLength(1));
      expect(h.repos['E']!.submitted.single.clienteId, 'cliente-123');
      for (final id in ['A', 'B', 'C', 'D']) {
        expect(h.repos[id]!.submitted, isEmpty, reason: id);
      }
      expect(h.nodes['E']!.log.any((e) => e.text.contains('subido a internet')), isTrue);

      // Reconexión: D vuelve a ofrecérselo a E, que no lo sube de nuevo.
      h.net.unlink('D', 'E');
      h.net.link('D', 'E');
      await h.settle();
      expect(h.repos['E']!.submitted, hasLength(1));
    });

    test('al recuperar internet sube el reporte que llevaba guardado', () async {
      await h.add('A', null);
      await h.add('B', null);
      h.net.link('A', 'B');
      await h.nodes['A']!.publishReportPayload({
        'cliente_id': 'c-9',
        'categoria': 'fuga',
        'severidad': 1,
        'lat': 19.2,
        'lon': -96.1,
        'descripcion': 'x',
        'direccion': '',
      });
      await h.settle();
      expect(h.repos['B']!.submitted, isEmpty);
      h.nets['B']!.online = true;
      await h.settle();
      expect(h.repos['B']!.submitted.single.clienteId, 'c-9');
    });
  });

  group('código postal', () {
    Map<String, dynamic> square(String name, double x0, double y0, double x1, double y1) => {
          'type': 'Feature',
          'properties': {'nombre': name},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                [x0, y0],
                [x1, y0],
                [x1, y1],
                [x0, y1],
                [x0, y0],
              ],
            ],
          },
        };

    final geo = {
      'type': 'FeatureCollection',
      'features': [
        square('C.P. 91690', -96.20, 19.10, -96.10, 19.20),
        {
          'type': 'Feature',
          'properties': {'nombre': 'C.P. 91700'},
          'geometry': {
            'type': 'MultiPolygon',
            'coordinates': [
              [
                [
                  [-96.10, 19.10],
                  [-96.00, 19.10],
                  [-96.00, 19.20],
                  [-96.10, 19.20],
                  [-96.10, 19.10],
                ],
              ],
            ],
          },
        },
        square('Sin código', -97, 18, -96.5, 18.5),
      ],
    };

    test('extrae el CP del nombre', () {
      expect(PostalCodeResolver.extractCp('C.P. 91690'), '91690');
      expect(PostalCodeResolver.extractCp('Colonia Centro'), isNull);
      expect(PostalCodeResolver.extractCp(null), isNull);
    });

    test('punto en polígono y multipolígono', () {
      expect(PostalCodeResolver.cpFromGeoJson(geo, 19.15, -96.15), '91690');
      expect(PostalCodeResolver.cpFromGeoJson(geo, 19.15, -96.05), '91700');
      expect(PostalCodeResolver.cpFromGeoJson(geo, 18.25, -96.7), isNull); // sin CP en el nombre
      expect(PostalCodeResolver.cpFromGeoJson(geo, 30, -100), isNull);
    });

    test('se deriva de la ubicación y el CP fijado a mano manda', () async {
      final r = PostalCodeResolver(
        manualStore: MemoryManualCpStore(),
        loadGeoJson: () async => geo,
        locate: () async => const Coordinates(19.15, -96.05),
      );
      var res = await r.resolve();
      expect(res.cp, '91700');
      expect(res.source, CpSource.gps);

      expect(await r.setManual('12345'), isTrue);
      res = await r.resolve();
      expect(res.cp, '12345');
      expect(res.source, CpSource.manual);

      expect(await r.setManual('12a'), isFalse);
      expect(r.manual, '12345');

      await r.setManual('');
      expect((await r.resolve()).cp, '91700');
    });

    test('sin ubicación ni zonas el CP es desconocido', () async {
      final r = PostalCodeResolver(manualStore: MemoryManualCpStore());
      expect((await r.resolve()).cp, isNull);
    });
  });

  group('almacén SQLite', () {
    sqfliteFfiInit();

    test('migra a la versión 2, limita a 20 y purga vencidos', () async {
      expect(LocalDatabase.version, greaterThanOrEqualTo(2));
      final db = LocalDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      final store = SqlMeshStore(db);
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      for (var i = 0; i < 22; i++) {
        await store.put(StoredMesh(
          message: MeshMessage(id: 'id$i', kind: MeshKind.alerta, createdAt: nowSec, expiresAt: nowSec + 3600, cps: const ['1']),
          from: 'self',
          receivedAt: i,
        ));
      }
      expect(await store.all(), hasLength(20));
      expect(await store.has('id0'), isFalse);
      expect(await store.has('id21'), isTrue);
      await store.put(StoredMesh(
        message: MeshMessage(id: 'viejo', kind: MeshKind.alerta, createdAt: 1, expiresAt: 2),
        from: 'self',
        receivedAt: 100,
      ));
      expect(await store.purgeExpired(DateTime.now()), greaterThanOrEqualTo(1));
      expect(await store.has('viejo'), isFalse);
      await db.close();
    });

    test('mensaje de menos de 1 KB', () {
      final m = MeshMessage(
        id: 'a' * 36,
        kind: MeshKind.reporte,
        createdAt: 1,
        expiresAt: 2,
        payload: {
          'cliente_id': 'a' * 36,
          'categoria': 'inundacion',
          'severidad': 3,
          'lat': 19.1903,
          'lon': -96.1342,
          'descripcion': 'x' * 280,
          'direccion': 'y' * 80,
        },
      );
      expect(m.toBytes().length, lessThan(MeshMessage.maxBytes));
      expect(MeshMessage.fromBytes(m.toBytes())!.id, m.id);
    });
  });
}
