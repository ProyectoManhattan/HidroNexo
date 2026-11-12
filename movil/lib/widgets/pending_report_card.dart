import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/di/app_dependencies.dart';
import '../core/theme/app_colors.dart';
import '../data/local/pending_report.dart';
import 'app_card.dart';
import 'app_toast.dart';

/// Tarjeta «Reporte pendiente de envío» con su resumen y estado.
/// No ocupa espacio si no hay nada pendiente.
class PendingReportCard extends StatelessWidget {
  const PendingReportCard({super.key});

  @override
  Widget build(BuildContext context) {
    final queue = AppDependencies.pendingQueue;
    return ListenableBuilder(
      listenable: queue,
      builder: (context, _) {
        final pending = queue.pending;
        if (pending != null) return _PendingBody(report: pending);
        final folio = queue.lastSentFolio;
        if (folio != null) return _SentBody(folio: folio, onClose: queue.dismissSentNotice);
        return const SizedBox.shrink();
      },
    );
  }
}

class _PendingBody extends StatelessWidget {
  const _PendingBody({required this.report});

  final PendingReport report;

  String get _stateLabel => switch (report.status) {
        PendingStatus.waiting => AppStrings.pendingWaiting,
        PendingStatus.retrying => AppStrings.pendingRetrying,
        PendingStatus.failed => AppStrings.pendingFailedState,
      };

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final failed = report.status == PendingStatus.failed;
    final color = failed ? AppColors.danger : AppColors.warn;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(failed ? Icons.error_outline : Icons.schedule_send, size: 20, color: color),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  AppStrings.pendingCardTitle,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _stateLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${report.type.label}${report.hasPhoto ? ' · con foto' : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            report.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
          if (report.address.isNotEmpty)
            Text(report.address, style: TextStyle(fontSize: 11, color: palette.muted)),
          if (failed && report.error != null) ...[
            const SizedBox(height: 4),
            Text(report.error!, style: const TextStyle(fontSize: 11, color: AppColors.danger)),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!failed)
                TextButton(
                  onPressed: report.status == PendingStatus.retrying
                      ? null
                      : () => AppDependencies.pendingSender.attempt(force: true),
                  child: const Text(AppStrings.retryNow),
                ),
              TextButton(
                onPressed: () async {
                  await AppDependencies.pendingQueue.discard();
                  if (context.mounted) AppToast.show(context, AppStrings.pendingDiscarded);
                },
                child: const Text(AppStrings.discard),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SentBody extends StatelessWidget {
  const _SentBody({required this.folio, required this.onClose});

  final String folio;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 20, color: AppColors.ok),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${AppStrings.pendingSent} · ${AppStrings.pendingSentFolio(folio)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close, size: 18)),
        ],
      ),
    );
  }
}
