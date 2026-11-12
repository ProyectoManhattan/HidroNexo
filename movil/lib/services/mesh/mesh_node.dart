import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/utils/uuid.dart';
import '../../data/local/pending_report.dart';
import '../../data/report_repository.dart';
import '../../models/active_alert.dart';
import '../../models/coordinates.dart';
import '../../models/new_report.dart';
import '../../models/report_type.dart';
import '../connectivity_service.dart';
import 'mesh_message.dart';
import 'mesh_store.dart';
import 'mesh_transport.dart';
import 'postal_code_resolver.dart';

class MeshLogEntry {
  const MeshLogEntry(this.at, this.text, {this.isError = false});

  final DateTime at;
  final String text;
  final bool isError;
}

/// Nodo de la malla: aplica las reglas de recepción, guarda, lleva y reenvía.
///
/// Reglas (cada decisión queda en [log]):
///  - duplicado (id ya visto) → se ignora; expirado → se descarta;
///  - saltos >= ttl → se procesa pero no se reenvía;
///  - alerta: mi CP ∈ destino → se guarda, se muestra y se reenvía
///    (saltos_fuera = 0); fuera de destino (o CP desconocido) → se guarda y
///    reenvía solo si saltos_fuera + 1 <= [maxOutside]; si no, se descarta;
///  - reporte: sin filtro por CP; con internet se sube (mismo cliente_id,
///    el backend es idempotente) y se marca entregado; sin internet se
///    guarda y se reenvía.
class MeshNode extends ChangeNotifier {
  MeshNode({
    required this.transport,
    required this.store,
    required this.cpResolver,
    required this.repository,
    required this.connectivity,
    required this.onShowAlert,
    DateTime Function()? now,
    this.maxOutside = 2,
    this.linger = const Duration(seconds: 6),
    this.label = 'yo',
  }) : _now = now ?? DateTime.now;

  final MeshTransport transport;
  final MeshStore store;
  final PostalCodeResolver cpResolver;
  final ReportRepository repository;
  final ConnectivityService connectivity;

  /// Muestra la alerta en pantalla completa.
  final void Function(ActiveAlert alert) onShowAlert;
  final DateTime Function() _now;

  /// Saltos que una alerta aguanta fuera de la zona destino.
  final int maxOutside;

  /// Tiempo que se mantiene abierta la conexión tras conectar (null = no se cierra).
  final Duration? linger;
  final String label;

  static const int maxLog = 200;

  final List<MeshLogEntry> _log = [];
  final Set<String> _seen = {};
  final List<StreamSubscription<Object?>> _subs = [];
  Future<void> _chain = Future<void>.value();
  bool _started = false;
  bool _disposed = false;

  int sent = 0;
  int received = 0;
  int discarded = 0;
  int storedCount = 0;

  List<MeshLogEntry> get log => List.unmodifiable(_log);
  bool get started => _started;
  int get connectedCount => transport.connectedPeers.length;
  int get discoveredCount => transport.discoveredCount;

  void addLog(String text, {bool error = false}) {
    _log.insert(0, MeshLogEntry(_now(), text, isError: error));
    if (_log.length > maxLog) _log.removeLast();
    debugPrint('[malla:$label] $text');
    _notify();
  }

  Future<void> start() async {
    if (_started) return;
    await cpResolver.load();
    try {
      await transport.start();
    } catch (e) {
      addLog('No se pudo activar la malla: $e', error: true);
      rethrow;
    }
    _started = true;
    _subs
      ..add(transport.events.listen(_onEvent))
      ..add(transport.messages.listen((m) => _enqueue(() => _onIncoming(m))))
      ..add(connectivity.changes.listen((online) {
        if (online) _enqueue(_uploadStoredReports);
      }));
    await store.purgeExpired(_now());
    await _refreshCount();
    final cp = await cpResolver.resolve();
    addLog('Malla activada. Mi CP: ${cp.cp ?? 'desconocido'} (${_sourceLabel(cp.source)}).');
    _notify();
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await transport.stop();
    addLog('Malla desactivada.');
  }

  static String _sourceLabel(CpSource s) => switch (s) {
        CpSource.manual => 'fijado a mano',
        CpSource.gps => 'según tu ubicación',
        CpSource.unknown => 'sin ubicación ni zonas en caché',
      };

  void _enqueue(Future<void> Function() job) {
    _chain = _chain.then((_) => job()).catchError((Object e) {
      addLog('Error interno: $e', error: true);
    });
  }

  /// Espera a que termine lo que está en cola (pruebas).
  Future<void> idle() => _chain;

  // ---------------------------------------------------------------- eventos

  void _onEvent(MeshEvent e) {
    switch (e.kind) {
      case MeshEventKind.peerFound:
        addLog('Vecino descubierto${e.text.isEmpty ? '' : ': ${e.text}'}.');
      case MeshEventKind.peerLost:
        addLog('Vecino fuera de alcance.');
      case MeshEventKind.peerConnected:
        addLog('Conectado con vecino ${_peer(e)}. Enviando mensajes guardados…');
        _enqueue(() => _sendStoredTo(e.peerId!));
        final l = linger;
        if (l != null) {
          Timer(l, () {
            if (_started && transport.connectedPeers.contains(e.peerId)) {
              unawaited(transport.disconnect(e.peerId!));
            }
          });
        }
      case MeshEventKind.peerDisconnected:
        addLog('Vecino ${_peer(e)} desconectado.');
      case MeshEventKind.info:
        addLog(e.text);
      case MeshEventKind.error:
        addLog(e.text, error: true);
    }
    _notify();
  }

  String _peer(MeshEvent e) => e.text.isNotEmpty ? e.text : (e.peerId ?? '?');

  // ----------------------------------------------------------------- envío

  Future<void> _sendTo(String peer, MeshMessage m) async {
    try {
      await transport.send(peer, m.toBytes());
      sent++;
    } catch (e) {
      addLog('No se pudo enviar ${m.shortId} a un vecino: $e', error: true);
    }
  }

  bool _forwardable(MeshMessage m) => !m.isExpired(_now()) && m.hops < m.ttl;

  Future<void> _sendStoredTo(String peer) async {
    final items = await store.all();
    var n = 0;
    for (final i in items) {
      if (i.delivered || i.from == peer || !_forwardable(i.message)) continue;
      await _sendTo(peer, i.message);
      n++;
    }
    addLog(n == 0 ? 'No hay mensajes vigentes para ese vecino.' : 'Enviados $n mensaje(s) guardados al vecino.');
  }

  Future<void> _forward(MeshMessage m, {String? except}) async {
    if (!_forwardable(m)) {
      addLog('${_name(m)}: no se reenvía (llegó a su límite de saltos o venció).');
      return;
    }
    final peers = transport.connectedPeers.where((p) => p != except).toList();
    for (final p in peers) {
      await _sendTo(p, m);
    }
    if (peers.isNotEmpty) addLog('${_name(m)} reenviada a ${peers.length} vecino(s).');
    transport.requestExchange();
  }

  String _name(MeshMessage m) => '${m.kind == MeshKind.alerta ? 'Alerta' : 'Reporte'} ${m.shortId}';

  // ------------------------------------------------------------- recepción

  Future<void> _onIncoming(MeshIncoming incoming) async {
    received++;
    final raw = MeshMessage.fromBytes(incoming.bytes);
    if (raw == null) {
      discarded++;
      addLog('Descartado: mensaje ilegible de un vecino.', error: true);
      return;
    }
    final desc = '${_name(raw)} de vecino';
    if (_seen.contains(raw.id) || await store.has(raw.id)) {
      discarded++;
      addLog('$desc: duplicado, ignorado.');
      return;
    }
    if (raw.isExpired(_now())) {
      discarded++;
      addLog('$desc: descartado, ya venció.');
      return;
    }
    final m = raw.copyWith(hops: raw.hops + 1);
    switch (m.kind) {
      case MeshKind.alerta:
        await _handleAlert(m, incoming.peerId, desc);
      case MeshKind.reporte:
        await _handleReport(m, incoming.peerId, desc);
    }
  }

  Future<void> _handleAlert(MeshMessage m, String from, String desc) async {
    final cpInfo = await cpResolver.resolve();
    final cp = cpInfo.cp;
    final inZone = cp != null && m.cps.contains(cp);
    final dest = m.cps.join(', ');
    MeshMessage stored;
    if (inZone) {
      stored = m.copyWith(hopsOutside: 0);
      _seen.add(m.id);
      addLog('$desc: mi CP $cp ∈ destino ($dest) → mostrar y reenviar.');
      onShowAlert(_toActiveAlert(m, cp));
    } else {
      final outside = m.hopsOutside + 1;
      if (outside > maxOutside) {
        discarded++;
        addLog('$desc: descartada, fuera de zona (mi CP ${cp ?? 'desconocido'} ∉ $dest; '
            'ya pasó $maxOutside saltos fuera).');
        return;
      }
      stored = m.copyWith(hopsOutside: outside);
      _seen.add(m.id);
      addLog(cp == null
          ? '$desc: mi CP es desconocido → no se muestra; se reenvía (salto fuera $outside/$maxOutside).'
          : '$desc: mi CP $cp ∉ destino ($dest) → solo reenviar (salto fuera $outside/$maxOutside).');
    }
    await _keep(stored, from);
    await _forward(stored, except: from);
  }

  Future<void> _handleReport(MeshMessage m, String from, String desc) async {
    _seen.add(m.id);
    if (await _tryUpload(m)) {
      await store.put(StoredMesh(message: m, from: from, receivedAt: _nowMs(), delivered: true));
      await _refreshCount();
      return;
    }
    addLog('$desc: sin internet aquí → guardado y reenviado.');
    await _keep(m, from);
    await _forward(m, except: from);
  }

  /// Sube el reporte si este teléfono tiene internet. true si quedó entregado.
  Future<bool> _tryUpload(MeshMessage m) async {
    if (!connectivity.online) return false;
    try {
      await repository.checkHealth();
      final p = m.payload;
      final folio = await repository.submit(NewReport(
        type: ReportTypeApi.fromApi(p['categoria'] as String?),
        neighborhood: '',
        address: '${p['direccion'] ?? ''}',
        position: Coordinates((p['lat'] as num).toDouble(), (p['lon'] as num).toDouble()),
        description: '${p['descripcion'] ?? ''}',
        severity: (p['severidad'] as num?)?.toInt() ?? 2,
        clienteId: p['cliente_id'] as String?,
      ));
      addLog('${_name(m)}: reporte subido a internet (folio $folio). Ya no se reenvía.');
      return true;
    } on RepositoryException catch (e) {
      addLog('${_name(m)}: no se pudo subir a internet (${e.message}).');
    } catch (e) {
      addLog('${_name(m)}: reporte inválido o error al subir ($e).', error: true);
    }
    return false;
  }

  Future<void> _uploadStoredReports() async {
    for (final i in await store.all()) {
      if (i.delivered || i.message.kind != MeshKind.reporte || i.message.isExpired(_now())) continue;
      if (await _tryUpload(i.message)) await store.markDelivered(i.message.id);
    }
    await _refreshCount();
  }

  ActiveAlert _toActiveAlert(MeshMessage m, String cp) {
    final id = -(m.id.hashCode & 0x3fffffff) - 1; // negativo: no choca con ids del backend
    return ActiveAlert(
      id: id,
      type: ReportType.flood,
      level: AlertLevel.fromApi(m.level),
      text: m.text,
      zoneName: 'C.P. $cp',
      motivo: 'malla',
      simulated: m.simulated,
      approvedAt: DateTime.fromMillisecondsSinceEpoch(m.createdAt * 1000),
      guideTitle: 'Qué hacer ante una inundación',
      steps: ReportType.flood.tips,
    );
  }

  // ------------------------------------------------------------ almacenamiento

  int _nowMs() => _now().millisecondsSinceEpoch;

  Future<void> _keep(MeshMessage m, String from) async {
    await store.purgeExpired(_now());
    final evicted = await store.put(StoredMesh(message: m, from: from, receivedAt: _nowMs()));
    if (evicted != null) addLog('Almacén lleno (${MeshStore.maxMessages}): se borró el mensaje más antiguo.');
    await _refreshCount();
  }

  Future<void> _refreshCount() async {
    storedCount = (await store.all()).where((i) => !i.delivered).length;
    _notify();
  }

  // ---------------------------------------------------------------- origen

  /// Publica una alerta (real o de prueba) a la malla. [id] fijo evita duplicar
  /// una alerta real. Devuelve el mensaje, o null si ya estaba publicada.
  Future<MeshMessage?> publishAlert({
    required List<String> cps,
    required String level,
    required String text,
    bool simulated = false,
    bool show = true,
    String? id,
    Duration validity = const Duration(hours: 6),
    int? createdAtSec,
    int ttl = MeshMessage.defaultTtl,
  }) {
    final c = Completer<MeshMessage?>();
    _enqueue(() async {
      final mid = id ?? generateUuidV4();
      if (_seen.contains(mid) || await store.has(mid)) {
        c.complete(null);
        return;
      }
      final nowSec = _nowMs() ~/ 1000;
      final m = MeshMessage(
        id: mid,
        kind: MeshKind.alerta,
        cps: cps,
        level: level,
        text: text.length > 300 ? text.substring(0, 300) : text,
        createdAt: createdAtSec ?? nowSec,
        expiresAt: nowSec + validity.inSeconds,
        ttl: ttl,
        simulated: simulated,
      );
      _seen.add(mid);
      await _keep(m, 'self');
      addLog('${_name(m)} creada${simulated ? ' (prueba)' : ''} para CP ${cps.join(', ')}.');
      final cp = (await cpResolver.resolve()).cp;
      if (show && cp != null && cps.contains(cp)) {
        // Quien la crea en su propia zona también la ve.
        onShowAlert(_toActiveAlert(m, cp));
      }
      await _forward(m);
      c.complete(m);
    });
    return c.future;
  }

  /// Publica un reporte pendiente (sin foto). Id determinista por cliente_id.
  Future<MeshMessage?> publishReport(PendingReport r, {Duration validity = const Duration(hours: 24)}) =>
      publishReportPayload({
        'cliente_id': r.clienteId,
        'categoria': r.type.apiKey,
        'severidad': r.severity,
        'lat': r.position.latitude,
        'lon': r.position.longitude,
        'descripcion': r.description.length > 280 ? r.description.substring(0, 280) : r.description,
        'direccion': r.address.length > 80 ? r.address.substring(0, 80) : r.address,
      }, validity: validity);

  Future<MeshMessage?> publishReportPayload(Map<String, dynamic> payload,
      {Duration validity = const Duration(hours: 24)}) {
    final c = Completer<MeshMessage?>();
    _enqueue(() async {
      final mid = 'rep-${payload['cliente_id']}';
      if (_seen.contains(mid) || await store.has(mid)) {
        c.complete(null);
        return;
      }
      final nowSec = _nowMs() ~/ 1000;
      final m = MeshMessage(
        id: mid,
        kind: MeshKind.reporte,
        createdAt: nowSec,
        expiresAt: nowSec + validity.inSeconds,
        payload: payload,
      );
      _seen.add(mid);
      addLog('${_name(m)} creado en este teléfono.');
      if (await _tryUpload(m)) {
        await store.put(StoredMesh(message: m, from: 'self', receivedAt: _nowMs(), delivered: true));
      } else {
        await _keep(m, 'self');
        await _forward(m);
      }
      c.complete(m);
    });
    return c.future;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
