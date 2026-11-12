import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

import '../../core/utils/uuid.dart';
import 'mesh_transport.dart';

/// Transporte real: Google Nearby Connections (Bluetooth/Wi-Fi), estrategia
/// P2P_CLUSTER. Cada teléfono anuncia y busca a la vez; para no pedirse
/// conexión los dos al mismo tiempo, solo pide el de nombre «menor» (con un
/// respaldo si el otro no lo hace). Máx. [maxConnections] conexiones y
/// [cooldown] antes de reconectar con el mismo vecino.
class NearbyMeshTransport implements MeshTransport {
  NearbyMeshTransport({
    this.maxConnections = 3,
    this.cooldown = const Duration(seconds: 30),
    String? name,
  }) : _name = name ?? 'HN-${generateUuidV4().substring(0, 8)}';

  static const String serviceId = 'mx.veracruz.agua_lluvia.malla';

  final int maxConnections;
  final Duration cooldown;
  final String _name;
  final Nearby _nearby = Nearby();
  final StreamController<MeshEvent> _events = StreamController<MeshEvent>.broadcast();
  final StreamController<MeshIncoming> _messages = StreamController<MeshIncoming>.broadcast();

  /// endpointId -> nombre del vecino visto en el aire.
  final Map<String, String> _found = {};
  final Map<String, DateTime> _foundAt = {};
  final Set<String> _connected = {};
  final Set<String> _requesting = {};

  /// nombre del vecino -> última conexión/intento (enfriamiento).
  final Map<String, DateTime> _lastContact = {};
  Timer? _tick;
  bool _running = false;

  @override
  bool get running => _running;

  @override
  Set<String> get connectedPeers => Set.unmodifiable(_connected);

  @override
  int get discoveredCount => _found.length;

  @override
  Stream<MeshEvent> get events => _events.stream;

  @override
  Stream<MeshIncoming> get messages => _messages.stream;

  void _emit(MeshEventKind k, {String? peer, String text = ''}) =>
      _events.add(MeshEvent(k, peerId: peer, text: text));

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    try {
      final adv = await _nearby.startAdvertising(
        _name,
        Strategy.P2P_CLUSTER,
        serviceId: serviceId,
        onConnectionInitiated: _onInitiated,
        onConnectionResult: _onResult,
        onDisconnected: _onDisconnected,
      );
      final dis = await _nearby.startDiscovery(
        _name,
        Strategy.P2P_CLUSTER,
        serviceId: serviceId,
        onEndpointFound: _onFound,
        onEndpointLost: _onLost,
      );
      _emit(MeshEventKind.info, text: 'Transporte Nearby iniciado como $_name (anuncio: $adv, búsqueda: $dis)');
    } catch (e) {
      _running = false;
      await _safe(_nearby.stopAdvertising);
      await _safe(_nearby.stopDiscovery);
      _emit(MeshEventKind.error, text: 'No se pudo iniciar Nearby: $e');
      rethrow;
    }
    _tick = Timer.periodic(const Duration(seconds: 5), (_) => _connectToFound());
  }

  @override
  Future<void> stop() async {
    _running = false;
    _tick?.cancel();
    _tick = null;
    await _safe(_nearby.stopAdvertising);
    await _safe(_nearby.stopDiscovery);
    await _safe(_nearby.stopAllEndpoints);
    _found.clear();
    _foundAt.clear();
    _connected.clear();
    _requesting.clear();
  }

  Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      debugPrint('[malla] $e');
    }
  }

  void _onFound(String id, String name, String service) {
    _found[id] = name;
    _foundAt[id] = DateTime.now();
    _emit(MeshEventKind.peerFound, peer: id, text: name);
    _connectToFound();
  }

  void _onLost(String? id) {
    if (id == null) return;
    _found.remove(id);
    _foundAt.remove(id);
    _emit(MeshEventKind.peerLost, peer: id);
  }

  @override
  void requestExchange() {
    _lastContact.clear();
    _connectToFound();
  }

  void _connectToFound() {
    if (!_running) return;
    final now = DateTime.now();
    for (final entry in _found.entries.toList()) {
      if (_connected.length + _requesting.length >= maxConnections) return;
      final id = entry.key, theirName = entry.value;
      if (_connected.contains(id) || _requesting.contains(id)) continue;
      final last = _lastContact[theirName];
      if (last != null && now.difference(last) < cooldown) continue;
      // Pide el de nombre menor; el otro espera (o pide si pasan 12 s sin que
      // el primero lo haga).
      final iGoFirst = _name.compareTo(theirName) < 0;
      final waited = now.difference(_foundAt[id] ?? now);
      if (!iGoFirst && waited < const Duration(seconds: 12)) continue;
      _requesting.add(id);
      _lastContact[theirName] = now;
      _nearby
          .requestConnection(
            _name,
            id,
            onConnectionInitiated: _onInitiated,
            onConnectionResult: _onResult,
            onDisconnected: _onDisconnected,
          )
          .catchError((Object e) {
        _requesting.remove(id);
        _emit(MeshEventKind.info, text: 'No se pudo pedir conexión con $theirName: $e');
        return false;
      });
    }
  }

  void _onInitiated(String id, ConnectionInfo info) {
    _lastContact[info.endpointName] = DateTime.now();
    if (_connected.length >= maxConnections && !_connected.contains(id)) {
      _nearby.rejectConnection(id);
      _requesting.remove(id);
      return;
    }
    _found.putIfAbsent(id, () => info.endpointName);
    _nearby
        .acceptConnection(id, onPayLoadRecieved: _onPayload)
        .catchError((Object e) {
      _emit(MeshEventKind.error, text: 'No se pudo aceptar a ${info.endpointName}: $e');
      return false;
    });
  }

  void _onResult(String id, Status status) {
    _requesting.remove(id);
    if (status == Status.CONNECTED) {
      _connected.add(id);
      _emit(MeshEventKind.peerConnected, peer: id, text: _found[id] ?? id);
    } else {
      _emit(MeshEventKind.info, text: 'Conexión con ${_found[id] ?? id} no establecida ($status)');
    }
  }

  void _onDisconnected(String id) {
    _requesting.remove(id);
    if (_connected.remove(id)) {
      _emit(MeshEventKind.peerDisconnected, peer: id, text: _found[id] ?? id);
    }
  }

  void _onPayload(String id, Payload payload) {
    final bytes = payload.bytes;
    if (payload.type == PayloadType.BYTES && bytes != null) {
      _messages.add(MeshIncoming(id, bytes));
    }
  }

  @override
  Future<void> send(String peerId, Uint8List bytes) async {
    if (!_connected.contains(peerId)) return;
    await _nearby.sendBytesPayload(peerId, bytes);
  }

  @override
  Future<void> disconnect(String peerId) async {
    await _safe(() => _nearby.disconnectFromEndpoint(peerId));
    _onDisconnected(peerId);
  }
}
