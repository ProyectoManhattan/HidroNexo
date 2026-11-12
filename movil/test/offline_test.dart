import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:agua_lluvia/controllers/report_form_controller.dart';
import 'package:agua_lluvia/data/api_report_repository.dart';
import 'package:agua_lluvia/data/local/local_database.dart';
import 'package:agua_lluvia/data/local/offline_cache.dart';
import 'package:agua_lluvia/data/local/pending_report.dart';
import 'package:agua_lluvia/data/local/pending_report_store.dart';
import 'package:agua_lluvia/data/mock_report_repository.dart';
import 'package:agua_lluvia/data/report_repository.dart';
import 'package:agua_lluvia/models/active_alert.dart';
import 'package:agua_lluvia/models/coordinates.dart';
import 'package:agua_lluvia/models/new_report.dart';
import 'package:agua_lluvia/models/report_type.dart';
import 'package:agua_lluvia/services/connectivity_service.dart';
import 'package:agua_lluvia/services/location_service.dart';
import 'package:agua_lluvia/services/pending_report_queue.dart';
import 'package:agua_lluvia/services/pending_report_sender.dart';
import 'package:agua_lluvia/services/photo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _net = RepositoryException('Sin conexión con el servidor. Revisa tu internet.', retryable: true);
const _invalid = RepositoryException('Revisa los datos del reporte e inténtalo de nuevo.');

/// Repo falso: guiones de respuestas para health, foto y reporte.
class _Repo extends MockReportRepository {
  final List<RepositoryException?> health = [];
  final List<RepositoryException?> upload = [];
  final List<RepositoryException?> submits = [];
  final List<NewReport> submitted = [];
  final List<String?> attemptedIds = [];
  int uploads = 0;
  int healthChecks = 0;

  static RepositoryException? _next(List<RepositoryException?> l) => l.isEmpty ? null : l.removeAt(0);

  @override
  Future<void> checkHealth() async {
    healthChecks++;
    final e = _next(health);
    if (e != null) throw e;
  }

  @override
  Future<String> uploadPhoto(PickedPhoto photo) async {
    uploads++;
    final e = _next(upload);
    if (e != null) throw e;
    return 'http://x/foto.jpg';
  }

  @override
  Future<String> submit(NewReport report) async {
    attemptedIds.add(report.clienteId);
    final e = _next(submits);
    if (e != null) throw e;
    submitted.add(report);
    return 'AV-9';
  }
}

class _FixedRandom implements Random {
  _FixedRandom(this.value);
  final double value;
  @override
  double nextDouble() => value;
  @override
  bool nextBool() => false;
  @override
  int nextInt(int max) => 0;
}

NewReport _report({String id = 'id-1', String text = 'Agua en la calle', String? photoUrl}) => NewReport(
      type: ReportType.flood,
      neighborhood: 'Centro',
      address: 'Calle 1',
      position: const Coordinates(19.19, -96.13),
      description: text,
      severity: 2,
      clienteId: id,
      photoUrl: photoUrl,
    );

void main() {
  sqfliteFfiInit();

  late LocalDatabase db;
  late Directory tmp;
  late File photo;

  setUp(() async {
    db = LocalDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    tmp = await Directory.systemTemp.createTemp('offline_test');
    photo = await File('${tmp.path}/origen.jpg').writeAsBytes([1, 2, 3]);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  PendingReportQueue newQueue() => PendingReportQueue(
        store: PendingReportStore(db),
        photosDir: () async => Directory('${tmp.path}/docs'),
      );

  group('cola de un solo reporte', () {
    test('un segundo reporte sin reemplazo no se apila', () async {
      final queue = newQueue();
      await queue.enqueue(_report(id: 'a'));
      await expectLater(queue.enqueue(_report(id: 'b')), throwsA(isA<PendingReportExistsException>()));
      expect(queue.pending!.clienteId, 'a');
    });

    test('reemplazar deja una sola fila y borra la foto anterior; la foto se copia', () async {
      final queue = newQueue();
      await queue.enqueue(_report(id: 'a'), photoPath: photo.path);
      final firstCopy = queue.pending!.photoPath!;
      expect(firstCopy, isNot(photo.path));
      expect(File(firstCopy).existsSync(), isTrue);

      await queue.enqueue(_report(id: 'b', text: 'otro'), replace: true);
      expect(File(firstCopy).existsSync(), isFalse);
      final rows = await (await db.database).query('pending_report');
      expect(rows, hasLength(1));
      expect(rows.single['cliente_id'], 'b');

      // sobrevive a reabrir la app
      final again = newQueue();
      await again.load();
      expect(again.pending!.description, 'otro');
    });

    test('descartar borra la fila y la foto local', () async {
      final queue = newQueue();
      await queue.enqueue(_report(), photoPath: photo.path);
      final copy = queue.pending!.photoPath!;
      await queue.discard();
      expect(queue.hasPending, isFalse);
      expect(File(copy).existsSync(), isFalse);
      expect(await (await db.database).query('pending_report'), isEmpty);
    });

    test('la BD no puede tener dos filas (id fijo)', () async {
      final store = PendingReportStore(db);
      await store.save(PendingReport.fromRow(_row('a')));
      await store.save(PendingReport.fromRow(_row('b')));
      expect(await (await db.database).query('pending_report'), hasLength(1));
    });

    test('si la BD falla la cola degrada sin lanzar', () async {
      final broken = LocalDatabase(factory: databaseFactoryFfi, path: '/ruta/que/no/existe/x.db');
      final queue = PendingReportQueue(store: PendingReportStore(broken));
      await queue.load();
      expect(await queue.enqueue(_report()), isNull);
      expect(queue.hasPending, isFalse);
    });
  });

  group('backoff', () {
    test('30 s, 1, 2, 4 min... con tope de 15 min', () {
      final values = [for (var i = 0; i < 10; i++) PendingReportSender.backoff(i)];
      expect(values.take(4), [
        const Duration(seconds: 30),
        const Duration(minutes: 1),
        const Duration(minutes: 2),
        const Duration(minutes: 4),
      ]);
      for (var i = 1; i < values.length; i++) {
        expect(values[i] >= values[i - 1], isTrue);
      }
      expect(values.last, const Duration(minutes: 15));
      expect(PendingReportSender.backoff(1000), const Duration(minutes: 15));
    });

    test('el jitter varía ±20 % y nunca pasa del tope', () {
      expect(PendingReportSender.backoff(0, random: _FixedRandom(0)), const Duration(seconds: 24));
      expect(PendingReportSender.backoff(0, random: _FixedRandom(1)), const Duration(seconds: 36));
      expect(PendingReportSender.backoff(9, random: _FixedRandom(1)), const Duration(minutes: 15));
    });

    test('al volver la conectividad el backoff se reinicia', () async {
      final queue = newQueue();
      await queue.enqueue(_report());
      await queue.update(queue.pending!.copyWith(attempts: 5));
      final repo = _Repo()..health.add(_net);
      final sender = PendingReportSender(queue: queue, repository: repo, connectivity: FakeConnectivityService());
      await sender.onConnectivityRestored();
      // se reinició a 0 y el intento (con la API caída) cuenta como el primero
      expect(queue.pending!.attempts, 1);
    });
  });

  group('formulario: encolar o no', () {
    ReportFormController controllerFor(_Repo repo, PendingReportQueue queue) => ReportFormController(
          repository: repo,
          locationService: SimulatedLocationService(),
          photoService: SimulatedPhotoService(),
          queue: queue,
        );

    Future<ReportFormController> filled(_Repo repo, PendingReportQueue queue, [String text = 'Agua']) async {
      final c = controllerFor(repo, queue);
      addTearDown(c.dispose);
      await c.useMyLocation();
      c.descriptionController.text = text;
      return c;
    }

    test('un fallo de red encola con cliente_id y limpia el formulario', () async {
      final queue = newQueue();
      final repo = _Repo()..submits.add(_net);
      final c = await filled(repo, queue);
      final result = await c.submit();
      expect(result.queued, isTrue);
      expect(queue.pending!.clienteId, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(c.descriptionController.text, isEmpty);
    });

    test('un 4xx de validación NO encola y se muestra al usuario', () async {
      final queue = newQueue();
      final repo = _Repo()..submits.add(_invalid);
      final c = await filled(repo, queue);
      await expectLater(c.submit(), throwsA(isA<RepositoryException>()));
      expect(queue.hasPending, isFalse);
      expect(c.descriptionController.text, 'Agua');
    });

    test('con un pendiente y otro envío sin red: pide decidir; reemplazar lo sustituye', () async {
      final queue = newQueue();
      final repo = _Repo()..submits.addAll([_net, _net, _net]);
      final c1 = await filled(repo, queue, 'primero');
      await c1.submit();
      final c2 = await filled(repo, queue, 'segundo');
      await expectLater(c2.submit(), throwsA(isA<PendingReportExistsException>()));
      expect(queue.pending!.description, 'primero');
      expect(c2.descriptionController.text, 'segundo');
      final result = await c2.submit(replacePending: true);
      expect(result.queued, isTrue);
      expect(queue.pending!.description, 'segundo');
    });

    test('el reintento del mismo contenido conserva el cliente_id', () async {
      final queue = newQueue();
      final repo = _Repo()..submits.add(_invalid);
      final c = await filled(repo, queue);
      await expectLater(c.submit(), throwsA(isA<RepositoryException>()));
      await c.submit();
      expect(repo.attemptedIds, hasLength(2));
      expect(repo.attemptedIds.first, isNotNull);
      expect(repo.attemptedIds.first, repo.attemptedIds.last);
    });
  });

  group('reenvío', () {
    Future<(PendingReportQueue, _Repo, PendingReportSender, List<String>)> setUpSender({
      String? photoPath,
    }) async {
      final queue = newQueue();
      await queue.enqueue(_report(id: 'uuid-fijo'), photoPath: photoPath);
      final repo = _Repo();
      final sent = <String>[];
      final sender = PendingReportSender(
        queue: queue,
        repository: repo,
        connectivity: FakeConnectivityService(),
        onSent: () => sent.add('refresh'),
      );
      final notices = <String>[];
      sender.notices.listen(notices.add);
      addTearDown(sender.dispose);
      return (queue, repo, sender, notices);
    }

    test('reenvía con el MISMO cliente_id, borra el pendiente y avisa', () async {
      final (queue, repo, sender, notices) = await setUpSender();
      repo.submits.add(_net); // 1er intento: sigue sin red
      await sender.attempt(force: true);
      expect(queue.pending!.status, PendingStatus.waiting);
      expect(queue.pending!.attempts, 1);
      expect(queue.pending!.nextAttempt, isNotNull);

      await sender.attempt(force: true);
      expect(repo.submitted.single.clienteId, 'uuid-fijo');
      expect(queue.hasPending, isFalse);
      expect(queue.lastSentFolio, 'AV-9');
      await Future<void>.delayed(Duration.zero);
      expect(notices, contains('Tu reporte fue enviado'));
    });

    test('si la API no responde (health) no se sube la foto', () async {
      final (queue, repo, sender, _) = await setUpSender(photoPath: photo.path);
      repo.health.add(_net);
      await sender.attempt(force: true);
      expect(repo.uploads, 0);
      expect(queue.hasPending, isTrue);
    });

    test('un solo envío en vuelo a la vez', () async {
      final (_, repo, sender, _) = await setUpSender();
      await Future.wait([sender.attempt(force: true), sender.attempt(force: true), sender.attempt(force: true)]);
      expect(repo.healthChecks, 1);
    });

    test('foto sube y luego el reporte lleva foto_url; se borra la copia local', () async {
      final (queue, repo, sender, _) = await setUpSender(photoPath: photo.path);
      final copy = queue.pending!.photoPath!;
      await sender.attempt(force: true);
      expect(repo.submitted.single.photoUrl, 'http://x/foto.jpg');
      expect(File(copy).existsSync(), isFalse);
    });

    test('la foto falla 3 veces seguidas: se envía el reporte SIN foto y se avisa', () async {
      final (queue, repo, sender, notices) = await setUpSender(photoPath: photo.path);
      repo.upload.addAll([_net, _net, _net]);
      await sender.attempt(force: true);
      await sender.attempt(force: true);
      expect(repo.submitted, isEmpty);
      expect(queue.pending!.photoFailures, 2);
      await sender.attempt(force: true);
      expect(repo.uploads, 3);
      expect(repo.submitted.single.photoUrl, isNull);
      expect(repo.submitted.single.clienteId, 'uuid-fijo');
      expect(queue.hasPending, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(notices.any((n) => n.contains('sin ella')), isTrue);
    });

    test('un 4xx en el reintento marca fallido y no se reintenta', () async {
      final (queue, repo, sender, notices) = await setUpSender();
      repo.submits.add(_invalid);
      await sender.attempt(force: true);
      expect(queue.pending!.status, PendingStatus.failed);
      expect(queue.pending!.error, isNotNull);
      final checks = repo.healthChecks;
      await sender.attempt(force: true);
      expect(repo.healthChecks, checks);
      await Future<void>.delayed(Duration.zero);
      expect(notices, isNotEmpty);
    });
  });

  group('API: cliente_id y duplicados', () {
    test('envía cliente_id y un 200 por duplicado cuenta como éxito', () async {
      late Map<String, dynamic> body;
      final repo = ApiReportRepository(
        baseUrl: 'http://api.test',
        client: MockClient((r) async {
          body = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'id': 15}), 200, headers: {'content-type': 'application/json'});
        }),
      );
      final folio = await repo.submit(_report(id: 'uuid-x'));
      expect(folio, 'AV-15');
      expect(body['cliente_id'], 'uuid-x');
    });

    test('5xx y caídas son reintentables; 422 no', () async {
      ApiReportRepository withStatus(int code) => ApiReportRepository(
            baseUrl: 'http://api.test',
            client: MockClient((r) async => http.Response('{}', code)),
          );
      await expectLater(
        withStatus(503).submit(_report()),
        throwsA(isA<RepositoryException>().having((e) => e.retryable, 'retryable', isTrue)),
      );
      await expectLater(
        withStatus(422).submit(_report()),
        throwsA(isA<RepositoryException>().having((e) => e.retryable, 'retryable', isFalse)),
      );
      final down = ApiReportRepository(
        baseUrl: 'http://api.test',
        client: MockClient((r) async => throw const SocketException('x')),
      );
      await expectLater(
        down.submit(_report()),
        throwsA(isA<RepositoryException>().having((e) => e.retryable, 'retryable', isTrue)),
      );
    });
  });

  group('caché offline', () {
    Map<String, dynamic> alertRow() => {
          'id': 7,
          'tipo': 'inundacion',
          'nivel': 'alto',
          'texto': 'Lluvia intensa',
          'motivo': 'lluvia',
          'simulada': false,
          'aprobada_en': '2026-11-11T22:15:00Z',
          'colonia_id': 4,
          'guia': {
            'titulo': 'Qué hacer ante una inundación',
            'pasos': ['Sube a un lugar alto', 'Corta la luz'],
          },
        };

    ApiReportRepository build(bool Function() online, OfflineCache cache) => ApiReportRepository(
          baseUrl: 'http://api.test',
          cache: cache,
          client: MockClient((r) async {
            if (!online()) throw const SocketException('sin red');
            Object body;
            switch (r.url.path) {
              case '/alerts/active':
                body = [alertRow()];
              case '/zones':
                body = [
                  {'id': 4, 'nombre': 'C.P. 91700'},
                ];
              case '/zones/risk':
                body = {
                  'type': 'FeatureCollection',
                  'features': [
                    {'type': 'Feature', 'properties': {'nivel': 'alto'}, 'geometry': null},
                  ],
                };
              case '/reports':
                body = [
                  {
                    'id': 15,
                    'categoria': 'inundacion',
                    'lat': 19.19,
                    'lon': -96.13,
                    'descripcion': 'x',
                    'colonia_id': 4,
                    'estado': 'activo',
                    'creado_en': '2026-11-11T22:15:00Z',
                  },
                ];
              default:
                body = {};
            }
            return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
          }),
        );

    test('las alertas se guardan con red y se leen sin red, con su guía', () async {
      var online = true;
      final cache = OfflineCache(db);
      final repo = build(() => online, cache);
      final active = await repo.getActiveAlertsAt(lat: 19.19, lon: -96.13);
      expect(active.single.steps, hasLength(2));
      expect(repo.alertsStaleSince, isNull);

      online = false;
      final offline = build(() => online, cache); // app reiniciada sin red
      final items = await offline.getCurrentAlerts();
      expect(items.single.recommendations, ['Sube a un lugar alto', 'Corta la luz']);
      expect(items.single.detail, 'Lluvia intensa');
      expect(offline.alertsStaleSince, isNotNull);
      // el vigilante NO recibe alertas cacheadas: sin red lanza
      await expectLater(
        offline.getActiveAlertsAt(lat: 19.19, lon: -96.13),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('se guardan solo las 10 alertas más graves', () async {
      final cache = OfflineCache(db);
      await cache.saveAlerts([
        for (var i = 1; i <= 15; i++)
          ActiveAlert(id: i, type: ReportType.flood, level: i == 15 ? AlertLevel.critico : AlertLevel.bajo, text: 't$i'),
      ]);
      final loaded = (await cache.loadAlerts())!.value;
      expect(loaded, hasLength(10));
      expect(loaded.first.id, 15);
    });

    test('mapa: zonas, riesgo y reportes salen de la caché sin red, marcados como desactualizados', () async {
      var online = true;
      final cache = OfflineCache(db);
      final repo = build(() => online, cache);
      await repo.getMapReports();
      await repo.getRiskZones();
      expect(repo.mapStaleSince, isNull);
      await Future<void>.delayed(const Duration(milliseconds: 50)); // guardados sin await

      online = false;
      final offline = build(() => online, cache);
      final reports = await offline.getMapReports();
      final risk = await offline.getRiskZones();
      expect(reports.single.folio, 'AV-15');
      expect(reports.single.neighborhood, 'C.P. 91700'); // nombre de zona cacheado
      expect((risk['features'] as List), hasLength(1));
      expect(offline.mapStaleSince, isNotNull);
    });

    test('sin red y sin caché el error sigue llegando a la UI', () async {
      final repo = build(() => false, OfflineCache(db));
      await expectLater(repo.getRiskZones(), throwsA(isA<RepositoryException>()));
    });
  });
}

Map<String, Object?> _row(String id) => {
      'id': 1,
      'cliente_id': id,
      'categoria': 'inundacion',
      'severidad': 2,
      'lat': 19.1,
      'lon': -96.1,
      'descripcion': 'd',
      'direccion': '',
      'foto_path': null,
      'foto_url': null,
      'foto_fallos': 0,
      'creado_en': 0,
      'intentos': 0,
      'proximo_intento': null,
      'estado': 'waiting',
      'error': null,
    };
