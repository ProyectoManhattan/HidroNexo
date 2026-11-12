
import 'package:flutter/material.dart';

import '../../core/constants/app_config.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/uuid.dart';
import '../../models/coordinates.dart';
import '../../services/location_service.dart';
import '../../services/mesh/mesh_node.dart';
import '../../services/mesh/mesh_permissions.dart';
import '../../services/mesh/postal_code_resolver.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_toast.dart';

/// «Modo sin internet (experimental)»: malla Bluetooth entre teléfonos con la
/// app abierta (solo en primer plano). Muestra estado, contadores, CP propio,
/// botones de demostración y el registro de decisiones en vivo.
class MeshScreen extends StatefulWidget {
  const MeshScreen({super.key});

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const MeshScreen());

  @override
  State<MeshScreen> createState() => _MeshScreenState();
}

class _MeshScreenState extends State<MeshScreen> {
  final _node = AppDependencies.meshNode;
  final _resolver = AppDependencies.cpResolver;
  final _myCp = TextEditingController();
  final _destCp = TextEditingController();
  bool _busy = false;
  CpResult? _cp;

  @override
  void initState() {
    super.initState();
    _resolver.load().then((_) {
      if (!mounted) return;
      _myCp.text = _resolver.manual ?? '';
      _refreshCp();
    });
  }

  @override
  void dispose() {
    _myCp.dispose();
    _destCp.dispose();
    super.dispose();
  }

  Future<void> _refreshCp() async {
    final r = await _resolver.resolve();
    if (!mounted) return;
    setState(() => _cp = r);
    if (_destCp.text.isEmpty && r.cp != null) _destCp.text = r.cp!;
  }

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    try {
      if (on) {
        if (!AppConfig.useMock) {
          final missing = await requestMeshPermissions();
          if (missing.isNotEmpty) {
            _node.addLog('Faltan permisos: ${missing.join(', ')}. Se intenta activar de todos modos.', error: true);
          }
        }
        await AppDependencies.meshOrigins.enable();
        await _refreshCp();
      } else {
        await AppDependencies.meshOrigins.disable();
      }
    } catch (e) {
      if (mounted) AppToast.show(context, 'No se pudo activar el modo sin internet. Revisa Bluetooth y permisos.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveCp() async {
    final ok = await _resolver.setManual(_myCp.text);
    if (!mounted) return;
    if (!ok) {
      AppToast.show(context, 'El código postal debe tener 5 dígitos.');
      return;
    }
    _node.addLog(_resolver.manual == null
        ? 'CP manual quitado; se usará la ubicación.'
        : 'CP fijado a mano: ${_resolver.manual}.');
    FocusManager.instance.primaryFocus?.unfocus();
    await _refreshCp();
  }

  Future<void> _demoAlert() async {
    final dest = _destCp.text.trim();
    if (!RegExp(r'^\d{5}$').hasMatch(dest)) {
      AppToast.show(context, 'Escribe un CP destino de 5 dígitos.');
      return;
    }
    await _node.publishAlert(
      cps: [dest],
      level: 'alto',
      text: 'Alerta de prueba: lluvia intensa con riesgo de inundación en tu zona. '
          'Evita calles con agua y ponte a salvo en un lugar alto.',
      simulated: true,
    );
  }

  Future<void> _demoReport() async {
    Coordinates pos = AppConfig.mapCenter;
    try {
      pos = (await AppDependencies.locationService.getCurrentLocation(requestPermission: false)).position;
    } on LocationException {
      // Sin ubicación: se usa el centro de la zona.
    }
    await _node.publishReportPayload({
      'cliente_id': generateUuidV4(),
      'categoria': 'inundacion',
      'severidad': 2,
      'lat': pos.latitude,
      'lon': pos.longitude,
      'descripcion': 'Reporte de prueba enviado por la malla Bluetooth.',
      'direccion': 'Reporte de prueba (malla)',
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        title: const Text('Modo sin internet (experimental)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_node, _resolver]),
        builder: (context, _) => SingleChildScrollView(
          child: ResponsiveBody(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statusCard(palette),
                  _countersCard(palette),
                  _cpCard(palette),
                  _demoCard(palette),
                  _logCard(palette),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusCard(AppPalette palette) {
    final on = _node.started;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(on ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: on ? AppColors.ok : palette.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  on ? 'Malla activa' : 'Malla apagada',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              if (_busy)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Switch(value: on, onChanged: _toggle),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            on
                ? 'Buscando teléfonos cercanos con la app abierta (~100 m por salto). '
                    '${_node.connectedCount} conectado(s), ${_node.discoveredCount} visto(s).'
                : 'Sin internet, las alertas y reportes pueden saltar de teléfono en teléfono por Bluetooth. '
                    'Solo funciona con la app abierta en pantalla.',
            style: TextStyle(fontSize: 12.5, color: palette.muted),
          ),
        ],
      ),
    );
  }

  Widget _countersCard(AppPalette palette) {
    Widget cell(String label, int v) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: palette.pale, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text('$v', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: palette.muted)),
            ]),
          ),
        );
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(children: [
        Row(children: [
          cell('Vecinos conectados', _node.connectedCount),
          cell('Vecinos vistos', _node.discoveredCount),
          cell('Mensajes guardados', _node.storedCount),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          cell('Enviados', _node.sent),
          cell('Recibidos', _node.received),
          cell('Descartados', _node.discarded),
        ]),
      ]),
    );
  }

  Widget _cpCard(AppPalette palette) {
    final cp = _cp;
    final source = switch (cp?.source) {
      CpSource.manual => 'fijado a mano',
      CpSource.gps => 'según tu ubicación',
      _ => 'desconocido (sin zonas en caché)',
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mi código postal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${cp?.cp ?? '—'}  ·  $source', style: TextStyle(fontSize: 13, color: palette.muted)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _myCp,
                keyboardType: TextInputType.number,
                maxLength: 5,
                decoration: const InputDecoration(
                  labelText: 'Mi CP (demo)',
                  helperText: 'Tiene prioridad sobre el GPS. Vacío = usar ubicación.',
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(onPressed: _saveCp, child: const Text('Fijar')),
          ]),
        ],
      ),
    );
  }

  Widget _demoCard(AppPalette palette) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Demostración', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          TextField(
            controller: _destCp,
            keyboardType: TextInputType.number,
            maxLength: 5,
            decoration: const InputDecoration(labelText: 'CP destino de la alerta', counterText: '', isDense: true),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _node.started ? _demoAlert : null,
            icon: const Icon(Icons.warning_amber_rounded, size: 18),
            label: const Text('Crear alerta de prueba'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.alertHigh),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _node.started ? _demoReport : null,
            icon: const Icon(Icons.water, size: 18),
            label: const Text('Crear reporte de prueba'),
          ),
          if (!_node.started)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Activa la malla para usar los botones.', style: TextStyle(fontSize: 11.5, color: palette.muted)),
            ),
        ],
      ),
    );
  }

  Widget _logCard(AppPalette palette) {
    final entries = _node.log.take(80).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Registro en vivo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text('Aún no hay actividad.', style: TextStyle(fontSize: 12, color: palette.muted))
          else
            for (final e in entries) _logLine(e, palette),
        ],
      ),
    );
  }

  Widget _logLine(MeshLogEntry e, AppPalette palette) {
    String two(int n) => n.toString().padLeft(2, '0');
    final t = '${two(e.at.hour)}:${two(e.at.minute)}:${two(e.at.second)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$t  ', style: TextStyle(color: palette.muted, fontFeatures: const [FontFeature.tabularFigures()])),
          TextSpan(text: e.text, style: TextStyle(color: e.isError ? AppColors.danger : palette.ink)),
        ]),
        style: const TextStyle(fontSize: 12, height: 1.3),
      ),
    );
  }
}
