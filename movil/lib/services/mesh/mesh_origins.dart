import 'dart:async';

import '../../models/active_alert.dart';
import '../active_alert_watcher.dart';
import '../connectivity_service.dart';
import '../pending_report_queue.dart';
import 'mesh_node.dart';
import 'postal_code_resolver.dart';

/// Conecta el nodo con lo que ya hace la app: alertas reales que llegan con
/// internet (se publican a la malla, con el CP de su colonia) y el reporte
/// pendiente de la cola local cuando no hay internet.
class MeshOrigins {
  MeshOrigins({
    required this.node,
    required this.watcher,
    required this.queue,
    required this.connectivity,
  });

  final MeshNode node;
  final ActiveAlertWatcher watcher;
  final PendingReportQueue queue;
  final ConnectivityService connectivity;

  StreamSubscription<List<ActiveAlert>>? _alertsSub;
  StreamSubscription<bool>? _netSub;

  bool get enabled => node.started;

  Future<void> enable() async {
    if (node.started) return;
    await node.start();
    _alertsSub = watcher.activeUpdates.listen(_publishAlerts);
    _netSub = connectivity.changes.listen((_) => _publishPending());
    queue.addListener(_publishPending);
    _publishAlerts(watcher.active);
    _publishPending();
  }

  Future<void> disable() async {
    queue.removeListener(_publishPending);
    await _alertsSub?.cancel();
    await _netSub?.cancel();
    _alertsSub = _netSub = null;
    await node.stop();
  }

  void _publishAlerts(List<ActiveAlert> alerts) {
    for (final a in alerts) {
      final cp = PostalCodeResolver.extractCp(a.zoneName);
      if (cp == null) continue;
      unawaited(node.publishAlert(
        id: 'alerta-${a.id}',
        cps: [cp],
        level: a.level.apiKey,
        text: a.text,
        simulated: a.simulated,
        show: false,
        createdAtSec: a.approvedAt == null ? null : a.approvedAt!.millisecondsSinceEpoch ~/ 1000,
      ));
    }
  }

  void _publishPending() {
    final p = queue.pending;
    if (p == null || connectivity.online || !node.started) return;
    unawaited(node.publishReport(p));
  }
}
