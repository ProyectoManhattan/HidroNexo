import 'dart:async';
import 'dart:typed_data';

import 'mesh_transport.dart';

/// Red en memoria: nodos unidos por enlaces explícitos (`link`). Sirve para
/// pruebas y para abrir la pantalla sin hardware (USE_MOCK).
class InMemoryMeshNetwork {
  final Map<String, InMemoryMeshTransport> _nodes = {};
  final Set<String> _links = {};

  /// Crea (o devuelve) el transporte con ese id.
  InMemoryMeshTransport node(String id) => _nodes.putIfAbsent(id, () => InMemoryMeshTransport._(this, id));

  static String _key(String a, String b) => a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

  bool linked(String a, String b) => _links.contains(_key(a, b));

  Iterable<String> _neighbors(String id) sync* {
    for (final k in _links) {
      final parts = k.split('|');
      if (parts[0] == id) yield parts[1];
      if (parts[1] == id) yield parts[0];
    }
  }

  /// Une dos nodos (como si entraran en alcance). Si ambos están activos se
  /// «conectan» y cada uno recibe el evento `peerConnected`.
  void link(String a, String b) {
    _links.add(_key(a, b));
    _nodes[a]?._seen(b);
    _nodes[b]?._seen(a);
    _tryConnect(a, b);
  }

  void unlink(String a, String b) {
    _links.remove(_key(a, b));
    _nodes[a]?._drop(b);
    _nodes[b]?._drop(a);
  }

  void _tryConnect(String a, String b) {
    final na = _nodes[a], nb = _nodes[b];
    if (na == null || nb == null || !na.running || !nb.running || !linked(a, b)) return;
    if (na._connected.contains(b)) return;
    na._connected.add(b);
    nb._connected.add(a);
    na._events.add(MeshEvent(MeshEventKind.peerConnected, peerId: b));
    nb._events.add(MeshEvent(MeshEventKind.peerConnected, peerId: a));
  }
}

class InMemoryMeshTransport implements MeshTransport {
  InMemoryMeshTransport._(this._net, this.id);

  final InMemoryMeshNetwork _net;
  final String id;
  final Set<String> _connected = {};
  final StreamController<MeshEvent> _events = StreamController<MeshEvent>.broadcast();
  final StreamController<MeshIncoming> _messages = StreamController<MeshIncoming>.broadcast();
  bool _running = false;

  @override
  bool get running => _running;

  @override
  Set<String> get connectedPeers => Set.unmodifiable(_connected);

  @override
  int get discoveredCount => _running ? _net._neighbors(id).length : 0;

  @override
  Stream<MeshEvent> get events => _events.stream;

  @override
  Stream<MeshIncoming> get messages => _messages.stream;

  @override
  Future<void> start() async {
    _running = true;
    for (final n in _net._neighbors(id).toList()) {
      _net._tryConnect(id, n);
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    for (final p in _connected.toList()) {
      await disconnect(p);
    }
  }

  void _seen(String peer) {
    if (_running) _events.add(MeshEvent(MeshEventKind.peerFound, peerId: peer));
  }

  void _drop(String peer) {
    if (_connected.remove(peer)) {
      _events.add(MeshEvent(MeshEventKind.peerDisconnected, peerId: peer));
    }
  }

  @override
  Future<void> send(String peerId, Uint8List bytes) async {
    final peer = _net._nodes[peerId];
    if (!_connected.contains(peerId) || peer == null) return;
    // Entrega asíncrona, como en una radio real.
    Future<void>.microtask(() {
      if (peer._running && peer._connected.contains(id)) {
        peer._messages.add(MeshIncoming(id, bytes));
      }
    });
  }

  @override
  Future<void> disconnect(String peerId) async {
    final peer = _net._nodes[peerId];
    _drop(peerId);
    peer?._drop(id);
  }

  @override
  void requestExchange() {
    for (final n in _net._neighbors(id).toList()) {
      _net._tryConnect(id, n);
    }
  }
}
