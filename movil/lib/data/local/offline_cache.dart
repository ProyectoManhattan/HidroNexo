import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/active_alert.dart';
import 'local_database.dart';

/// Dato guardado junto con el momento en que se guardó.
class Cached<T> {
  const Cached(this.value, this.savedAt);

  final T value;
  final DateTime savedAt;
}

/// Caché local de lo último que se vio con red: alertas (con su guía),
/// GeoJSON de riesgo, zonas y reportes del mapa. Nunca lanza.
class OfflineCache {
  OfflineCache(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final LocalDatabase _db;
  final DateTime Function() _now;

  /// Cuántas alertas se conservan.
  static const int maxAlerts = 10;

  static const _riskKey = 'risk';
  static const _zonesKey = 'zones';
  static const _reportsKey = 'reports';

  // ---- Alertas ----

  /// Reemplaza las alertas guardadas por [alerts] (las [maxAlerts] más graves).
  Future<void> saveAlerts(List<ActiveAlert> alerts) => _db.guard<void>('guardar alertas', null, (db) async {
        final kept = ([...alerts]..sort(ActiveAlert.compareBySeverity)).take(maxAlerts).toList();
        final at = _now().millisecondsSinceEpoch;
        await db.transaction((txn) async {
          await txn.delete('cached_alerts');
          for (final a in kept) {
            await txn.insert(
              'cached_alerts',
              {'id': a.id, 'json': jsonEncode(a.toJson()), 'saved_at': at},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });
      });

  /// Alertas guardadas (más grave primero) y cuándo se guardaron; null si no hay.
  Future<Cached<List<ActiveAlert>>?> loadAlerts() =>
      _db.guard<Cached<List<ActiveAlert>>?>('leer alertas', null, (db) async {
        final rows = await db.query('cached_alerts');
        if (rows.isEmpty) return null;
        final alerts = <ActiveAlert>[];
        var savedAt = 0;
        for (final row in rows) {
          final a = ActiveAlert.fromCacheJson(jsonDecode(row['json'] as String) as Map<String, dynamic>);
          if (a != null) alerts.add(a);
          savedAt = row['saved_at'] as int;
        }
        alerts.sort(ActiveAlert.compareBySeverity);
        return Cached(alerts, DateTime.fromMillisecondsSinceEpoch(savedAt));
      });

  // ---- Zonas y reportes ----

  Future<void> saveRiskZones(Map<String, dynamic> geoJson) => _put('cached_zones', _riskKey, geoJson);
  Future<Cached<Map<String, dynamic>>?> loadRiskZones() async {
    final c = await _get('cached_zones', _riskKey);
    final v = c?.value;
    return v is Map<String, dynamic> ? Cached(v, c!.savedAt) : null;
  }

  Future<void> saveZones(List<Map<String, dynamic>> rows) => _put('cached_zones', _zonesKey, rows);
  Future<Cached<List<Map<String, dynamic>>>?> loadZones() => _loadList('cached_zones', _zonesKey);

  Future<void> saveReports(List<Map<String, dynamic>> rows) => _put('cached_reports', _reportsKey, rows);
  Future<Cached<List<Map<String, dynamic>>>?> loadReports() => _loadList('cached_reports', _reportsKey);

  Future<Cached<List<Map<String, dynamic>>>?> _loadList(String table, String key) async {
    final c = await _get(table, key);
    final v = c?.value;
    if (v is! List) return null;
    return Cached(v.whereType<Map<String, dynamic>>().toList(), c!.savedAt);
  }

  Future<void> _put(String table, String key, Object value) => _db.guard<void>('guardar $key', null, (db) async {
        await db.insert(
          table,
          {'key': key, 'json': jsonEncode(value), 'saved_at': _now().millisecondsSinceEpoch},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });

  Future<Cached<Object?>?> _get(String table, String key) =>
      _db.guard<Cached<Object?>?>('leer $key', null, (db) async {
        final rows = await db.query(table, where: 'key = ?', whereArgs: [key], limit: 1);
        if (rows.isEmpty) return null;
        return Cached(
          jsonDecode(rows.first['json'] as String),
          DateTime.fromMillisecondsSinceEpoch(rows.first['saved_at'] as int),
        );
      });
}
