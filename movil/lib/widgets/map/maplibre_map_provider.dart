import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../models/incident_report.dart';
import '../../models/report_type.dart';
import 'map_provider.dart';

/// Mapa real con MapLibre: base de OpenStreetMap, polígonos de riesgo por zona
/// (`GET /zones/risk`) coloreados por nivel y un punto por reporte.
class MaplibreMapProvider extends MapProvider {
  const MaplibreMapProvider();

  @override
  Widget build(
    BuildContext context, {
    required List<IncidentReport> reports,
    required ValueChanged<IncidentReport> onReportTap,
    Map<String, dynamic>? riskZones,
  }) {
    return RiskMap(
      reports: reports,
      onReportTap: onReportTap,
      riskZones: riskZones,
    );
  }
}

const _zonesSource = 'zonas';
const _reportsSource = 'reportes';
const _reportsLayer = 'reportes-puntos';

/// Estilo mínimo: teselas raster de OSM, sin claves de API. Bajo ellas va una
/// capa `background` lisa: sin mosaicos (sin red y fuera de la caché ambiental
/// de MapLibre) las zonas de riesgo se siguen dibujando sobre un fondo liso.
/// No se descargan mosaicos de forma masiva (lo prohíbe la política de OSM).
final String _baseStyle = jsonEncode({
  'version': 8,
  'sources': {
    'osm': {
      'type': 'raster',
      'tiles': ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
      'tileSize': 256,
      'maxzoom': 19,
      'attribution': '© OpenStreetMap',
    },
  },
  'layers': [
    {
      'id': 'fondo',
      'type': 'background',
      'paint': {'background-color': '#e4ebf3'},
    },
    {'id': 'osm', 'type': 'raster', 'source': 'osm'},
  ],
});

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Color por nivel de riesgo (`bajo`, `medio`, `alto`, `critico`).
final List<Object> _levelColor = [
  'match',
  ['get', 'nivel'],
  'bajo', _hex(AppColors.ok),
  'medio', _hex(AppColors.yellow),
  'alto', _hex(AppColors.warn),
  'critico', _hex(AppColors.danger),
  _hex(AppColors.drain),
];

final List<Object> _typeColor = [
  'match',
  ['get', 'tipo'],
  for (final t in ReportType.values) ...[t.apiKey, _hex(t.color)],
  _hex(AppColors.blue),
];

/// FeatureCollection con un punto por reporte (la propiedad `folio` sirve
/// para identificarlo al tocarlo).
@visibleForTesting
Map<String, dynamic> reportsToGeoJson(List<IncidentReport> reports) => {
      'type': 'FeatureCollection',
      'features': [
        for (final r in reports)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [r.position.longitude, r.position.latitude],
            },
            'properties': {'folio': r.folio, 'tipo': r.type.apiKey},
          },
      ],
    };

const _emptyCollection = {'type': 'FeatureCollection', 'features': <dynamic>[]};

class RiskMap extends StatefulWidget {
  const RiskMap({
    super.key,
    required this.reports,
    required this.onReportTap,
    this.riskZones,
  });

  final List<IncidentReport> reports;
  final ValueChanged<IncidentReport> onReportTap;
  final Map<String, dynamic>? riskZones;

  @override
  State<RiskMap> createState() => _RiskMapState();
}

class _RiskMapState extends State<RiskMap> {
  MapLibreMapController? _controller;
  bool _styleReady = false;

  @override
  void didUpdateWidget(RiskMap old) {
    super.didUpdateWidget(old);
    if (!_styleReady) return;
    // Solo se reemplazan los datos de las fuentes: las capas no se recrean.
    if (!identical(old.riskZones, widget.riskZones)) _pushZones();
    if (!listEquals(old.reports, widget.reports)) _pushReports();
  }

  Future<void> _onStyleLoaded() async {
    final c = _controller;
    if (c == null) return;
    await c.addGeoJsonSource(_zonesSource, widget.riskZones ?? _emptyCollection);
    await c.addGeoJsonSource(_reportsSource, reportsToGeoJson(widget.reports));
    await c.addFillLayer(
      _zonesSource,
      'zonas-relleno',
      FillLayerProperties(fillColor: _levelColor, fillOpacity: 0.4),
    );
    await c.addLineLayer(
      _zonesSource,
      'zonas-borde',
      LineLayerProperties(
        lineColor: _levelColor,
        lineWidth: 1,
        lineOpacity: 0.8,
      ),
    );
    await c.addCircleLayer(
      _reportsSource,
      _reportsLayer,
      CircleLayerProperties(
        circleColor: _typeColor,
        circleRadius: 7,
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 2,
      ),
    );
    _styleReady = true;
    // Los datos pudieron cambiar mientras se creaban las capas.
    await _pushZones();
    await _pushReports();
  }

  Future<void> _pushZones() async =>
      _controller?.setGeoJsonSource(_zonesSource, widget.riskZones ?? _emptyCollection);

  Future<void> _pushReports() async =>
      _controller?.setGeoJsonSource(_reportsSource, reportsToGeoJson(widget.reports));

  Future<void> _onTap(math.Point<double> point, LatLng _) async {
    final hits = await _controller?.queryRenderedFeatures(point, [_reportsLayer], null);
    if (hits == null || hits.isEmpty) return;
    final props = (hits.first as Map)['properties'];
    final folio = props is Map ? props['folio'] : null;
    for (final r in widget.reports) {
      if (r.folio == folio) {
        widget.onReportTap(r);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      styleString: _baseStyle,
      initialCameraPosition: CameraPosition(
        target: LatLng(AppConfig.mapCenter.latitude, AppConfig.mapCenter.longitude),
        zoom: 11.5,
      ),
      onMapCreated: (c) => _controller = c,
      onStyleLoadedCallback: _onStyleLoaded,
      onMapClick: _onTap,
      attributionButtonMargins: const math.Point(8, 8),
      compassEnabled: false,
      // El mapa va dentro de una lista que también se desplaza.
      gestureRecognizers: {Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new)},
    );
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }
}
