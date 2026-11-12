import 'dart:async';
import 'dart:typed_data';

/// Evento del transporte (vecinos que aparecen, se conectan, errores).
enum MeshEventKind { peerFound, peerLost, peerConnected, peerDisconnected, info, error }

class MeshEvent {
  const MeshEvent(this.kind, {this.peerId, this.text = ''});

  final MeshEventKind kind;
  final String? peerId;
  final String text;
}

/// Bytes recibidos de un vecino.
class MeshIncoming {
  const MeshIncoming(this.peerId, this.bytes);

  final String peerId;
  final Uint8List bytes;
}

/// Transporte de la malla: quita al nodo la dependencia de Bluetooth.
/// Implementaciones: [NearbyMeshTransport] (real) e [InMemoryMeshTransport].
abstract class MeshTransport {
  /// Empieza a anunciarse y a buscar vecinos. Lanza si no se puede.
  Future<void> start();

  /// Desconecta todo y deja de anunciarse/buscar.
  Future<void> stop();

  bool get running;

  /// Vecinos con conexión abierta ahora.
  Set<String> get connectedPeers;

  /// Vecinos vistos en el aire (conectados o no).
  int get discoveredCount;

  Stream<MeshEvent> get events;
  Stream<MeshIncoming> get messages;

  Future<void> send(String peerId, Uint8List bytes);

  Future<void> disconnect(String peerId);

  /// Pide intentar conectar ya con los vecinos vistos (salta el enfriamiento).
  void requestExchange();
}
