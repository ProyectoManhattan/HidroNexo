import 'dart:convert';

import 'package:agua_lluvia/data/api_report_repository.dart';
import 'package:agua_lluvia/data/mock_report_repository.dart';
import 'package:agua_lluvia/data/report_repository.dart';
import 'package:agua_lluvia/models/active_alert.dart';
import 'package:agua_lluvia/models/report_type.dart';
import 'package:agua_lluvia/screens/citizen/alert_full_screen.dart';
import 'package:agua_lluvia/services/active_alert_watcher.dart';
import 'package:agua_lluvia/services/location_service.dart';
import 'package:agua_lluvia/services/seen_alerts_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ActiveAlert alert(int id, AlertLevel level, {DateTime? at}) => ActiveAlert(
      id: id,
      type: ReportType.flood,
      level: level,
      text: 'Texto $id',
      approvedAt: at ?? DateTime.now(),
    );

class FakeRepo extends MockReportRepository {
  List<ActiveAlert> alerts = [];
  bool fail = false;
  int calls = 0;
  double? lastLat;

  @override
  Future<List<ActiveAlert>> getActiveAlertsAt({required double lat, required double lon}) async {
    calls++;
    lastLat = lat;
    if (fail) throw const RepositoryException('Sin conexión');
    return alerts;
  }
}

class NoLocation implements LocationService {
  @override
  Future<UserLocation> getCurrentLocation({bool requestPermission = true}) async =>
      throw const LocationException('sin permiso');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ActiveAlertWatcher build(FakeRepo repo, {SeenAlertsStore? store, LocationService? loc}) =>
      ActiveAlertWatcher(
        repository: repo,
        locationService: loc ?? SimulatedLocationService(),
        store: store,
      );

  test('detecta alertas nuevas y las ordena por gravedad', () async {
    final repo = FakeRepo()
      ..alerts = [
        alert(1, AlertLevel.bajo),
        alert(2, AlertLevel.critico),
        alert(3, AlertLevel.alto),
      ];
    final w = build(repo);
    await w.refresh();
    expect(w.pending.map((a) => a.id), [2, 3, 1]);
    // Una segunda consulta no duplica.
    await w.refresh();
    expect(w.pending.length, 3);
  });

  test('una alerta confirmada no reaparece, ni tras reiniciar (persistencia)', () async {
    final store = MemorySeenAlertsStore();
    final repo = FakeRepo()..alerts = [alert(1, AlertLevel.alto), alert(2, AlertLevel.medio)];
    final w = build(repo, store: store);
    await w.refresh();
    await w.markSeen(1);
    expect(w.pending.map((a) => a.id), [2]);
    await w.refresh();
    expect(w.pending.map((a) => a.id), [2]);

    final w2 = build(repo, store: store); // "reabrir la app"
    await w2.refresh();
    expect(w2.pending.map((a) => a.id), [2]);
  });

  test('ignora alertas de más de 12 h', () async {
    final repo = FakeRepo()
      ..alerts = [alert(1, AlertLevel.alto, at: DateTime.now().subtract(const Duration(hours: 13)))];
    final w = build(repo);
    await w.refresh();
    expect(w.pending, isEmpty);
  });

  test('un fallo de red no rompe el watcher y se recupera', () async {
    final repo = FakeRepo()
      ..fail = true
      ..alerts = [alert(1, AlertLevel.alto)];
    final w = build(repo);
    await w.refresh();
    expect(w.pending, isEmpty);
    repo.fail = false;
    await w.refresh();
    expect(w.pending.map((a) => a.id), [1]);
  });

  test('sin ubicación no consulta', () async {
    final repo = FakeRepo()..alerts = [alert(1, AlertLevel.alto)];
    final w = build(repo, loc: NoLocation());
    await w.refresh();
    expect(repo.calls, 0);
    expect(w.pending, isEmpty);
  });

  test('requestShow abre una alerta ya vista y devuelve false si no existe', () async {
    final repo = FakeRepo()..alerts = [alert(1, AlertLevel.alto)];
    final w = build(repo);
    await w.refresh();
    await w.markSeen(1);
    expect(await w.requestShow(1), isTrue);
    expect(w.pending.map((a) => a.id), [1]);
    expect(await w.requestShow(99), isFalse);
  });

  test('ordena por gravedad y luego por recencia', () {
    final now = DateTime.now();
    final list = [
      alert(1, AlertLevel.medio, at: now),
      alert(2, AlertLevel.medio, at: now.add(const Duration(minutes: 5))),
      alert(3, AlertLevel.critico, at: now.subtract(const Duration(hours: 2))),
    ]..sort(ActiveAlert.compareBySeverity);
    expect(list.map((a) => a.id), [3, 2, 1]);
  });

  test('ApiReportRepository envía lat/lon y parsea la guía', () async {
    late Uri captured;
    final client = MockClient((request) async {
      if (request.url.path == '/zones') {
        return http.Response(jsonEncode([{'id': 4, 'nombre': 'Col. Centro'}]), 200);
      }
      captured = request.url;
      return http.Response(
        utf8.decode(utf8.encode(jsonEncode([
          {
            'id': 7,
            'colonia_id': 4,
            'tipo': 'inundacion',
            'nivel': 'critico',
            'motivo': 'lluvia',
            'texto': 'Hay riesgo',
            'estado': 'aprobada',
            'simulada': true,
            'aprobada_en': '2026-11-11T22:17:00Z',
            'guia': {'titulo': 'Qué hacer', 'pasos': ['Uno', 'Dos']},
          },
          {'id': 8, 'tipo': 'fuga', 'nivel': 'bajo', 'texto': 'x', 'guia': null},
        ]))),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final repo = ApiReportRepository(client: client, baseUrl: 'http://x');
    final list = await repo.getActiveAlertsAt(lat: 19.19, lon: -96.13);
    expect(captured.path, '/alerts/active');
    expect(captured.queryParameters, {'lat': '19.19', 'lon': '-96.13'});
    expect(list.length, 2);
    expect(list[0].level, AlertLevel.critico);
    expect(list[0].simulated, isTrue);
    expect(list[0].zoneName, 'Col. Centro');
    expect(list[0].steps, ['Uno', 'Dos']);
    expect(list[1].steps, isEmpty);
    expect(list[1].zoneName, isNull);
  });

  testWidgets('AlertFullScreen: atrás no cierra; Enterado sí y confirma', (tester) async {
    var acked = false;
    final a = ActiveAlert(
      id: 1,
      type: ReportType.flood,
      level: AlertLevel.critico,
      text: 'Texto de prueba',
      zoneName: 'Col. Centro',
      simulated: true,
      steps: const ['Paso uno', 'Paso dos'],
    );
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      home: const Scaffold(body: Text('base')),
    ));
    key.currentState!.push(AlertFullScreen.route(a, onAcknowledge: () => acked = true));
    await tester.pumpAndSettle();
    expect(find.text('SIMULACIÓN'), findsOneWidget);
    expect(find.text('Paso uno'), findsOneWidget);
    expect(find.textContaining('911'), findsOneWidget);

    await tester.binding.handlePopRoute(); // botón atrás
    await tester.pumpAndSettle();
    expect(find.text('Enterado'), findsOneWidget);

    await tester.tap(find.text('Enterado'));
    await tester.pumpAndSettle();
    expect(acked, isTrue);
    expect(find.text('Enterado'), findsNothing);
    expect(find.text('base'), findsOneWidget);
  });
}
