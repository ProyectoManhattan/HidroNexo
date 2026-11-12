import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos local (SQLite) con migraciones versionadas.
///
/// Tablas:
///  - `pending_report`: el único reporte pendiente de envío (como máximo una fila).
///  - `cached_alerts`: últimas alertas activas con su guía (JSON).
///  - `cached_zones`: GeoJSON de riesgo y listado de zonas (JSON + fecha de guardado).
///  - `cached_reports`: última lista de reportes del mapa (JSON + fecha).
///  - `mesh_messages`: mensajes de la malla Bluetooth guardados para reenviar (máx. 20).
///
/// Para añadir una migración: sube [version] y agrega la clave en [migrations].
class LocalDatabase {
  LocalDatabase({DatabaseFactory? factory, String? path})
      : _factory = factory,
        _path = path;

  static const String fileName = 'hidronexo.db';

  /// Sentencias por versión. `onCreate` ejecuta todas; `onUpgrade`, las nuevas.
  static const Map<int, List<String>> migrations = {
    1: [
      '''
      CREATE TABLE pending_report (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        cliente_id TEXT NOT NULL,
        categoria TEXT NOT NULL,
        severidad INTEGER NOT NULL,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        descripcion TEXT NOT NULL,
        direccion TEXT NOT NULL DEFAULT '',
        foto_path TEXT,
        foto_url TEXT,
        foto_fallos INTEGER NOT NULL DEFAULT 0,
        creado_en INTEGER NOT NULL,
        intentos INTEGER NOT NULL DEFAULT 0,
        proximo_intento INTEGER,
        estado TEXT NOT NULL,
        error TEXT
      )''',
      '''
      CREATE TABLE cached_alerts (
        id INTEGER PRIMARY KEY,
        json TEXT NOT NULL,
        saved_at INTEGER NOT NULL
      )''',
      '''
      CREATE TABLE cached_zones (
        key TEXT PRIMARY KEY,
        json TEXT NOT NULL,
        saved_at INTEGER NOT NULL
      )''',
      '''
      CREATE TABLE cached_reports (
        key TEXT PRIMARY KEY,
        json TEXT NOT NULL,
        saved_at INTEGER NOT NULL
      )''',
    ],
    2: [
      // Malla Bluetooth (modo sin internet): mensajes que se llevan y reenvían.
      '''
      CREATE TABLE mesh_messages (
        id TEXT PRIMARY KEY,
        json TEXT NOT NULL,
        expira_en INTEGER NOT NULL,
        entregado INTEGER NOT NULL DEFAULT 0,
        de TEXT NOT NULL,
        recibida_en INTEGER NOT NULL
      )''',
    ],
  };

  static int get version => migrations.keys.reduce((a, b) => a > b ? a : b);

  final DatabaseFactory? _factory;
  final String? _path;
  Future<Database>? _db;

  /// Abre la base (una sola vez). Lanza si no se puede; quien la usa captura.
  Future<Database> get database => _db ??= _open().catchError((Object e) {
        _db = null; // permite reintentar más tarde
        throw e;
      });

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final path = _path ?? p.join(await factory.getDatabasesPath(), fileName);
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, _) => _migrate(db, 0, version),
        onUpgrade: _migrate,
      ),
    );
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    for (var v = from + 1; v <= to; v++) {
      for (final sql in migrations[v] ?? const <String>[]) {
        await db.execute(sql);
      }
    }
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) await (await db).close();
  }

  /// Ejecuta [action]; si la BD falla devuelve [fallback] y lo registra.
  /// La app sigue funcionando sin base de datos (degradación elegante).
  Future<T> guard<T>(String what, T fallback, Future<T> Function(Database db) action) async {
    try {
      return await action(await database);
    } catch (e) {
      debugPrint('[bd] $what falló: $e');
      return fallback;
    }
  }
}
