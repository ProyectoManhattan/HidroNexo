import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Estado de la conexión del dispositivo (solo si hay red, no si hay internet:
/// por eso el reenvío además comprueba `/health`).
abstract class ConnectivityService extends ChangeNotifier {
  /// Última lectura conocida. Optimista (true) hasta la primera comprobación.
  bool get online;

  /// Emite true al recuperar la conexión y false al perderla.
  Stream<bool> get changes;

  Future<void> start();
}

/// Real: `connectivity_plus`.
class DeviceConnectivityService extends ConnectivityService {
  DeviceConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _online = true;
  bool _started = false;

  @override
  bool get online => _online;

  @override
  Stream<bool> get changes => _changes.stream;

  static bool _isOnline(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);

  void _update(bool value) {
    if (value == _online) return;
    _online = value;
    _changes.add(value);
    notifyListeners();
  }

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      _update(_isOnline(await _connectivity.checkConnectivity()));
      _sub = _connectivity.onConnectivityChanged.listen(
        (r) => _update(_isOnline(r)),
        onError: (Object e) => debugPrint('[red] error de conectividad: $e'),
      );
    } catch (e) {
      debugPrint('[red] no se pudo leer la conectividad: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _changes.close();
    super.dispose();
  }
}

/// Siempre en línea (USE_MOCK).
class AlwaysOnlineConnectivity extends ConnectivityService {
  @override
  bool get online => true;

  @override
  Stream<bool> get changes => const Stream.empty();

  @override
  Future<void> start() async {}
}

/// Controlable a mano (pruebas).
class FakeConnectivityService extends ConnectivityService {
  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  bool _online = true;

  @override
  bool get online => _online;

  @override
  Stream<bool> get changes => _changes.stream;

  set online(bool value) {
    if (value == _online) return;
    _online = value;
    _changes.add(value);
    notifyListeners();
  }

  @override
  Future<void> start() async {}
}
