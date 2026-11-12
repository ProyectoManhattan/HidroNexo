import 'package:sqflite/sqflite.dart';

import 'local_database.dart';
import 'pending_report.dart';

/// Acceso a la tabla `pending_report` (una sola fila posible: id = 1).
/// Nunca lanza: si la BD falla, devuelve null/false y lo registra.
class PendingReportStore {
  PendingReportStore(this._db);

  final LocalDatabase _db;

  static const _table = 'pending_report';

  Future<PendingReport?> load() => _db.guard<PendingReport?>('leer reporte pendiente', null, (db) async {
        final rows = await db.query(_table, limit: 1);
        return rows.isEmpty ? null : PendingReport.fromRow(rows.first);
      });

  /// Guarda (o reemplaza) el reporte pendiente. false si la BD falló.
  Future<bool> save(PendingReport report) => _db.guard('guardar reporte pendiente', false, (db) async {
        await db.insert(_table, report.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
        return true;
      });

  Future<void> clear() => _db.guard<void>('borrar reporte pendiente', null, (db) async {
        await db.delete(_table);
      });
}
