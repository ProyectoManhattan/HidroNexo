import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../models/incident_report.dart';
import 'primary_button.dart';

/// Hoja inferior con el detalle de un reporte.
class ReportDetailSheet extends StatelessWidget {
  const ReportDetailSheet({
    super.key,
    required this.title,
    required this.description,
    required this.place,
    required this.date,
    required this.status,
    this.photoUrl,
  });

  final String title;
  final String description;
  final String place;
  final String date;
  final String status;
  final String? photoUrl;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String description,
    required String place,
    required String date,
    required String status,
    String? photoUrl,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => ReportDetailSheet(
        title: title,
        description: description,
        place: place,
        date: date,
        status: status,
        photoUrl: photoUrl,
      ),
    );
  }

  static Future<void> showReport(BuildContext context, IncidentReport report) {
    return show(
      context,
      title: report.type.label,
      description: report.description,
      place: report.address,
      date: report.dateLabel,
      status: report.status.label,
      photoUrl: report.photoUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(description, style: TextStyle(color: palette.muted, fontSize: 13, height: 1.5)),
            if (photoUrl != null) ...[
              const SizedBox(height: 10),
              _DetailPhoto(url: photoUrl!),
            ],
            const SizedBox(height: 10),
            _DetailRow(label: AppStrings.location, value: place),
            _DetailRow(label: AppStrings.date, value: date),
            _DetailRow(label: AppStrings.status, value: status),
            const SizedBox(height: 6),
            PrimaryButton(
              label: AppStrings.understood,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailPhoto extends StatelessWidget {
  const _DetailPhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    Widget placeholder(Widget child) => Container(
          height: 160,
          alignment: Alignment.center,
          color: palette.pale,
          child: child,
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: Image.network(
          url,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : placeholder(const CircularProgressIndicator(strokeWidth: 2)),
          errorBuilder: (context, error, stack) => placeholder(
            Text(AppStrings.photoLoadFailed, style: TextStyle(color: palette.muted, fontSize: 12)),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: palette.muted, fontSize: 12)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
