import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/offline_cache.dart';
import '../../models/coordinates.dart';
import '../location_service.dart';

/// Guarda el CP fijado a mano (demo).
abstract class ManualCpStore {
  Future<String?> load();
  Future<void> save(String? cp);
}

class MemoryManualCpStore implements ManualCpStore {
  MemoryManualCpStore([this._cp]);

  String? _cp;

  @override
  Future<String?> load() async => _cp;

  @override
  Future<void> save(String? cp) async => _cp = cp;
}

class PrefsManualCpStore implements ManualCpStore {
  static const _key = 'malla_cp_manual';

  @override
  Future<String?> load() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String? cp) async {
    try {
      final p = await SharedPreferences.getInstance();
      cp == null ? await p.remove(_key) : await p.setString(_key, cp);
    } catch (e) {
      debugPrint('[malla] no se pudo guardar el CP: $e');
    }
  }
}

/// De dónde salió el CP propio.
enum CpSource { manual, gps, unknown }

class CpResult {
  const CpResult(this.cp, this.source);

  final String? cp;
  final CpSource source;
}

/// Calcula el código postal propio: el fijado a mano manda; si no, la última
/// ubicación (sin pedir permisos) dentro de las zonas ya cacheadas.
class PostalCodeResolver extends ChangeNotifier {
  PostalCodeResolver({
    required this.manualStore,
    this.loadGeoJson,
    this.locate,
    this.cacheFor = const Duration(minutes: 2),
  });

  /// Con la caché local real.
  factory PostalCodeResolver.fromApp({
    required ManualCpStore manualStore,
    required OfflineCache cache,
    required LocationService location,
  }) =>
      PostalCodeResolver(
        manualStore: manualStore,
        loadGeoJson: () async => (await cache.loadRiskZones())?.value,
        locate: () async {
          try {
            return (await location.getCurrentLocation(requestPermission: false)).position;
          } on LocationException {
            return null;
          }
        },
      );

  final ManualCpStore manualStore;
  final Future<Map<String, dynamic>?> Function()? loadGeoJson;
  final Future<Coordinates?> Function()? locate;
  final Duration cacheFor;

  String? _manual;
  bool _loaded = false;
  CpResult? _last;
  DateTime? _lastAt;

  /// CP fijado a mano (o null).
  String? get manual => _manual;
  CpResult? get last => _last;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    _manual = await manualStore.load();
  }

  /// Fija (5 dígitos) o quita (null/vacío) el CP manual. false si es inválido.
  Future<bool> setManual(String? raw) async {
    final v = raw?.trim() ?? '';
    if (v.isNotEmpty && !RegExp(r'^\d{5}$').hasMatch(v)) return false;
    await load();
    _manual = v.isEmpty ? null : v;
    await manualStore.save(_manual);
    _last = null;
    notifyListeners();
    return true;
  }

  Future<CpResult> resolve() async {
    await load();
    final m = _manual;
    if (m != null) return _last = CpResult(m, CpSource.manual);
    final at = _lastAt;
    if (_last != null && at != null && DateTime.now().difference(at) < cacheFor) return _last!;
    CpResult r = const CpResult(null, CpSource.unknown);
    try {
      final geo = await loadGeoJson?.call();
      final pos = await locate?.call();
      if (geo != null && pos != null) {
        final cp = cpFromGeoJson(geo, pos.latitude, pos.longitude);
        if (cp != null) r = CpResult(cp, CpSource.gps);
      }
    } catch (e) {
      debugPrint('[malla] no se pudo derivar el CP: $e');
    }
    _lastAt = DateTime.now();
    _last = r;
    notifyListeners();
    return r;
  }

  /// Los 5 dígitos de un nombre como «C.P. 91690» (null si no hay).
  static String? extractCp(String? name) {
    if (name == null) return null;
    return RegExp(r'(?<!\d)(\d{5})(?!\d)').firstMatch(name)?.group(1);
  }

  /// CP de la zona (feature) del GeoJSON que contiene el punto.
  static String? cpFromGeoJson(Map<String, dynamic> geo, double lat, double lon) {
    final features = geo['features'];
    if (features is! List) return null;
    for (final f in features) {
      if (f is! Map) continue;
      final cp = extractCp('${(f['properties'] is Map ? f['properties']['nombre'] : null) ?? ''}');
      if (cp == null) continue;
      final g = f['geometry'];
      if (g is Map && geometryContains(g, lat, lon)) return cp;
    }
    return null;
  }

  /// Punto en Polygon / MultiPolygon GeoJSON (coordenadas [lon, lat]).
  static bool geometryContains(Map g, double lat, double lon) {
    final coords = g['coordinates'];
    if (coords is! List) return false;
    switch (g['type']) {
      case 'Polygon':
        return _polygonContains(coords, lat, lon);
      case 'MultiPolygon':
        return coords.any((p) => p is List && _polygonContains(p, lat, lon));
    }
    return false;
  }

  /// Primer anillo = exterior; los demás = huecos.
  static bool _polygonContains(List rings, double lat, double lon) {
    if (rings.isEmpty || !_ringContains(rings.first, lat, lon)) return false;
    for (var i = 1; i < rings.length; i++) {
      if (_ringContains(rings[i], lat, lon)) return false;
    }
    return true;
  }

  static bool _ringContains(Object? ring, double lat, double lon) {
    if (ring is! List || ring.length < 3) return false;
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = (ring[i][0] as num).toDouble(), yi = (ring[i][1] as num).toDouble();
      final xj = (ring[j][0] as num).toDouble(), yj = (ring[j][1] as num).toDouble();
      if ((yi > lat) != (yj > lat) && lon < (xj - xi) * (lat - yi) / (yj - yi) + xi) inside = !inside;
    }
    return inside;
  }
}
