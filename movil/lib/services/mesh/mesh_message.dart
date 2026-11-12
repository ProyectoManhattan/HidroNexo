import 'dart:convert';
import 'dart:typed_data';

/// Tipo de mensaje de la malla.
enum MeshKind {
  alerta,
  reporte;

  static MeshKind? parse(Object? v) {
    for (final k in MeshKind.values) {
      if (k.name == v) return k;
    }
    return null;
  }
}

/// Mensaje que viaja por la malla Bluetooth (JSON compacto, < 1 KB).
///
/// SIN firma ni cifrado: es un prototipo (ver docs/modo-sin-internet.md).
class MeshMessage {
  const MeshMessage({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.expiresAt,
    this.cps = const [],
    this.level = 'alto',
    this.text = '',
    this.ttl = defaultTtl,
    this.hops = 0,
    this.hopsOutside = 0,
    this.simulated = false,
    this.payload = const {},
  });

  static const int defaultTtl = 25;
  static const int maxBytes = 1024;

  /// UUID v4 (o un id determinista `alerta-<n>` / `rep-<cliente_id>` cuando el
  /// mensaje nace de datos reales, para no publicarlo dos veces).
  final String id;
  final MeshKind kind;

  /// Códigos postales destino (solo alertas).
  final List<String> cps;
  final String level;
  final String text;

  /// Epoch en segundos.
  final int createdAt;
  final int expiresAt;
  final int ttl;

  /// Saltos recorridos hasta quien lo envió.
  final int hops;

  /// Saltos consecutivos dados fuera de la zona destino.
  final int hopsOutside;

  /// Alerta de prueba: la pantalla completa muestra «SIMULACIÓN».
  final bool simulated;

  /// Reportes: campos del reporte pendiente (sin foto).
  final Map<String, dynamic> payload;

  bool isExpired(DateTime now) => expiresAt <= now.millisecondsSinceEpoch ~/ 1000;

  MeshMessage copyWith({int? hops, int? hopsOutside}) => MeshMessage(
        id: id,
        kind: kind,
        createdAt: createdAt,
        expiresAt: expiresAt,
        cps: cps,
        level: level,
        text: text,
        ttl: ttl,
        hops: hops ?? this.hops,
        hopsOutside: hopsOutside ?? this.hopsOutside,
        simulated: simulated,
        payload: payload,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': kind.name,
        if (cps.isNotEmpty) 'cps': cps,
        'nivel': level,
        if (text.isNotEmpty) 'texto': text,
        'creada_en': createdAt,
        'expira_en': expiresAt,
        'ttl': ttl,
        'saltos': hops,
        'saltos_fuera': hopsOutside,
        if (simulated) 'sim': true,
        if (payload.isNotEmpty) 'payload': payload,
      };

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  /// Null si el JSON no es un mensaje válido.
  static MeshMessage? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final kind = MeshKind.parse(json['tipo']);
    final created = json['creada_en'];
    final expires = json['expira_en'];
    if (id is! String || id.isEmpty || id.length > 64 || kind == null) return null;
    if (created is! int || expires is! int) return null;
    int intOr(Object? v, int d) => v is int ? v : d;
    final cps = json['cps'];
    final payload = json['payload'];
    return MeshMessage(
      id: id,
      kind: kind,
      createdAt: created,
      expiresAt: expires,
      cps: cps is List ? cps.map((e) => '$e').toList() : const [],
      level: '${json['nivel'] ?? 'alto'}',
      text: '${json['texto'] ?? ''}',
      ttl: intOr(json['ttl'], defaultTtl),
      hops: intOr(json['saltos'], 0),
      hopsOutside: intOr(json['saltos_fuera'], 0),
      simulated: json['sim'] == true,
      payload: payload is Map ? Map<String, dynamic>.from(payload) : const {},
    );
  }

  static MeshMessage? fromBytes(List<int> bytes) {
    try {
      return fromJson(jsonDecode(utf8.decode(bytes)));
    } catch (_) {
      return null;
    }
  }

  /// Nombre corto para el log.
  String get shortId => id.length <= 8 ? id : id.substring(0, 8);
}
