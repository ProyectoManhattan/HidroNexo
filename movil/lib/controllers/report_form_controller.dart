import 'package:flutter/material.dart';

import '../data/report_repository.dart';
import '../models/coordinates.dart';
import '../models/incident_report.dart';
import '../models/new_report.dart';
import '../models/report_type.dart';
import '../services/location_service.dart';
import '../services/photo_service.dart';

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
  String? _photoName;
  bool _sending = false;

  ReportType get type => _type;
  int get severity => _severity;
  bool get sending => _sending;
  String? get locationLabel => _location?.address;
  String? get photoName => _photoName;

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

  Future<void> pickPhoto() async {
    final name = await _photoService.pickPhotoName();
    if (name == null) return;
    _photoName = name;
    notifyListeners();
  }

  /// Envía el reporte y devuelve el folio. Limpia el formulario solo si se envió.
  /// Lanza [RepositoryException] si falla: el formulario conserva lo escrito.
  Future<String> submit() async {
    if (_sending) throw const RepositoryException('Ya se está enviando el reporte.');
    final location = _location!;
    final Coordinates position = location.position;
    _sending = true;
    notifyListeners();
    try {
      final folio = await _repository.submit(
        NewReport(
          type: _type,
          neighborhood: location.neighborhood,
          address: location.address,
          position: position,
          description: descriptionController.text.trim(),
          severity: _severity,
          photoName: _photoName,
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
    _photoName = null;
    notifyListeners();
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }
}
