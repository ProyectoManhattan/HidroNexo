import 'package:flutter/material.dart';

import '../../core/constants/app_config.dart';
import '../../core/constants/app_strings.dart';
import '../../models/incident_report.dart';
import 'map_provider.dart';

/// Mapa de demostración dibujado con Flutter (sin claves ni paquetes).
class PlaceholderMapProvider extends MapProvider {
  const PlaceholderMapProvider();

  @override
  Widget build(
    BuildContext context, {
    required List<IncidentReport> reports,
    required ValueChanged<IncidentReport> onReportTap,
  }) {
    return _PlaceholderMap(reports: reports, onReportTap: onReportTap);
  }
}

class _PlaceholderMap extends StatelessWidget {
  const _PlaceholderMap({required this.reports, required this.onReportTap});

  final List<IncidentReport> reports;
  final ValueChanged<IncidentReport> onReportTap;

  static const double _pin = 34;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final height = box.maxHeight;
        return Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _DemoMapPainter())),
            for (final report in reports)
              Positioned(
                left: _x(report) * width - _pin / 2,
                top: _y(report) * height - _pin,
                child: _Pin(report: report, onTap: () => onReportTap(report)),
              ),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  AppStrings.mapPlaceholderNote,
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _x(IncidentReport r) {
    final dx = (r.position.longitude - AppConfig.mapCenter.longitude) /
        AppConfig.mapSpanLng;
    return (0.5 + dx).clamp(0.06, 0.94).toDouble();
  }

  double _y(IncidentReport r) {
    final dy = (r.position.latitude - AppConfig.mapCenter.latitude) /
        AppConfig.mapSpanLat;
    return (0.5 - dy).clamp(0.16, 0.94).toDouble();
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.report, required this.onTap});

  final IncidentReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${report.type.label} · ${report.folio}',
      child: Material(
        color: report.type.color,
        shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2)),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: _PlaceholderMap._pin,
            height: _PlaceholderMap._pin,
            child: Icon(report.type.icon, size: 17, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _DemoMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 300, size.height / 230);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 300, 230),
      Paint()..color = const Color(0xFFDBE8F7),
    );

    final water = Path()
      ..moveTo(0, 170)
      ..quadraticBezierTo(70, 150, 130, 175)
      ..quadraticBezierTo(190, 200, 300, 160)
      ..lineTo(300, 230)
      ..lineTo(0, 230)
      ..close();
    canvas.drawPath(water, Paint()..color = const Color(0xFF9FC6F2));

    final wide = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-10, 60), const Offset(310, 90), wide);
    canvas.drawLine(const Offset(60, -10), const Offset(90, 240), wide);
    canvas.drawLine(const Offset(200, -10), const Offset(230, 240), wide);
    canvas.drawLine(const Offset(-10, 130), const Offset(310, 120), wide);

    final thin = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawLine(const Offset(140, -10), const Offset(150, 170), thin);
    canvas.drawLine(const Offset(-10, 25), const Offset(310, 40), thin);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
