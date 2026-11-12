import 'package:agua_lluvia/models/coordinates.dart';
import 'package:agua_lluvia/models/incident_report.dart';
import 'package:agua_lluvia/models/report_status.dart';
import 'package:agua_lluvia/models/report_type.dart';
import 'package:agua_lluvia/widgets/map/maplibre_map_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reportsToGeoJson usa [lon, lat] y deja folio y tipo', () {
    final json = reportsToGeoJson(const [
      IncidentReport(
        folio: 'AV-15',
        type: ReportType.flood,
        neighborhood: 'Centro',
        address: 'Calle 1',
        description: '',
        dateLabel: '',
        status: ReportStatus.pending,
        position: Coordinates(19.17, -96.13),
      ),
    ]);
    final feature = (json['features'] as List).single as Map;
    expect((feature['geometry'] as Map)['coordinates'], [-96.13, 19.17]);
    expect(feature['properties'], {'folio': 'AV-15', 'tipo': 'inundacion'});
  });
}
