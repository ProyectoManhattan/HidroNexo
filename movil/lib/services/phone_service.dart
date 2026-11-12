import 'package:url_launcher/url_launcher.dart';

/// Contrato para llamadas telefónicas.
abstract class PhoneService {
  Future<bool> call(String number);
}

/// Simulado: no abre el marcador. Útil en pruebas y emulador sin teléfono.
class SimulatedPhoneService implements PhoneService {
  @override
  Future<bool> call(String number) async => true;
}

/// Abre el marcador del celular con el número (no llama solo: el usuario confirma).
class DevicePhoneService implements PhoneService {
  @override
  Future<bool> call(String number) async {
    try {
      return await launchUrl(Uri(scheme: 'tel', path: number));
    } catch (_) {
      return false;
    }
  }
}
