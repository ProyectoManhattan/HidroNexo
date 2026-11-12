import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/report_repository.dart';
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
  })  : _repository = repository,
        _locationService = locationService,
        _photoService = photoService;

  final ReportRepository _repository;
  final LocationService _locationService;
  final PhotoService _photoService;

  final TextEditingController descriptionController = TextEditingController();

  ReportType _type = ReportType.flood;
  String? _locationLabel;
  LatLng? _position;
  String? _photoName;

  ReportType get type => _type;
  String? get locationLabel => _locationLabel;
  String? get photoName => _photoName;

  bool get isValid =>
      _position != null && descriptionController.text.trim().isNotEmpty;

  void selectType(ReportType type) {
    _type = type;
    notifyListeners();
  }

  Future<void> useMyLocation() async {
    final location = await _locationService.getCurrentLocation();
    _locationLabel = location.label;
    _position = location.position;
    notifyListeners();
  }

  Future<void> pickPhoto() async {
    final name = await _photoService.pickPhotoName();
    if (name == null) return;
    _photoName = name;
    notifyListeners();
  }

  /// Envía el reporte y devuelve el folio. Limpia el formulario al terminar.
  Future<String> submit() async {
    final folio = await _repository.submit(
      NewReport(
        type: _type,
        placeLabel: _locationLabel!,
        position: _position!,
        description: descriptionController.text.trim(),
        photoName: _photoName,
      ),
    );
    reset();
    return folio;
  }

  IncidentReport? findReport(String folio) => _repository.findByFolio(folio);

  void reset() {
    descriptionController.clear();
    _locationLabel = null;
    _position = null;
    _photoName = null;
    notifyListeners();
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }
}
