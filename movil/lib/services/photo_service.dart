import 'package:image_picker/image_picker.dart';

/// Contrato para adjuntar fotos.
abstract class PhotoService {
  /// Devuelve el nombre del archivo elegido o null si se canceló.
  Future<String?> pickPhotoName();
}

class GalleryPhotoService implements PhotoService {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<String?> pickPhotoName() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    return file?.name;
  }
}
