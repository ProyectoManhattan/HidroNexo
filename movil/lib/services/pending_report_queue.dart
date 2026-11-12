import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/local/pending_report.dart';
import '../data/local/pending_report_store.dart';
import '../models/new_report.dart';

/// Ya hay un reporte pendiente y no se pidió reemplazarlo.
class PendingReportExistsException implements Exception {
  const PendingReportExistsException();

  @override
  String toString() => 'Ya hay un reporte pendiente de enviar.';
}

/// Cola de reportes pendientes LIMITADA A UNO: guarda un solo reporte
/// (con su foto copiada al directorio de documentos de la app) hasta que el
/// [PendingReportSender] logra enviarlo.
class PendingReportQueue extends ChangeNotifier {
  PendingReportQueue({
    required PendingReportStore store,
    Future<Directory> Function()? photosDir,
    DateTime Function()? now,
  })  : _store = store,
        _photosDir = photosDir ?? _defaultPhotosDir,
        _now = now ?? DateTime.now;

  final PendingReportStore _store;
  final Future<Directory> Function() _photosDir;
  final DateTime Function() _now;

  PendingReport? _pending;
  String? _lastSentFolio;
  bool _disposed = false;

  static Future<Directory> _defaultPhotosDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'reportes_pendientes'));
  }

  /// El reporte pendiente, o null.
  PendingReport? get pending => _pending;
  bool get hasPending => _pending != null;

  /// Folio del último reporte pendiente que se envió (para avisarlo en la tarjeta).
  String? get lastSentFolio => _lastSentFolio;

  /// Lee el reporte guardado (al abrir la app).
  Future<void> load() async {
    final saved = await _store.load();
    // Un «reintentando» guardado es de una sesión anterior: ya no hay envío en curso.
    _pending = saved?.status == PendingStatus.retrying
        ? saved!.copyWith(status: PendingStatus.waiting)
        : saved;
    _notify();
  }

  /// Guarda [report] como el reporte pendiente. [photoPath] es la ruta original
  /// de la foto: se copia al directorio de documentos (la caché de image_picker
  /// puede borrarse). Lanza [PendingReportExistsException] si ya hay uno y
  /// [replace] es false. Devuelve null si no se pudo guardar (BD caída).
  Future<PendingReport?> enqueue(
    NewReport report, {
    String? photoPath,
    bool replace = false,
  }) async {
    if (_pending != null && !replace) throw const PendingReportExistsException();
    final previous = _pending;
    final clienteId = report.clienteId;
    if (clienteId == null) throw ArgumentError('clienteId es obligatorio para encolar');

    final copied = (report.photoUrl == null && photoPath != null)
        ? await _copyPhoto(photoPath, clienteId)
        : null;
    final entry = PendingReport(
      clienteId: clienteId,
      type: report.type,
      severity: report.severity,
      position: report.position,
      description: report.description,
      address: report.address,
      createdAt: _now(),
      photoPath: copied,
      photoUrl: report.photoUrl,
    );
    if (!await _store.save(entry)) {
      await _deleteFile(copied);
      return null;
    }
    if (previous != null && previous.photoPath != copied) await _deleteFile(previous.photoPath);
    _pending = entry;
    _lastSentFolio = null;
    _notify();
    return entry;
  }

  /// Actualiza el estado del pendiente (intentos, próximo intento, etc.).
  /// Se ignora si entretanto fue descartado o reemplazado.
  Future<void> update(PendingReport updated) async {
    if (_pending?.clienteId != updated.clienteId) return;
    _pending = updated;
    _notify();
    await _store.save(updated);
  }

  /// El usuario descarta el pendiente: borra la fila y la foto local.
  Future<void> discard() async {
    final old = _pending;
    if (old == null) return;
    _pending = null;
    _notify();
    await _store.clear();
    await _deleteFile(old.photoPath);
  }

  /// Se envió con éxito: borra la fila y la foto local (solo si sigue siendo
  /// el mismo reporte; el usuario pudo reemplazarlo mientras se enviaba).
  Future<void> complete(String clienteId, String folio) async {
    final old = _pending;
    if (old == null || old.clienteId != clienteId) return;
    _pending = null;
    _lastSentFolio = folio;
    _notify();
    await _store.clear();
    await _deleteFile(old.photoPath);
  }

  void dismissSentNotice() {
    if (_lastSentFolio == null) return;
    _lastSentFolio = null;
    _notify();
  }

  Future<String?> _copyPhoto(String source, String clienteId) async {
    try {
      final src = File(source);
      if (!await src.exists()) return null;
      final dir = await _photosDir();
      await dir.create(recursive: true);
      final ext = p.extension(source).isEmpty ? '.jpg' : p.extension(source);
      return (await src.copy(p.join(dir.path, '$clienteId$ext'))).path;
    } catch (e) {
      debugPrint('[cola] no se pudo copiar la foto: $e');
      return null;
    }
  }

  static Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('[cola] no se pudo borrar la foto: $e');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
