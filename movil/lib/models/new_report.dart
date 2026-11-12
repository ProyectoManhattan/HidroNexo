import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'report_type.dart';

/// Datos capturados en el formulario antes de enviarse.
class NewReport {
  const NewReport({
    required this.type,
    required this.placeLabel,
    required this.position,
    required this.description,
    this.photoName,
  });

  final ReportType type;
  final String placeLabel;
  final LatLng position;
  final String description;
  final String? photoName;
}
