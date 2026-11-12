import 'package:agua_lluvia/controllers/report_form_controller.dart';
import 'package:agua_lluvia/data/mock_report_repository.dart';
import 'package:agua_lluvia/data/report_repository.dart';
import 'package:agua_lluvia/models/new_report.dart';
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

  group('foto', () {
    test('si la subida falla no se pierde el reporte: se puede reintentar o enviar sin foto', () async {
      final repo = _FakeRepo()..failUpload = true;
      final controller = ReportFormController(
        repository: repo,
        locationService: SimulatedLocationService(),
        photoService: SimulatedPhotoService(),
      );
      addTearDown(controller.dispose);
      await controller.useMyLocation();
      controller.descriptionController.text = 'Agua en la calle';
      await controller.pickPhoto(PhotoSource.gallery);
      expect(controller.photo, isNotNull);

      await expectLater(controller.submit(), throwsA(isA<PhotoUploadException>()));
      expect(repo.submitted, isEmpty);
      expect(controller.descriptionController.text, 'Agua en la calle');
      expect(controller.photo, isNotNull);

      repo.failUpload = false;
      await controller.submit();
      expect(repo.uploads, 2);
      expect(repo.submitted.single.photoUrl, 'http://x/foto.jpg');
    });

    test('enviar sin foto crea el reporte sin foto_url', () async {
      final repo = _FakeRepo()..failUpload = true;
      final controller = ReportFormController(
        repository: repo,
        locationService: SimulatedLocationService(),
        photoService: SimulatedPhotoService(),
      );
      addTearDown(controller.dispose);
      await controller.useMyLocation();
      controller.descriptionController.text = 'x';
      await controller.pickPhoto(PhotoSource.camera);
      await controller.submit(withoutPhoto: true);
      expect(repo.submitted.single.photoUrl, isNull);
    });

    test('quitar la foto la descarta', () async {
      final controller = ReportFormController(
        repository: MockReportRepository(),
        locationService: SimulatedLocationService(),
        photoService: SimulatedPhotoService(),
      );
      addTearDown(controller.dispose);
      await controller.pickPhoto(PhotoSource.gallery);
      controller.removePhoto();
      expect(controller.photo, isNull);
    });
  });
}

class _FakeRepo extends MockReportRepository {
  bool failUpload = false;
  int uploads = 0;
  final List<NewReport> submitted = [];

  @override
  Future<String> uploadPhoto(PickedPhoto photo) async {
    uploads++;
    if (failUpload) throw const RepositoryException('La foto pesa demasiado (máximo 5 MB).');
    return 'http://x/foto.jpg';
  }

  @override
  Future<String> submit(NewReport report) {
    submitted.add(report);
    return super.submit(report);
  }
}
