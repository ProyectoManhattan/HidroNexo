/// Contrato para llamadas telefónicas.
abstract class PhoneService {
  Future<bool> call(String number);
}

/// Simulado: no abre el marcador. Para llamadas reales, implementa
/// [PhoneService] con `url_launcher`.
class SimulatedPhoneService implements PhoneService {
  @override
  Future<bool> call(String number) async => true;
}
