import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/report_repository.dart';
import '../models/active_alert.dart';
import 'location_service.dart';
import 'seen_alerts_store.dart';

/// Vigilante de alertas de la zona del usuario (sin Firebase).
///
/// Con la app en primer plano consulta la API cada [interval], al reanudar y
/// cuando se le pide ([refresh]). Las alertas nuevas (no confirmadas aún) van
/// a la cola [pending], la más grave primero; la UI las muestra en pantalla
/// completa y llama a [markSeen] al pulsar «Enterado».
class ActiveAlertWatcher extends ChangeNotifier with WidgetsBindingObserver {
  ActiveAlertWatcher({
    required ReportRepository repository,
    required LocationService locationService,
    SeenAlertsStore? store,
    this.interval = defaultInterval,
    this.maxAge = const Duration(hours: 12),
    DateTime Function()? now,
  })  : _repository = repository,
        _location = locationService,
        _store = store ?? MemorySeenAlertsStore(),
        _now = now ?? DateTime.now;

  /// Cada cuánto se consulta con la app abierta.
  static const Duration defaultInterval = Duration(seconds: 20);

  final ReportRepository _repository;
  final LocationService _location;
  final SeenAlertsStore _store;
  final Duration interval;
  final Duration maxAge;
  final DateTime Function() _now;

  Set<int>? _seen;
  List<ActiveAlert> _active = const [];
  final List<ActiveAlert> _pending = [];
  Timer? _timer;
  bool _running = false;
  bool _fetching = false;
  bool _disposed = false;

  /// Alertas vigentes de la última consulta exitosa.
  List<ActiveAlert> get active => List.unmodifiable(_active);

  /// Cola por mostrar (más grave primero).
  List<ActiveAlert> get pending => List.unmodifiable(_pending);

  /// Empieza a vigilar (consulta ya y luego cada [interval]).
  void start() {
    if (_running || _disposed) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    _schedule();
    unawaited(refresh());
  }

  /// Detiene el sondeo (sin liberar el objeto).
  void stop() {
    if (!_running) return;
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(refresh()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    if (state == AppLifecycleState.resumed) {
      _schedule();
      unawaited(refresh());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Consulta la API y encola alertas nuevas. Nunca lanza.
  Future<void> refresh() async {
    if (_fetching || _disposed) return;
    _fetching = true;
    try {
      final seen = _seen ??= await _store.load();
      final UserLocation loc;
      try {
        loc = await _location.getCurrentLocation(requestPermission: false);
      } on LocationException catch (e) {
        debugPrint('[alertas] sin ubicación, no se consulta la zona: $e');
        return;
      }
      final fetched = await _repository.getActiveAlertsAt(
        lat: loc.position.latitude,
        lon: loc.position.longitude,
      );
      _active = fetched;
      final cutoff = _now().subtract(maxAge);
      var changed = false;
      // Las que ya no están vigentes salen de la cola.
      final ids = fetched.map((a) => a.id).toSet();
      changed |= _removeWhere((a) => !ids.contains(a.id));
      for (final alert in fetched) {
        if (seen.contains(alert.id)) continue;
        if (_pending.any((p) => p.id == alert.id)) continue;
        final at = alert.approvedAt;
        if (at != null && at.isBefore(cutoff)) continue;
        _pending.add(alert);
        changed = true;
      }
      if (changed) {
        _pending.sort(ActiveAlert.compareBySeverity);
        _notify();
      }
    } on RepositoryException catch (e) {
      debugPrint('[alertas] no se pudo consultar alertas activas: $e');
    } catch (e) {
      debugPrint('[alertas] error al consultar alertas activas: $e');
    } finally {
      _fetching = false;
    }
  }

  /// Marca la alerta como confirmada (persistida) y la saca de la cola.
  Future<void> markSeen(int id) async {
    if (_removeWhere((a) => a.id == id)) _notify();
    final seen = _seen ??= await _store.load();
    seen.add(id);
    try {
      await _store.save(seen);
    } catch (e) {
      debugPrint('[alertas] no se pudo guardar alerta vista: $e');
    }
  }

  /// Pone una alerta al frente de la cola aunque ya estuviera confirmada
  /// (el usuario tocó su notificación). Si no está en la lista activa,
  /// refresca y busca. Devuelve false si no se encontró.
  Future<bool> requestShow(int id) async {
    ActiveAlert? find() {
      for (final a in _active) {
        if (a.id == id) return a;
      }
      return null;
    }

    var alert = find();
    if (alert == null) {
      await refresh();
      alert = find();
    }
    if (alert == null) return false;
    _pending.removeWhere((a) => a.id == id);
    _pending.insert(0, alert);
    _notify();
    return true;
  }

  bool _removeWhere(bool Function(ActiveAlert) test) {
    final before = _pending.length;
    _pending.removeWhere(test);
    return _pending.length != before;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _disposed = true;
    super.dispose();
  }
}
