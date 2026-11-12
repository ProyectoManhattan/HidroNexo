import 'package:flutter/material.dart';

import '../../controllers/home_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/filter_chips_bar.dart';
import '../../widgets/hero_header.dart';
import '../../widgets/incident_map_view.dart';
import '../../widgets/map_legend.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/report_detail_sheet.dart';
import '../../widgets/zone_search_field.dart';

/// Pantalla de inicio: clima, búsqueda de zona y mapa de reportes.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onReportTap});

  /// Se llama al presionar el botón "Reportar" del mapa.
  final VoidCallback onReportTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller =
      HomeController(AppDependencies.reportRepository);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onZoneSubmitted(String value) {
    _controller.updateZone(value);
    AppToast.show(context, AppStrings.zoneUpdated);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return PageLayout(
          header: HeroHeader(
            zoneLabel: _controller.zoneLabel,
            children: [
              const SizedBox(height: 16),
              const _WeatherRow(),
              ZoneSearchField(onSubmitted: _onZoneSubmitted),
            ],
          ),
          children: [
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilterChipsBar(
                    selected: _controller.filter,
                    onSelected: _controller.setFilter,
                  ),
                  const SizedBox(height: 10),
                  IncidentMapView(
                    reports: _controller.visibleReports,
                    height: Responsive.mapHeight(context),
                    onReportTap: (report) =>
                        ReportDetailSheet.showReport(context, report),
                    overlay: Positioned(
                      right: 12,
                      bottom: 12,
                      child: FilledButton.icon(
                        onPressed: widget.onReportTap,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(AppStrings.navReport),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const MapLegend(),
                ],
              ),
            ),
            const _RiskCard(),
          ],
        );
      },
    );
  }
}

class _WeatherRow extends StatelessWidget {
  const _WeatherRow();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppStrings.temperature,
              style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 8),
            Icon(Icons.wb_cloudy, color: Colors.white, size: 34),
          ],
        ),
        SizedBox(height: 2),
        Text(
          AppStrings.weatherQuote,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Row(
        children: [
          Expanded(
            child: _InfoTile(
              label: AppStrings.rainRisk,
              value: AppStrings.rainRiskValue,
              icon: Icons.circle,
              iconColor: AppColors.ok,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _InfoTile(
              label: AppStrings.waterInZone,
              value: AppStrings.waterInZoneValue,
              icon: Icons.water_drop,
              iconColor: AppColors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.pale,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: palette.muted)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
