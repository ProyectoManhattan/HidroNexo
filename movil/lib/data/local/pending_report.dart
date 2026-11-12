import '../../models/coordinates.dart';
import '../../models/new_report.dart';
import '../../models/report_type.dart';

/// Situación de un reporte pendiente.
enum PendingStatus {
  /// Esperando señal / el próximo intento.
  waiting,

  /// Hay un envío en curso.
  retrying,

  /// El servidor lo rechazó (validación): no se reintenta, solo se puede descartar.
  failed,
}

/// Reporte guardado en el dispositivo hasta poder enviarse.
class PendingReport {
  const PendingReport({
    required this.clienteId,
    required this.type,
    required this.severity,
    required this.position,
    required this.description,
    required this.createdAt,
    this.address = '',
    this.photoPath,
    this.photoUrl,
    this.photoFailures = 0,
    this.attempts = 0,
    this.nextAttempt,
    this.status = PendingStatus.waiting,
    this.error,
  });

  /// UUID v4: llave de idempotencia (`cliente_id`) del backend.
  final String clienteId;
  final ReportType type;
  final int severity;
  final Coordinates position;
  final String description;
  final String address;
  final DateTime createdAt;

  /// Copia local de la foto (directorio de documentos de la app).
  final String? photoPath;

  /// Si la foto ya se subió, su URL (no se vuelve a subir).
  final String? photoUrl;
  final int photoFailures;
  final int attempts;
  final DateTime? nextAttempt;
  final PendingStatus status;
  final String? error;

  bool get hasPhoto => photoPath != null || photoUrl != null;

  PendingReport copyWith({
    String? photoPath,
    bool clearPhotoPath = false,
    String? photoUrl,
    int? photoFailures,
    int? attempts,
    DateTime? nextAttempt,
    bool clearNextAttempt = false,
    PendingStatus? status,
    String? error,
    bool clearError = false,
  }) {
    return PendingReport(
      clienteId: clienteId,
      type: type,
      severity: severity,
      position: position,
      description: description,
      address: address,
      createdAt: createdAt,
      photoPath: clearPhotoPath ? null : (photoPath ?? this.photoPath),
      photoUrl: photoUrl ?? this.photoUrl,
      photoFailures: photoFailures ?? this.photoFailures,
      attempts: attempts ?? this.attempts,
      nextAttempt: clearNextAttempt ? null : (nextAttempt ?? this.nextAttempt),
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Lo que se manda a `POST /reports` (con el mismo `cliente_id` siempre).
  NewReport toNewReport({String? photoUrl}) => NewReport(
        type: type,
        neighborhood: '',
        address: address,
        position: position,
        description: description,
        severity: severity,
        photoUrl: photoUrl,
        clienteId: clienteId,
      );

  Map<String, Object?> toRow() => {
        'id': 1,
        'cliente_id': clienteId,
        'categoria': type.apiKey,
        'severidad': severity,
        'lat': position.latitude,
        'lon': position.longitude,
        'descripcion': description,
        'direccion': address,
        'foto_path': photoPath,
        'foto_url': photoUrl,
        'foto_fallos': photoFailures,
        'creado_en': createdAt.millisecondsSinceEpoch,
        'intentos': attempts,
        'proximo_intento': nextAttempt?.millisecondsSinceEpoch,
        'estado': status.name,
        'error': error,
      };

  static PendingReport fromRow(Map<String, Object?> row) {
    int? ms(String key) => row[key] as int?;
    return PendingReport(
      clienteId: row['cliente_id'] as String,
      type: ReportTypeApi.fromApi(row['categoria'] as String?),
      severity: row['severidad'] as int,
      position: Coordinates((row['lat'] as num).toDouble(), (row['lon'] as num).toDouble()),
      description: row['descripcion'] as String,
      address: (row['direccion'] as String?) ?? '',
      photoPath: row['foto_path'] as String?,
      photoUrl: row['foto_url'] as String?,
      photoFailures: (row['foto_fallos'] as int?) ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(ms('creado_en') ?? 0),
      attempts: (row['intentos'] as int?) ?? 0,
      nextAttempt: ms('proximo_intento') == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(ms('proximo_intento')!),
      status: PendingStatus.values.firstWhere(
        (s) => s.name == row['estado'],
        orElse: () => PendingStatus.waiting,
      ),
      error: row['error'] as String?,
    );
  }
}
