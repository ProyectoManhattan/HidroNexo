import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda los ids de alertas que el usuario ya confirmó («Enterado»).
abstract class SeenAlertsStore {
  Future<Set<int>> load();
  Future<void> save(Set<int> ids);
}

/// Solo en memoria (pruebas o si no hay almacenamiento).
class MemorySeenAlertsStore implements SeenAlertsStore {
  MemorySeenAlertsStore([Set<int>? initial]) : _ids = {...?initial};

  Set<int> _ids;

  @override
  Future<Set<int>> load() async => {..._ids};

  @override
  Future<void> save(Set<int> ids) async => _ids = {...ids};
}

/// Persistente con shared_preferences. Nunca lanza: si falla, devuelve vacío.
class PrefsSeenAlertsStore implements SeenAlertsStore {
  static const _key = 'alertas_vistas';
  static const _maxKept = 200;

  @override
  Future<Set<int>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key) ?? const []).map(int.tryParse).whereType<int>().toSet();
    } catch (e) {
      debugPrint('[alertas] no se pudo leer alertas vistas: $e');
      return {};
    }
  }

  @override
  Future<void> save(Set<int> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sorted = ids.toList()..sort();
      final kept = sorted.length > _maxKept ? sorted.sublist(sorted.length - _maxKept) : sorted;
      await prefs.setStringList(_key, kept.map((i) => '$i').toList());
    } catch (e) {
      debugPrint('[alertas] no se pudo guardar alertas vistas: $e');
    }
  }
}
