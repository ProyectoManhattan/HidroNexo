import 'package:flutter/foundation.dart';

/// Avisa a las pantallas que los datos del servidor cambiaron (por ejemplo,
/// tras enviar un reporte) para que se recarguen. Las pestañas se conservan
/// vivas, así que no se recargan solas al volver a ellas.
class DataRefresh extends ChangeNotifier {
  void notifyChanged() => notifyListeners();
}
