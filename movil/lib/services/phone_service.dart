import 'package:url_launcher/url_launcher.dart';

/// Abre el marcador del teléfono.
class PhoneService {
  Future<bool> call(String number) {
    return launchUrl(Uri(scheme: 'tel', path: number));
  }
}
