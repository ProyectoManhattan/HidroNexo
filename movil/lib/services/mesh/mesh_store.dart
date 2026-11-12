import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../data/local/local_database.dart';
import 'mesh_message.dart';

/// Mensaje guardado en el teléfono para llevarlo y reenviarlo.
class StoredMesh {
  const StoredMesh({
    required this.message,
    required this.from,
    required this.receivedAt,
    this.delivered = false,
  });

  final MeshMessage message;

  /// Vecino que lo entregó (`self` si nació aquí).
  final String from;
  final int receivedAt;

  /// Reporte ya subido a internet: no se reenvía.
  final bool delivered;
}

/// Almacén de los mensajes de la malla (máx. [maxMessages]).
abstract class MeshStore {
  static const int maxMessages = 20;

  Future<bool> has(String id);

  /// Guarda el mensaje. Si se pasa el límite expulsa el más antiguo y
  /// devuelve su id (null si no expulsó nada).
  Future<String?> put(StoredMesh item);
  Future<void> markDelivered(String id);
  Future<List<StoredMesh>> all();

  /// Borra los vencidos; devuelve cuántos.
  Future<int> purgeExpired(DateTime now);
}

class MemoryMeshStore implements MeshStore {
  final Map<String, StoredMesh> _items = {};

  @override
  Future<bool> has(String id) async => _items.containsKey(id);

  @override
  Future<String?> put(StoredMesh item) async {
    _items[item.message.id] = item;
    return _evict(_items.values.toList(), (id) => _items.remove(id));
  }

  @override
  Future<void> markDelivered(String id) async {
    final i = _items[id];
    if (i != null) {
      _items[id] = StoredMesh(message: i.message, from: i.from, receivedAt: i.receivedAt, delivered: true);
    }
  }

  @override
  Future<List<StoredMesh>> all() async => _items.values.toList();

  @override
  Future<int> purgeExpired(DateTime now) async {
    final dead = _items.values.where((i) => i.message.isExpired(now)).map((i) => i.message.id).toList();
    dead.forEach(_items.remove);
    return dead.length;
  }
}

String? _evict(List<StoredMesh> items, void Function(String id) remove) {
  if (items.length <= MeshStore.maxMessages) return null;
  items.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
  final victim = items.first.message.id;
  remove(victim);
  return victim;
}

/// SQLite (tabla `mesh_messages`). Nunca lanza: si la BD falla se degrada
/// (como el resto de la app) a no guardar nada.
class SqlMeshStore implements MeshStore {
  SqlMeshStore(this._db);

  final LocalDatabase _db;

  @override
  Future<bool> has(String id) => _db.guard<bool>('mesh has', false, (db) async {
        final r = await db.query('mesh_messages', columns: ['id'], where: 'id = ?', whereArgs: [id], limit: 1);
        return r.isNotEmpty;
      });

  @override
  Future<String?> put(StoredMesh item) => _db.guard<String?>('mesh put', null, (db) async {
        await db.insert(
          'mesh_messages',
          {
            'id': item.message.id,
            'json': jsonEncode(item.message.toJson()),
            'expira_en': item.message.expiresAt,
            'entregado': item.delivered ? 1 : 0,
            'de': item.from,
            'recibida_en': item.receivedAt,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        final victim = _evict(await all(), (_) {});
        if (victim != null) await db.delete('mesh_messages', where: 'id = ?', whereArgs: [victim]);
        return victim;
      });

  @override
  Future<void> markDelivered(String id) => _db.guard<void>('mesh entregado', null, (db) async {
        await db.update('mesh_messages', {'entregado': 1}, where: 'id = ?', whereArgs: [id]);
      });

  @override
  Future<List<StoredMesh>> all() => _db.guard<List<StoredMesh>>('mesh all', const [], (db) async {
        final rows = await db.query('mesh_messages');
        final out = <StoredMesh>[];
        for (final r in rows) {
          final m = MeshMessage.fromJson(jsonDecode(r['json'] as String));
          if (m == null) continue;
          out.add(StoredMesh(
            message: m,
            from: '${r['de']}',
            receivedAt: r['recibida_en'] as int,
            delivered: r['entregado'] == 1,
          ));
        }
        return out;
      });

  @override
  Future<int> purgeExpired(DateTime now) => _db.guard<int>('mesh purge', 0, (db) {
        return db.delete('mesh_messages', where: 'expira_en <= ?', whereArgs: [now.millisecondsSinceEpoch ~/ 1000]);
      });
}
