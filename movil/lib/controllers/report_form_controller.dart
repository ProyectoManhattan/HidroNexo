import 'package:flutter/material.dart';

import '../data/report_repository.dart';
import '../models/coordinates.dart';
import '../models/incident_report.dart';
import '../models/new_report.dart';
import '../models/report_type.dart';
import '../services/location_service.dart';
import '../services/photo_service.dart';

/// La foto no se pudo subir. El reporte NO se envió y el formulario sigue intacto.
class PhotoUploadException extends RepositoryException {
  const PhotoUploadException(super.message);
}

/// Estado y lógica del formulario de reportes.
class ReportFormController extends ChangeNotifier {
  ReportFormController({
    required ReportRepository repository,
    required LocationService locationService,
    required PhotoService photoService,
    this.onSubmitted,
  })  : _repository = repository,
        _locationService = locationService,
        _photoService = photoService;

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
    notifyListeners();
  }

  void selectSeverity(int severity) {
    _severity = severity;
    notifyListeners();
  }

  /// Obtiene la ubicación. Lanza [LocationException] si no se pudo.
  Future<void> useMyLocation() async {
    _location = await _locationService.getCurrentLocation();
    notifyListeners();
  }

  Future<void> pickPhoto(PhotoSource source) async {
    final picked = await _photoService.pickPhoto(source);
    if (picked == null) return;
    _photo = picked;
    _uploadedUrl = null;
    notifyListeners();
  }

  void removePhoto() {
    _photo = null;
    _uploadedUrl = null;
    notifyListeners();
  }

  /// Envía el reporte y devuelve el folio. Limpia el formulario solo si se envió.
  /// Lanza [RepositoryException] si falla: el formulario conserva lo escrito.
  /// Si la foto no se pudo subir lanza [PhotoUploadException] sin crear el
  /// reporte; la pantalla puede reintentar o llamar con [withoutPhoto] true.
  Future<String> submit({bool withoutPhoto = false}) async {
    if (_sending) throw const RepositoryException('Ya se está enviando el reporte.');
    final location = _location!;
    final Coordinates position = location.position;
    _sending = true;
    notifyListeners();
    try {
      String? photoUrl;
      final photo = withoutPhoto ? null : _photo;
      if (photo != null) {
        photoUrl = _uploadedUrl;
        if (photoUrl == null) {
          try {
            photoUrl = _uploadedUrl = await _repository.uploadPhoto(photo);
          } on RepositoryException catch (e) {
            throw PhotoUploadException(e.message);
          }
        }
      }
      final folio = await _repository.submit(
        NewReport(
          type: _type,
          neighborhood: location.neighborhood,
          address: location.address,
          position: position,
          description: descriptionController.text.trim(),
          severity: _severity,
          photoUrl: photoUrl,
        ),
      );
      reset();
      onSubmitted?.call();
      return folio;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<IncidentReport?> findReport(String folio) => _repository.findByFolio(folio);

  void reset() {
    descriptionController.clear();
    _severity = 2;
    _location = null;
    _photo = null;
    _uploadedUrl = null;
    notifyListeners();
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }
}
