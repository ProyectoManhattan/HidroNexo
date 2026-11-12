import 'dart:convert';
import 'dart:io';

import 'package:agua_lluvia/data/api_report_repository.dart';
import 'package:agua_lluvia/data/report_repository.dart';
import 'package:agua_lluvia/models/coordinates.dart';
import 'package:agua_lluvia/models/new_report.dart';
import 'package:agua_lluvia/models/report_status.dart';
import 'package:agua_lluvia/models/report_type.dart';
import 'package:agua_lluvia/services/photo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _report(int id, {String estado = 'activo', String categoria = 'inundacion'}) => {
      'id': id,
      'categoria': categoria,
      'severidad': 3,
      'lat': 19.19,
      'lon': -96.13,
      'descripcion': 'El agua ya entró',
      'foto_url': null,
      'colonia_id': 4,
      'origen': 'app',
      'estado': estado,
      'creado_en': '2026-11-11T22:15:00Z',
      'expira_en': '2026-11-12T04:15:00Z',
    };

void main() {
  late List<http.Request> requests;

  ApiReportRepository build(http.Response Function(http.Request) handler) {
    requests = [];
    return ApiReportRepository(
      baseUrl: 'http://api.test/',
      client: MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
    );
  }

  http.Response routes(http.Request r) {
    switch (r.url.path) {
      case '/zones':
        return _json([{'id': 4, 'nombre': 'C.P. 91700', 'municipio': 'Veracruz'}]);
      case '/reports':
        return r.url.queryParameters['activos'] == 'false'
            ? _json([_report(15), _report(16, estado: 'resuelto', categoria: 'fuga')])
            : _json([_report(15)]);
      case '/alerts/active':
        return _json([
          {
            'id': 7,
            'tipo': 'inundacion',
            'nivel': 'alto',
            'texto': 'Riesgo alto de inundación',
            'creada_en': '2026-11-11T22:15:00Z',
            'aprobada_en': '2026-11-11T22:17:00Z',
            'guia': {'titulo': 'Qué hacer', 'pasos': ['Sube a un lugar alto', 'Corta la luz']},
          },
          {'id': 8, 'tipo': 'desconocido', 'nivel': 'medio', 'texto': 'Sin guía', 'creada_en': '2026-11-11T22:15:00Z'},
        ]);
    }
    return http.Response('no existe', 404);
  }

  test('lista reportes del mapa con nombre de zona y folio AV-<id>', () async {
    final repo = build(routes);
    final reports = await repo.getMapReports();
    expect(reports, hasLength(1));
    expect(reports.first.folio, 'AV-15');
    expect(reports.first.type, ReportType.flood);
    expect(reports.first.neighborhood, 'C.P. 91700');
    expect(reports.first.status, ReportStatus.pending);
    expect(reports.first.position.latitude, 19.19);
  });

  test('las zonas se piden una sola vez', () async {
    final repo = build(routes);
    await repo.getMapReports();
    await repo.getMapReports();
    expect(requests.where((r) => r.url.path == '/zones'), hasLength(1));
  });

  test('alertas actuales usan la guía de la API y, sin guía, las del tipo', () async {
    final alerts = await build(routes).getCurrentAlerts();
    expect(alerts, hasLength(2));
    expect(alerts[0].recommendations, ['Sube a un lugar alto', 'Corta la luz']);
    expect(alerts[0].title, contains('riesgo alto'));
    expect(alerts[1].recommendations, ReportType.flood.tips); // tipo desconocido → inundación
  });

  test('el historial solo trae reportes resueltos', () async {
    final history = await build(routes).getAlertHistory();
    expect(history, hasLength(1));
    expect(history.first.type, ReportType.leak);
    expect(history.first.status, ReportStatus.attended);
  });

  test('busca por folio sin importar mayúsculas ni el prefijo', () async {
    final repo = build(routes);
    expect((await repo.findByFolio(' av-16 '))?.type, ReportType.leak);
    expect((await repo.findByFolio('15'))?.folio, 'AV-15');
    expect(await repo.findByFolio('AV-999'), isNull);
    expect(await repo.findByFolio('hola'), isNull);
  });

  test('envía el reporte con los campos que espera la API y devuelve el folio', () async {
    final repo = build((r) => r.method == 'POST' ? _json(_report(21), 201) : routes(r));
    final folio = await repo.submit(const NewReport(
      type: ReportType.pooling,
      neighborhood: 'Mi ubicación',
      address: 'Mi ubicación',
      position: Coordinates(19.1745, -96.1342),
      description: 'Calle encharcada',
      severity: 3,
    ));
    expect(folio, 'AV-21');
    final post = requests.singleWhere((r) => r.method == 'POST');
    expect(post.url.path, '/reports');
    expect(jsonDecode(post.body), {
      'categoria': 'encharcamiento',
      'severidad': 3,
      'lat': 19.1745,
      'lon': -96.1342,
      'descripcion': 'Calle encharcada',
    });
  });

  test('los errores del servidor llegan como RepositoryException con mensaje legible', () async {
    final repo = build((_) => http.Response('{"detail":"x"}', 422));
    await expectLater(
      repo.submit(const NewReport(
        type: ReportType.flood,
        neighborhood: '',
        address: '',
        position: Coordinates(0, 0),
        description: 'x',
        severity: 1,
      )),
      throwsA(isA<RepositoryException>().having((e) => e.message, 'message', contains('Revisa los datos'))),
    );
    await expectLater(build((_) => http.Response('', 500)).getMapReports(), throwsA(isA<RepositoryException>()));
  });

  test('sin red se lanza RepositoryException, no una excepción cruda', () async {
    final repo = ApiReportRepository(
      baseUrl: 'http://api.test',
      client: MockClient((_) async => throw http.ClientException('sin red')),
    );
    await expectLater(repo.getCurrentAlerts(), throwsA(isA<RepositoryException>()));
  });

  test('sin nombres de zona la app sigue funcionando', () async {
    final repo = build((r) => r.url.path == '/zones' ? http.Response('', 500) : routes(r));
    final reports = await repo.getMapReports();
    expect(reports.first.neighborhood, contains('Fuera de las zonas'));
  });

  test('las 5 categorías de la API tienen tipo en la app', () {
    const categorias = ['inundacion', 'encharcamiento', 'alcantarilla', 'fuga', 'sin_agua'];
    expect(ReportType.values.map((t) => t.apiKey).toSet(), categorias.toSet());
  });

  test('getRiskZones devuelve el GeoJSON de /zones/risk', () async {
    final repo = build((r) => _json({'type': 'FeatureCollection', 'features': []}));
    final zones = await repo.getRiskZones();
    expect(requests.single.url.path, '/zones/risk');
    expect(zones['features'], isEmpty);
  });

  test('getRiskZones falla si la respuesta no es un GeoJSON', () async {
    final repo = build((r) => _json([1, 2]));
    expect(repo.getRiskZones(), throwsA(isA<RepositoryException>()));
  });

  group('fotos', () {
    late PickedPhoto photo;

    setUp(() {
      final dir = Directory.systemTemp.createTempSync('foto_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/evidencia.png')..writeAsBytesSync([1, 2, 3, 4]);
      photo = PickedPhoto(path: file.path, name: 'evidencia.png');
    });

    test('sube la foto por multipart con campo foto y content-type según la extensión', () async {
      final repo = build((_) => _json({'foto_url': 'http://api.test/media/a.png'}, 201));
      final url = await repo.uploadPhoto(photo);
      expect(url, 'http://api.test/media/a.png');
      final post = requests.single;
      expect(post.url.path, '/reports/photo');
      expect(post.headers['content-type'], startsWith('multipart/form-data'));
      expect(post.body, contains('name="foto"'));
      expect(post.body, contains('filename="evidencia.png"'));
      expect(post.body.toLowerCase(), contains('content-type: image/png'));
    });

    test('submit envía foto_url cuando hay foto subida', () async {
      final repo = build((_) => _json(_report(30), 201));
      await repo.submit(const NewReport(
        type: ReportType.flood,
        neighborhood: '',
        address: '',
        position: Coordinates(19.1, -96.1),
        description: 'x',
        severity: 1,
        photoUrl: 'http://api.test/media/a.png',
      ));
      expect(jsonDecode(requests.single.body)['foto_url'], 'http://api.test/media/a.png');
    });

    test('413, 415 y 503 dan mensajes claros', () async {
      for (final (code, text) in [(413, '5 MB'), (415, 'JPG, PNG o WebP'), (503, 'almacenamiento')]) {
        final repo = build((_) => http.Response('{"detail":"x"}', code));
        await expectLater(
          repo.uploadPhoto(photo),
          throwsA(isA<RepositoryException>().having((e) => e.message, 'message', contains(text))),
        );
      }
    });

    test('sin red al subir lanza RepositoryException', () async {
      final repo = ApiReportRepository(
        baseUrl: 'http://api.test',
        client: MockClient((_) async => throw http.ClientException('sin red')),
      );
      await expectLater(repo.uploadPhoto(photo), throwsA(isA<RepositoryException>()));
    });
  });
}
