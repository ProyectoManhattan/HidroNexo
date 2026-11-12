import 'dart:convert';

import 'package:agua_lluvia/core/utils/geo.dart';
import 'package:agua_lluvia/data/api_report_repository.dart';
import 'package:agua_lluvia/models/coordinates.dart';
import 'package:agua_lluvia/services/push_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const a = Coordinates(19.1903, -96.1342);

  test('distanceMeters: ~111 m por 0.001 grados de latitud', () {
    final d = distanceMeters(a, const Coordinates(19.1913, -96.1342));
    expect(d, closeTo(111, 2));
    expect(distanceMeters(a, a), 0);
  });

  test('shouldResendLocation respeta el umbral de 300 m', () {
    expect(shouldResendLocation(null, a), isTrue);
    expect(shouldResendLocation(a, const Coordinates(19.1913, -96.1342)), isFalse); // ~111 m
    expect(shouldResendLocation(a, const Coordinates(19.1940, -96.1342)), isTrue); // ~411 m
    expect(shouldResendLocation(a, const Coordinates(19.1940, -96.1342), thresholdMeters: 500), isFalse);
  });

  test('PushTap.fromData lee alerta_id, tipo y nivel', () {
    final tap = PushTap.fromData({'alerta_id': '42', 'tipo': 'inundacion', 'nivel': 'alto'});
    expect(tap.alertId, 42);
    expect(tap.tipo, 'inundacion');
    expect(tap.nivel, 'alto');
    expect(PushTap.fromData({}).alertId, isNull);
  });

  test('registerDevice hace POST /devices con el contrato esperado', () async {
    late http.Request sent;
    final repo = ApiReportRepository(
      baseUrl: 'http://api.test',
      client: MockClient((r) async {
        sent = r;
        return http.Response(
            jsonEncode({'id': 1, 'colonia_id': 4, 'plataforma': 'android'}), 200);
      }),
    );
    await repo.registerDevice(token: 'tok', lat: 19.19, lon: -96.13);
    expect(sent.method, 'POST');
    expect(sent.url.path, '/devices');
    expect(jsonDecode(sent.body), {
      'token': 'tok',
      'plataforma': 'android',
      'colonia_id': null,
      'lat': 19.19,
      'lon': -96.13,
    });
  });
}
