import 'package:flutter/material.dart';

import '../../models/active_alert.dart';
import '../../services/active_alert_watcher.dart';
import 'alert_full_screen.dart';

/// Muestra en pantalla completa, una tras otra, las alertas pendientes del
/// [ActiveAlertWatcher], sobre cualquier pantalla (usa el navigatorKey de la
/// app). Nunca apila dos a la vez.
class AlertPresenter {
  AlertPresenter({required this.watcher, required this.navigatorKey}) {
    watcher.addListener(_onChange);
  }

  final ActiveAlertWatcher watcher;
  final GlobalKey<NavigatorState> navigatorKey;

  bool _showing = false;
  bool _scheduled = false;

  /// Id de la alerta que se está mostrando (null si ninguna).
  int? shownId;

  /// Revisa si hay algo por mostrar.
  void check() => _onChange();

  void _onChange() {
    if (_showing || _scheduled) return;
    _scheduled = true;
    // Fuera del ciclo de notificación y del frame en curso.
    Future<void>.microtask(() {
      _scheduled = false;
      _showNext();
    });
  }

  void _showNext() {
    if (_showing) return;
    final nav = navigatorKey.currentState;
    if (nav == null || watcher.pending.isEmpty) {
      // Aún no hay navegador (arranque): se reintenta al próximo cambio.
      if (nav == null && watcher.pending.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _onChange());
      }
      return;
    }
    final ActiveAlert alert = watcher.pending.first;
    _showing = true;
    shownId = alert.id;
    nav
        .push(AlertFullScreen.route(
          alert,
          remaining: watcher.pending.length - 1,
          onAcknowledge: () => watcher.markSeen(alert.id),
        ))
        .whenComplete(() {
      _showing = false;
      shownId = null;
      if (watcher.pending.isNotEmpty) _onChange();
    });
  }

  void dispose() => watcher.removeListener(_onChange);
}
