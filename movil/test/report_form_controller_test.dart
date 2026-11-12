import 'package:agua_lluvia/controllers/report_form_controller.dart';
import 'package:agua_lluvia/data/mock_report_repository.dart';
import 'package:agua_lluvia/services/location_service.dart';
import 'package:agua_lluvia/services/photo_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('avisa que los datos cambiaron solo tras un envío exitoso', () async {
    var avisos = 0;
    final controller = ReportFormController(
      repository: MockReportRepository(),
      locationService: SimulatedLocationService(),
      photoService: SimulatedPhotoService(),
      onSubmitted: () => avisos++,
    );
    addTearDown(controller.dispose);

    await controller.useMyLocation();
    controller.descriptionController.text = 'Agua en la calle';
    expect(avisos, 0);

    await controller.submit();
    expect(avisos, 1);
  });
}
