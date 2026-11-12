import 'package:flutter/material.dart';

import '../../controllers/alerts_controller.dart';
import '../../core/constants/app_config.dart';
import '../../core/constants/app_strings.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/alert_tile.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/hero_header.dart';
import '../../widgets/load_status.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/segmented_tabs.dart';
import '../../widgets/water_service_card.dart';

/// Alertas actuales e historial de la zona.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late final AlertsController _controller =
      AlertsController(AppDependencies.reportRepository);

  @override
  void initState() {
    super.initState();
    _controller.load();
    AppDependencies.dataRefresh.addListener(_controller.load);
  }

  @override
  void dispose() {
    AppDependencies.dataRefresh.removeListener(_controller.load);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _callEmergency() async {
    final ok = await AppDependencies.phoneService.call(AppConfig.emergencyNumber);
    if (!mounted) return;
    AppToast.show(context, ok ? AppStrings.callDemo : AppStrings.callFailed);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final palette = AppPalette.of(context);
        final alerts = _controller.visibleAlerts;
        return PageLayout(
          header: HeroHeader(
            zoneLabel: AppConfig.zoneShort,
            title: AppStrings.alertsTitle,
            subtitle: AppStrings.alertsSubtitle,
          ),
          children: [
            LoadStatus(
              loading: _controller.loading,
              error: _controller.error,
              onRetry: _controller.load,
            ),
            const WaterServiceCard(),
            SegmentedTabs(
              labels: [
                'Actuales (${_controller.current.length})',
                'Historial (${_controller.history.length})',
              ],
              selectedIndex: _controller.showHistory ? 1 : 0,
              onChanged: (i) => _controller.setShowHistory(i == 1),
            ),
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < alerts.length; i++) ...[
                    if (i > 0) Divider(height: 28, color: palette.line),
                    AlertTile(item: alerts[i]),
                  ],
                ],
              ),
            ),
            if (!_controller.showHistory)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _callEmergency,
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text(AppStrings.callEmergency),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: AppColors.darkInk,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
