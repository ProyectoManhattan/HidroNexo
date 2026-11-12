import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/active_alert.dart';

/// Colores de cada nivel de alerta: fondo de la cabecera y texto encima.
class AlertLevelStyle {
  const AlertLevelStyle(this.background, this.foreground, this.icon);

  final Color background;
  final Color foreground;
  final IconData icon;

  static AlertLevelStyle of(AlertLevel level) {
    switch (level) {
      case AlertLevel.critico:
        return const AlertLevelStyle(AppColors.alertCritical, Colors.white, Icons.crisis_alert);
      case AlertLevel.alto:
        return const AlertLevelStyle(AppColors.alertHigh, Colors.white, Icons.warning_amber_rounded);
      case AlertLevel.medio:
        return const AlertLevelStyle(
            AppColors.alertMedium, AppColors.alertMediumInk, Icons.warning_amber_rounded);
      case AlertLevel.bajo:
        return const AlertLevelStyle(AppColors.alertLow, Colors.white, Icons.info_outline);
    }
  }
}

/// Alerta oficial a pantalla completa. No se puede cerrar con «atrás»: solo
/// con «Enterado», que cierra la pantalla y llama a [onAcknowledge].
class AlertFullScreen extends StatelessWidget {
  const AlertFullScreen({
    super.key,
    required this.alert,
    this.remaining = 0,
    this.onAcknowledge,
  });

  final ActiveAlert alert;

  /// Cuántas alertas más esperan después de esta.
  final int remaining;
  final VoidCallback? onAcknowledge;

  /// Ruta a pantalla completa para [alert].
  static Route<void> route(ActiveAlert alert, {int remaining = 0, VoidCallback? onAcknowledge}) {
    return MaterialPageRoute<void>(
      fullscreenDialog: true,
      settings: RouteSettings(name: 'alerta/${alert.id}'),
      builder: (_) => AlertFullScreen(alert: alert, remaining: remaining, onAcknowledge: onAcknowledge),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = AlertLevelStyle.of(alert.level);
    final zone = alert.zoneName;
    final title = zone == null || zone.isEmpty
        ? AppStrings.alertLevelTitle(alert.level.label)
        : '${AppStrings.alertLevelTitle(alert.level.label)} · $zone';
    final fg = style.foreground;
    const body = TextStyle(fontSize: 18, height: 1.4);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: palette.background,
        body: Column(
          children: [
            Semantics(
              container: true,
              header: true,
              label: '${AppStrings.alertScreenTitle}. $title',
              child: Container(
                width: double.infinity,
                color: style.background,
                padding: EdgeInsets.fromLTRB(
                    20, MediaQuery.of(context).padding.top + 20, 20, 24),
                child: ExcludeSemantics(
                  child: Column(
                    children: [
                      Icon(style.icon, size: 88, color: fg),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.alertScreenTitle.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: fg),
                      ),
                      if (alert.simulated) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: fg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            AppStrings.alertSimulation,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: style.background),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (alert.simulated) ...[
                          Text(AppStrings.alertSimulationNote,
                              style: body.copyWith(
                                  color: palette.muted, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                        ],
                        Text(alert.text,
                            style: body.copyWith(
                                color: palette.ink, fontWeight: FontWeight.w700, fontSize: 20)),
                        if (alert.steps.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Semantics(
                            header: true,
                            child: Text(
                              alert.guideTitle?.isNotEmpty == true
                                  ? alert.guideTitle!
                                  : AppStrings.alertWhatToDo,
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900, color: palette.ink),
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (var i = 0; i < alert.steps.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Semantics(
                                label: 'Paso ${i + 1}. ${alert.steps[i]}',
                                child: ExcludeSemantics(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: style.background,
                                        child: Text('${i + 1}',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: fg)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Text(alert.steps[i],
                                              style: body.copyWith(color: palette.ink))),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: palette.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.danger, width: 2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_in_talk, color: AppColors.danger, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(AppStrings.alertLife911,
                                    style: body.copyWith(
                                        color: palette.ink, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              color: palette.card,
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (remaining > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(AppStrings.alertRemaining(remaining),
                          style: TextStyle(fontSize: 16, color: palette.muted)),
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: FilledButton(
                      onPressed: () {
                        onAcknowledge?.call();
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(64),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      child: const Text(AppStrings.alertAcknowledge),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
