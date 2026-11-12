import 'package:flutter/material.dart';

import '../data/report_repository.dart';
import '../models/coordinates.dart';
import '../models/incident_report.dart';
import '../models/new_report.dart';
import '../models/report_type.dart';
import '../services/location_service.dart';
import '../core/utils/uuid.dart';
import '../services/pending_report_queue.dart';
import '../services/photo_service.dart';

/// La foto no se pudo subir. El reporte NO se envió y el formulario sigue intacto.
class PhotoUploadException extends RepositoryException {
  const PhotoUploadException(super.message, {super.retryable});
}

/// Resultado de [ReportFormController.submit].
class SubmitResult {
  const SubmitResult.sent(String this.folio) : queued = false;
  const SubmitResult.queued()
      : folio = null,
        queued = true;

  /// Folio del reporte enviado; null si quedó en cola por falta de señal.
  final String? folio;

  /// true si no hubo red y el reporte quedó guardado para enviarse solo.
  final bool queued;
}

/// Estado y lógica del formulario de reportes.
class ReportFormController extends ChangeNotifier {
  ReportFormController({
    required ReportRepository repository,
    required LocationService locationService,
    required PhotoService photoService,
    PendingReportQueue? queue,
    this.onSubmitted,
  })  : _repository = repository,
        _locationService = locationService,
        _photoService = photoService,
        _queue = queue {
    // Si el usuario cambia el texto, es otro reporte: otra llave de idempotencia.
    descriptionController.addListener(_newIdentity);
  }

  final PendingReportQueue? _queue;

  /// Llave de idempotencia del envío en curso. Se conserva entre reintentos del
  /// mismo contenido (así una respuesta perdida no duplica el reporte).
  String? _clienteId;

  void _newIdentity() => _clienteId = null;

  final ReportRepository _repository;
  final LocationService _locationService;
  final PhotoService _photoService;

  /// Se llama tras un envío exitoso (para refrescar el resto de la app).
  final VoidCallback? onSubmitted;

  final TextEditingController descriptionController = TextEditingController();

  ReportType _type = ReportType.flood;
  int _severity = 2;
  UserLocation? _location;
  PickedPhoto? _photo;

  /// URL de la foto ya subida, para no resubirla si falla el envío del reporte.
  String? _uploadedUrl;
  bool _sending = false;

  ReportType get type => _type;
  int get severity => _severity;
  bool get sending => _sending;
  String? get locationLabel => _location?.address;
  PickedPhoto? get photo => _photo;

  bool get isValid =>
      _location != null && descriptionController.text.trim().isNotEmpty;

  void selectType(ReportType type) {
    _type = type;
    _newIdentity();
    notifyListeners();
  }

  void selectSeverity(int severity) {
    _severity = severity;
    _newIdentity();
    notifyListeners();
  }

  /// Obtiene la ubicación. Lanza [LocationException] si no se pudo.
  Future<void> useMyLocation() async {
    _location = await _locationService.getCurrentLocation();
    _newIdentity();
    notifyListeners();
  }

  Future<void> pickPhoto(PhotoSource source) async {
    final picked = await _photoService.pickPhoto(source);
    if (picked == null) return;
    _photo = picked;
    _uploadedUrl = null;
    _newIdentity();
    notifyListeners();
  }

  void removePhoto() {
    _photo = null;
    _uploadedUrl = null;
    _newIdentity();
    notifyListeners();
  }

  /// Envía el reporte. Limpia el formulario si se envió o quedó en cola.
  ///
  /// - Falla de red/tiempo/5xx: si hay cola, lo guarda como pendiente
  ///   ([SubmitResult.queued]). Si ya había otro pendiente lanza
  ///   [PendingReportExistsException] (el formulario no se toca); la pantalla
  ///   pregunta y vuelve a llamar con [replacePending] true.
  /// - 4xx de validación: lanza [RepositoryException] y el formulario conserva
  ///   lo escrito.
  /// - Si la foto no se pudo subir por otra razón lanza [PhotoUploadException]
  ///   sin crear el reporte; la pantalla puede reintentar o llamar con
  ///   [withoutPhoto] true.
  Future<SubmitResult> submit({bool withoutPhoto = false, bool replacePending = false}) async {
    if (_sending) throw const RepositoryException('Ya se está enviando el reporte.');
    final location = _location!;
    final Coordinates position = location.position;
    final clienteId = _clienteId ??= generateUuidV4();
    final photo = withoutPhoto ? null : _photo;
    _sending = true;
    notifyListeners();
    String? photoUrl;
    NewReport build() => NewReport(
          type: _type,
          neighborhood: location.neighborhood,
          address: location.address,
          position: position,
          description: descriptionController.text.trim(),
          severity: _severity,
          photoUrl: photoUrl,
          clienteId: clienteId,
        );
    try {
      if (photo != null) {
        photoUrl = _uploadedUrl;
        if (photoUrl == null) {
          try {
            photoUrl = _uploadedUrl = await _repository.uploadPhoto(photo);
          } on RepositoryException catch (e) {
            if (e.retryable && _queue != null) {
              return await _enqueue(build(), photo.path, replacePending);
            }
            throw PhotoUploadException(e.message, retryable: e.retryable);
          }
        }
      }
      final String folio;
      try {
        folio = await _repository.submit(build());
      } on RepositoryException catch (e) {
        if (e.retryable && _queue != null) {
          return await _enqueue(build(), photo?.path, replacePending);
        }
        rethrow;
      }
      reset();
      onSubmitted?.call();
      return SubmitResult.sent(folio);
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<SubmitResult> _enqueue(NewReport report, String? photoPath, bool replace) async {
    final queue = _queue!;
    if (queue.hasPending && !replace) throw const PendingReportExistsException();
    final saved = await queue.enqueue(report, photoPath: photoPath, replace: replace);
    if (saved == null) {
      // La BD local no está disponible: no se puede guardar, se avisa del fallo.
      throw const RepositoryException('Sin conexión con el servidor. Revisa tu internet.');
    }
    reset();
    return const SubmitResult.queued();
  }

  Future<IncidentReport?> findReport(String folio) => _repository.findByFolio(folio);

  void reset() {
    _clienteId = null;
    descriptionController.clear();
    _severity = 2;
    _location = null;
    _photo = null;
    _uploadedUrl = null;
    notifyListeners();
  }

  @override
  void dispose() {
    descriptionController.removeListener(_newIdentity);
    descriptionController.dispose();
    super.dispose();
  }
}
