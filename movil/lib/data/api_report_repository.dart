import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../core/constants/app_config.dart';
import '../models/active_alert.dart';
import '../models/alert_item.dart';
import '../models/coordinates.dart';
import '../models/incident_report.dart';
import '../models/new_report.dart';
import '../models/report_status.dart';
import '../models/report_type.dart';
import '../services/photo_service.dart';
import 'local/offline_cache.dart';
import 'report_repository.dart';

/// Implementación contra el backend FastAPI (ver docs/api.md).
class ApiReportRepository implements ReportRepository {
  ApiReportRepository({http.Client? client, String? baseUrl, OfflineCache? cache})
      : _client = client ?? http.Client(),
        _cache = cache,
        _baseUrl = (baseUrl ?? AppConfig.apiUrl).replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  /// Caché local; null = sin caché (pruebas o si la BD no está disponible).
  final OfflineCache? _cache;

  DateTime? _reportsStale;
  DateTime? _zonesStale;
  DateTime? _alertsStale;

  @override
  DateTime? get mapStaleSince {
    final a = _reportsStale, b = _zonesStale;
    if (a == null) return b;
    if (b == null) return a;
    return a.isBefore(b) ? a : b;
  }

  @override
  DateTime? get alertsStaleSince => _alertsStale;

  /// id de zona → nombre. Se pide una vez y se conserva.
  Map<int, String>? _zones;

  /// Prefijo de los folios que ve el ciudadano: el reporte 15 es `AV-15`.
  static const String folioPrefix = 'AV-';

  // ---- Lectura ----

  @override
  Future<List<IncidentReport>> getMapReports() async {
    final List<Map<String, dynamic>> rows;
    try {
      rows = await _getList('/reports');
    } on RepositoryException {
      final cached = await _cache?.loadReports();
      if (cached == null) rethrow;
      _reportsStale = cached.savedAt;
      final zones = await _zoneNames();
      return cached.value.map((r) => _toReport(r, zones)).toList();
    }
    _reportsStale = null;
    unawaited(_cache?.saveReports(rows));
    final zones = await _zoneNames();
    return rows.map((r) => _toReport(r, zones)).toList();
  }

  @override
  Future<Map<String, dynamic>> getRiskZones() async {
    try {
      final data = await _send(() => _client.get(_uri('/zones/risk')));
      if (data is! Map<String, dynamic> || data['features'] is! List) {
        throw const RepositoryException('Respuesta inesperada del servidor.');
      }
      _zonesStale = null;
      unawaited(_cache?.saveRiskZones(data));
      return data;
    } on RepositoryException {
      final cached = await _cache?.loadRiskZones();
      if (cached == null) rethrow;
      _zonesStale = cached.savedAt;
      return cached.value;
    }
  }

  @override
  Future<List<AlertItem>> getCurrentAlerts() async {
    final List<Map<String, dynamic>> rows;
    try {
      rows = await _getList('/alerts/active');
    } on RepositoryException {
      // Sin red: las últimas alertas vistas, con su guía de acción completa.
      final cached = await _cache?.loadAlerts();
      if (cached == null) rethrow;
      _alertsStale = cached.savedAt;
      return cached.value.map(_cachedToAlertItem).toList();
    }
    _alertsStale = null;
    return rows.map(_toAlert).toList();
  }

  AlertItem _cachedToAlertItem(ActiveAlert a) => AlertItem(
        title: '${a.type.alertTitle} · riesgo ${a.level.apiKey}',
        detail: a.text,
        meta: [
          if (a.zoneName != null) a.zoneName!,
          _dateLabel(a.approvedAt?.toIso8601String()),
        ].where((s) => s.isNotEmpty).join(' · '),
        type: a.type,
        status: ReportStatus.accepted,
        recommendations: a.steps.isEmpty ? a.type.tips : a.steps,
      );

  @override
  Future<List<ActiveAlert>> getActiveAlertsAt({required double lat, required double lon}) async {
    final rows = await _getList(
      '/alerts/active',
      query: {'lat': '$lat', 'lon': '$lon'},
    );
    final zones = await _zoneNames();
    final alerts = rows
        .map((row) => ActiveAlert.fromJson(row, zoneName: zones[row['colonia_id']]))
        .whereType<ActiveAlert>()
        .toList();
    // Solo con red llegamos aquí: se guarda para consultarlas sin conexión.
    // Esta consulta NO cae a la caché: una alerta nueva solo se detecta con red.
    unawaited(_cache?.saveAlerts(alerts));
    return alerts;
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
      if (report.photoUrl != null) 'foto_url': report.photoUrl,
      if (report.clienteId != null) 'cliente_id': report.clienteId,
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
  Future<String> uploadPhoto(PickedPhoto photo) async {
    final http.MultipartFile file;
    try {
      file = await http.MultipartFile.fromPath(
        'foto',
        photo.path,
        filename: photo.name,
        contentType: MediaType.parse(photo.mimeType),
      );
    } on FileSystemException {
      throw const RepositoryException('No se pudo leer la foto elegida.');
    }
    final data = await _send(
      () async {
        final request = http.MultipartRequest('POST', _uri('/reports/photo'))..files.add(file);
        return http.Response.fromStream(await _client.send(request));
      },
      errorMessage: _photoErrorMessage,
      timeout: AppConfig.uploadTimeout,
    );
    final url = (data is Map ? data['foto_url'] : null) as String?;
    if (url == null || url.isEmpty) {
      throw const RepositoryException('Respuesta inesperada del servidor.');
    }
    return url;
  }

  @override
  Future<void> checkHealth() async {
    await _send(() => _client.get(_uri('/health')));
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
      unawaited(_cache?.saveZones(rows));
      return _zones = {for (final z in rows) z['id'] as int: '${z['nombre']}'};
    } on RepositoryException {
      // Sin red: nombres guardados (sin fijarlos, para pedirlos de nuevo luego).
      final cached = await _cache?.loadZones();
      if (cached != null) return {for (final z in cached.value) z['id'] as int: '${z['nombre']}'};
      return const {}; // sin nombres de zona la app sigue funcionando
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String path, {Map<String, String>? query}) async {
    final data = await _send(() => _client.get(_uri(path, query)));
    if (data is! List) throw const RepositoryException('Respuesta inesperada del servidor.');
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<dynamic> _send(
    Future<http.Response> Function() request, {
    String Function(http.Response)? errorMessage,
    Duration timeout = AppConfig.apiTimeout,
  }) async {
    try {
      final response = await request().timeout(timeout);
      if (response.statusCode >= 400) {
        final code = response.statusCode;
        throw RepositoryException(
          (errorMessage ?? _errorMessage)(response),
          // 5xx, 408 y 429: reintentar luego puede funcionar. El resto de 4xx, no.
          retryable: code >= 500 || code == 408 || code == 429,
        );
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw const RepositoryException('El servidor tardó demasiado en responder.', retryable: true);
    } on SocketException {
      throw const RepositoryException('Sin conexión con el servidor. Revisa tu internet.', retryable: true);
    } on http.ClientException {
      throw const RepositoryException('Sin conexión con el servidor. Revisa tu internet.', retryable: true);
    } on FormatException {
      // Típico de un portal cautivo o un proxy que devuelve HTML.
      throw const RepositoryException('Respuesta inesperada del servidor.', retryable: true);
    }
  }

  static String _photoErrorMessage(http.Response response) {
    switch (response.statusCode) {
      case 413:
        return 'La foto pesa demasiado (máximo 5 MB).';
      case 415:
        return 'Formato de foto no permitido. Usa JPG, PNG o WebP.';
      case 503:
        return 'El almacenamiento de fotos no está disponible por ahora.';
    }
    return _errorMessage(response);
  }

  static String _errorMessage(http.Response response) {
    if (response.statusCode == 422) return 'Revisa los datos del reporte e inténtalo de nuevo.';
    if (response.statusCode >= 500) return 'El servidor tuvo un problema. Inténtalo más tarde.';
    return 'No se pudo completar la solicitud (${response.statusCode}).';
  }
}
