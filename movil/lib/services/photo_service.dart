/// Contrato para adjuntar fotos.
abstract class PhotoService {
  /// Devuelve el nombre del archivo elegido o null si se canceló.
  Future<String?> pickPhotoName();
}

/// Simulado: no abre galería ni cámara. Para fotos reales, implementa
/// [PhotoService] con `image_picker`.
class SimulatedPhotoService implements PhotoService {
  @override
  Future<String?> pickPhotoName() async => 'foto_demo.jpg';
}
