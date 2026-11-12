import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Pide los permisos de la malla Bluetooth. Devuelve los nombres de los
/// imprescindibles que faltan (vacío = todo listo).
///
/// En Android 12+ hacen falta BLUETOOTH_SCAN/ADVERTISE/CONNECT; en Android 13+
/// también NEARBY_WIFI_DEVICES; en versiones anteriores, la ubicación. Los
/// permisos que no existen en esa versión del sistema se reportan como
/// concedidos.
Future<List<String>> requestMeshPermissions() async {
  final required = <String, Permission>{
    'Bluetooth (buscar)': Permission.bluetoothScan,
    'Bluetooth (anunciarse)': Permission.bluetoothAdvertise,
    'Bluetooth (conectar)': Permission.bluetoothConnect,
  };
  final optional = <String, Permission>{
    'Dispositivos cercanos': Permission.nearbyWifiDevices,
    'Ubicación': Permission.locationWhenInUse,
  };
  try {
    final all = await [...required.values, ...optional.values].request();
    return [
      for (final e in required.entries)
        if (!(all[e.value]?.isGranted ?? false)) e.key,
    ];
  } catch (e) {
    debugPrint('[malla] error al pedir permisos: $e');
    return ['permisos'];
  }
}
