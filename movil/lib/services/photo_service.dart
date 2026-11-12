import 'package:image_picker/image_picker.dart';

/// De dónde se toma la foto.
enum PhotoSource { camera, gallery }

/// Foto elegida por el usuario (archivo local ya reducido).
class PickedPhoto {
  const PickedPhoto({required this.path, required this.name});

  final String path;
  final String name;

  /// Tipo MIME según la extensión. Solo jpeg/png/webp los acepta el backend;
  /// cualquier otra cosa se manda como jpeg (image_picker re-codifica a jpeg).
  String get mimeType {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

/// Contrato para adjuntar fotos.
abstract class PhotoService {
  /// Devuelve la foto elegida o null si se canceló.
  Future<PickedPhoto?> pickPhoto(PhotoSource source);
}

/// Real: cámara o galería con `image_picker`, reduciendo tamaño y peso.
class DevicePhotoService implements PhotoService {
  DevicePhotoService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedPhoto?> pickPhoto(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
    if (file == null) return null;
    return PickedPhoto(path: file.path, name: file.name);
  }
}

/// Simulado (USE_MOCK y pruebas): no abre cámara ni galería.
class SimulatedPhotoService implements PhotoService {
  @override
  Future<PickedPhoto?> pickPhoto(PhotoSource source) async =>
      const PickedPhoto(path: '/simulado/foto_demo.jpg', name: 'foto_demo.jpg');
}
