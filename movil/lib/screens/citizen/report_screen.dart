import 'dart:io';

import 'package:flutter/material.dart';

import '../../controllers/report_form_controller.dart';
import '../../core/constants/app_config.dart';
import '../../core/constants/app_strings.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/theme/app_colors.dart';
import '../../data/report_repository.dart';
import '../../models/incident_report.dart';
import '../../models/report_status.dart';
import '../../services/location_service.dart';
import '../../services/photo_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/hero_header.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/report_detail_sheet.dart';
import '../../widgets/report_type_selector.dart';

/// Formulario para reportar un problema y consultar un folio.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final ReportFormController _controller = ReportFormController(
    repository: AppDependencies.reportRepository,
    locationService: AppDependencies.locationService,
    photoService: AppDependencies.photoService,
    onSubmitted: AppDependencies.dataRefresh.notifyChanged,
  );
  final TextEditingController _folioController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _folioController.dispose();
    super.dispose();
  }

  Future<void> _useLocation() async {
    try {
      await _controller.useMyLocation();
      if (!mounted) return;
      AppToast.show(context, AppStrings.locationAdded);
    } on LocationException catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.message);
    }
  }

  Future<void> _submit() async {
    if (!_controller.isValid) {
      AppToast.show(context, AppStrings.missingData);
      return;
    }
    final place = _controller.locationLabel ?? '';
    String folio;
    var withoutPhoto = false;
    while (true) {
      try {
        folio = await _controller.submit(withoutPhoto: withoutPhoto);
        break;
      } on PhotoUploadException catch (e) {
        if (!mounted) return;
        final choice = await _askPhotoFailure(e.message);
        if (choice == null || !mounted) return;
        withoutPhoto = !choice;
      } on RepositoryException catch (e) {
        if (!mounted) return;
        AppToast.show(context, e.message);
        return;
      }
    }
    if (!mounted) return;
    await ReportDetailSheet.show(
      context,
      title: AppStrings.reportSent,
      description: AppStrings.reportSentBody,
      place: place,
      date: AppStrings.now,
      status: '$folio · ${ReportStatus.pending.label}',
    );
  }

  /// true = reintentar, false = enviar sin foto, null = cancelar.
  Future<bool?> _askPhotoFailure(String reason) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.photoUploadFailedTitle),
        content: Text('$reason\n\n${AppStrings.photoUploadFailedBody}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.sendWithoutPhoto),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text(AppStrings.photoFromCamera),
              onTap: () => Navigator.pop(context, PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(AppStrings.photoFromGallery),
              onTap: () => Navigator.pop(context, PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      await _controller.pickPhoto(source);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, AppStrings.photoPickFailed);
    }
  }

  Future<void> _track() async {
    final IncidentReport? report;
    try {
      report = await _controller.findReport(_folioController.text);
    } on RepositoryException catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.message);
      return;
    }
    if (!mounted) return;
    if (report == null) {
      AppToast.show(context, AppStrings.folioNotFound);
      return;
    }
    ReportDetailSheet.showReport(context, report);
  }

  @override
  Widget build(BuildContext context) {
    return PageLayout(
      header: HeroHeader(
        zoneLabel: AppConfig.zoneShort,
        title: AppStrings.reportTitle,
        subtitle: AppStrings.reportSubtitle,
      ),
      children: [
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _buildForm(context),
        ),
        _buildTracking(context),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final palette = AppPalette.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel(AppStrings.whatIsHappening, first: true),
          ReportTypeSelector(
            selected: _controller.type,
            onSelected: _controller.selectType,
          ),
          const _FieldLabel(AppStrings.severityLabel),
          _SeveritySelector(
            selected: _controller.severity,
            onSelected: _controller.selectSeverity,
          ),
          const _FieldLabel(AppStrings.location),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.pale,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: AppColors.blue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _controller.locationLabel ?? AppStrings.noLocation,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _useLocation,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  child: const Text(AppStrings.useMyLocation),
                ),
              ],
            ),
          ),
          const _FieldLabel(AppStrings.photoOptional),
          Material(
            color: palette.pale,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _choosePhoto,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 18, color: AppColors.blue),
                        SizedBox(width: 8),
                        Text(
                          AppStrings.attachPhoto,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppStrings.attachPhotoHint,
                      style: TextStyle(fontSize: 11, color: palette.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_controller.photo != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_controller.photo!.path),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        width: 72,
                        height: 72,
                        color: palette.pale,
                        child: const Icon(Icons.image_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _controller.photo!.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.removePhoto,
                    onPressed: _controller.removePhoto,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          const _FieldLabel(AppStrings.description),
          TextField(
            controller: _controller.descriptionController,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: AppStrings.descriptionHint,
              hintStyle: TextStyle(color: palette.muted),
              filled: true,
              fillColor: palette.pale,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.sky, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: _controller.sending ? AppStrings.sending : AppStrings.sendReport,
            onPressed: _controller.sending ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildTracking(BuildContext context) {
    final palette = AppPalette.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.trackTitle,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _folioController,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _track(),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: AppStrings.folioHint,
                    hintStyle: TextStyle(color: palette.muted),
                    filled: true,
                    fillColor: palette.pale,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _track,
                icon: const Icon(Icons.search),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 16, bottom: 7),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

/// Gravedad del problema (1 baja, 2 media, 3 alta): pesa en el cálculo de riesgo.
class _SeveritySelector extends StatelessWidget {
  const _SeveritySelector({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const _labels = [
    AppStrings.severityLow,
    AppStrings.severityMedium,
    AppStrings.severityHigh,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      children: [
        for (var level = 1; level <= 3; level++) ...[
          if (level > 1) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: selected == level ? AppColors.blue : palette.pale,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(level),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Center(
                    child: Text(
                      _labels[level - 1],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected == level ? Colors.white : palette.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
