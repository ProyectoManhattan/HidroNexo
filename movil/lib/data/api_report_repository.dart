import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';
import '../models/alert_item.dart';
import '../models/coordinates.dart';
import '../models/incident_report.dart';
import '../models/new_report.dart';
import '../models/report_status.dart';
import '../models/report_type.dart';
import 'report_repository.dart';

/// Implementación contra el backend FastAPI (ver docs/api.md).
class ApiReportRepository implements ReportRepository {
  ApiReportRepository({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? AppConfig.apiUrl).replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  /// id de zona → nombre. Se pide una vez y se conserva.
  Map<int, String>? _zones;

  /// Prefijo de los folios que ve el ciudadano: el reporte 15 es `AV-15`.
  static const String folioPrefix = 'AV-';

  // ---- Lectura ----

  @override
  Future<List<IncidentReport>> getMapReports() async {
    final zones = await _zoneNames();
    final rows = await _getList('/reports');
    return rows.map((r) => _toReport(r, zones)).toList();
  }

  @override
  Future<Map<String, dynamic>> getRiskZones() async {
    final data = await _send(() => _client.get(_uri('/zones/risk')));
    if (data is! Map<String, dynamic> || data['features'] is! List) {
      throw const RepositoryException('Respuesta inesperada del servidor.');
    }
    return data;
  }

  @override
  Future<List<AlertItem>> getCurrentAlerts() async {
    final rows = await _getList('/alerts/active');
    return rows.map(_toAlert).toList();
  }

  @override
  Future<List<AlertItem>> getAlertHistory() async {
    final zones = await _zoneNames();
    final rows = await _getList('/reports', query: {'activos': 'false'});
    return rows
        .where((r) => r['estado'] == 'resuelto')
        .map((r) => _toReport(r, zones))
        .map(
          (r) => AlertItem(
            title: '${r.type.label} atendida',
            detail: '${r.address} · ${r.description}',
            meta: '${r.dateLabel} · ${r.folio}',
            type: r.type,
            status: r.status,
          ),
        )
        .toList();
  }

  @override
  Future<IncidentReport?> findByFolio(String folio) async {
    final id = parseFolio(folio);
    if (id == null) return null;
    final zones = await _zoneNames();
    final rows = await _getList('/reports', query: {'activos': 'false'});
    for (final row in rows) {
      if (row['id'] == id) return _toReport(row, zones);
    }
    return null;
  }

  // ---- Escritura ----

  @override
  Future<String> submit(NewReport report) async {
    final body = jsonEncode({
      'categoria': report.type.apiKey,
      'severidad': report.severity,
      'lat': report.position.latitude,
      'lon': report.position.longitude,
      'descripcion': report.description,
    });
    final data = await _send(
      () => _client.post(
        _uri('/reports'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ),
    );
    final id = (data is Map ? data['id'] : null) as int?;
    if (id == null) throw const RepositoryException('Respuesta inesperada del servidor.');
    return '$folioPrefix$id';
  }

  @override
  Future<void> registerDevice({
    required String token,
    required double lat,
    required double lon,
  }) async {
    final body = jsonEncode({
      'token': token,
      'plataforma': 'android',
      'colonia_id': null,
      'lat': lat,
      'lon': lon,
    });
    await _send(
      () => _client.post(
        _uri('/devices'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ),
    );
  }

  // ---- Conversión ----

  /// `AV-15`, `av-15` o `15` → 15. Null si no es un folio válido.
  static int? parseFolio(String folio) {
    final match = RegExp(r'^(?:AV-)?(\d+)$', caseSensitive: false).firstMatch(folio.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static ReportStatus _statusOf(String? estado) =>
      estado == 'resuelto' ? ReportStatus.attended : ReportStatus.pending;

  IncidentReport _toReport(Map<String, dynamic> row, Map<int, String> zones) {
    final zone = zones[row['colonia_id']] ?? 'Fuera de las zonas registradas';
    return IncidentReport(
      folio: '$folioPrefix${row['id']}',
      type: ReportTypeApi.fromApi(row['categoria'] as String?),
      neighborhood: zone,
      address: zone,
      description: (row['descripcion'] as String?)?.trim().isNotEmpty == true
          ? row['descripcion'] as String
          : 'Sin descripción.',
      dateLabel: _dateLabel(row['creado_en'] as String?),
      status: _statusOf(row['estado'] as String?),
      position: Coordinates(
        (row['lat'] as num).toDouble(),
        (row['lon'] as num).toDouble(),
      ),
      photoUrl: row['foto_url'] as String?,
    );
  }

  AlertItem _toAlert(Map<String, dynamic> row) {
    final type = ReportTypeApi.fromApi(row['tipo'] as String?);
    final guide = row['guia'];
    final steps = guide is Map && guide['pasos'] is List
        ? (guide['pasos'] as List).map((p) => '$p').toList()
        : type.tips;
    final level = '${row['nivel'] ?? ''}';
    return AlertItem(
      title: level.isEmpty ? type.alertTitle : '${type.alertTitle} · riesgo $level',
      detail: '${row['texto'] ?? ''}',
      meta: _dateLabel((row['aprobada_en'] ?? row['creada_en']) as String?),
      type: type,
      status: ReportStatus.accepted,
      recommendations: steps,
    );
  }

  /// "11 nov 2026, 16:15" en hora local; vacío si la fecha no es válida.
  static String _dateLabel(String? iso) {
    final date = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (date == null) return '';
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)} ${months[date.month - 1]} ${date.year}, ${two(date.hour)}:${two(date.minute)}';
  }

  // ---- HTTP ----

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  Future<Map<int, String>> _zoneNames() async {
    final cached = _zones;
    if (cached != null) return cached;
    try {
      final rows = await _getList('/zones');
      return _zones = {for (final z in rows) z['id'] as int: '${z['nombre']}'};
    } on RepositoryException {
      return const {}; // sin nombres de zona la app sigue funcionando
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String path, {Map<String, String>? query}) async {
    final data = await _send(() => _client.get(_uri(path, query)));
    if (data is! List) throw const RepositoryException('Respuesta inesperada del servidor.');
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(AppConfig.apiTimeout);
      if (response.statusCode >= 400) {
        throw RepositoryException(_errorMessage(response));
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw const RepositoryException('El servidor tardó demasiado en responder.');
    } on SocketException {
      throw const RepositoryException('Sin conexión con el servidor. Revisa tu internet.');
    } on http.ClientException {
      throw const RepositoryException('Sin conexión con el servidor. Revisa tu internet.');
    } on FormatException {
      throw const RepositoryException('Respuesta inesperada del servidor.');
    }
  }

  static String _errorMessage(http.Response response) {
    if (response.statusCode == 422) return 'Revisa los datos del reporte e inténtalo de nuevo.';
    if (response.statusCode >= 500) return 'El servidor tuvo un problema. Inténtalo más tarde.';
    return 'No se pudo completar la solicitud (${response.statusCode}).';
  }
}
