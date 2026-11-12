import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../core/constants/app_strings.dart';
import '../data/local/pending_report.dart';
import '../data/report_repository.dart';
import '../models/new_report.dart';
import '../services/photo_service.dart';
import 'connectivity_service.dart';
import 'pending_report_queue.dart';

/// Reenvía el reporte pendiente sin saturar la red.
///
/// - Un solo envío en vuelo a la vez.
/// - Se dispara al recuperar la conectividad, al volver a primer plano y con un
///   temporizador de backoff exponencial con jitter mientras la app está abierta.
/// - Antes de subir nada comprueba la API con una petición ligera (`/health`).
/// - Orden: foto → reporte con `foto_url` y el MISMO `cliente_id` (idempotente).
/// - Si la foto falla [maxPhotoFailures] veces seguidas, envía el reporte sin ella.
/// - Un 4xx de validación marca el reporte como fallido: no se reintenta.
class PendingReportSender with WidgetsBindingObserver {
  PendingReportSender({
    required PendingReportQueue queue,
    required ReportRepository repository,
    required ConnectivityService connectivity,
    this.onSent,
    Random? random,
    DateTime Function()? now,
  })  : _queue = queue,
        _repository = repository,
        _connectivity = connectivity,
        _random = random ?? Random(),
        _now = now ?? DateTime.now;

  static const Duration baseDelay = Duration(seconds: 30);
  static const Duration maxDelay = Duration(minutes: 15);
  static const double jitter = 0.2;
  static const int maxPhotoFailures = 3;

  /// Separación mínima entre intentos disparados por eventos (conectividad,
  /// primer plano) para no encadenar envíos.
  static const Duration minGap = Duration(seconds: 5);

  final PendingReportQueue _queue;
  final ReportRepository _repository;
  final ConnectivityService _connectivity;
  final Random _random;
  final DateTime Function() _now;

  /// Se llama tras un envío exitoso (para refrescar la app).
  final VoidCallback? onSent;

  final StreamController<String> _notices = StreamController<String>.broadcast();
  StreamSubscription<bool>? _connSub;
  Timer? _timer;
  bool _inFlight = false;
  bool _started = false;
  DateTime? _lastAttempt;

  /// Avisos para el usuario («Tu reporte fue enviado», etc.).
  Stream<String> get notices => _notices.stream;

  bool get inFlight => _inFlight;

  /// Espera del intento número [attempt] (0 = el primero): 30 s, 1, 2, 4… min,
  /// con tope de 15 min y ±[jitter] de variación aleatoria (el tope manda).
  static Duration backoff(int attempt, {Random? random, double jitterFactor = jitter}) {
    final exp = min(max(attempt, 0), 20); // evita desbordes
    final nominal = min(baseDelay.inMilliseconds * pow(2, exp), maxDelay.inMilliseconds.toDouble());
    final spread = random == null ? 0.0 : (random.nextDouble() * 2 - 1) * jitterFactor;
    final ms = min(nominal * (1 + spread), maxDelay.inMilliseconds.toDouble());
    return Duration(milliseconds: ms.round());
  }

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _queue.addListener(_ensureScheduled);
    _connSub = _connectivity.changes.listen((online) {
      if (online) unawaited(onConnectivityRestored());
    });
    unawaited(_startup());
  }

  Future<void> _startup() async {
    await _queue.load();
    if (_queue.pending != null) unawaited(attempt(respectGap: false));
    _ensureScheduled();
  }

  /// La conectividad volvió: se reinicia el backoff y se intenta ya.
  Future<void> onConnectivityRestored() async {
    final p = _queue.pending;
    if (p == null) return;
    if (p.status == PendingStatus.waiting && p.attempts != 0) {
      await _queue.update(p.copyWith(attempts: 0, clearNextAttempt: true));
    }
    await attempt();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(attempt());
      _ensureScheduled();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Programa el próximo intento si hay un pendiente reintentable y no hay
  /// temporizador ni envío en curso.
  void _ensureScheduled() {
    final p = _queue.pending;
    if (!_started || p == null || p.status == PendingStatus.failed || _inFlight || _timer != null) {
      return;
    }
    final due = p.nextAttempt;
    var delay = due == null ? backoff(p.attempts, random: _random) : due.difference(_now());
    if (delay.isNegative) delay = Duration.zero;
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(attempt(respectGap: false));
    });
  }

  /// Un intento de envío. Si ya hay uno en vuelo, no hace nada.
  /// [respectGap] evita encadenar intentos disparados por eventos.
  Future<void> attempt({bool respectGap = true, bool force = false}) async {
    final first = _queue.pending;
    if (_inFlight || first == null || first.status == PendingStatus.failed) return;
    final last = _lastAttempt;
    if (!force && respectGap && last != null && _now().difference(last) < minGap) return;
    _inFlight = true;
    _lastAttempt = _now();
    _timer?.cancel();
    _timer = null;
    try {
      await _run(first);
    } catch (e) {
      debugPrint('[envio] error inesperado: $e');
    } finally {
      _inFlight = false;
      _ensureScheduled();
    }
  }

  Future<void> _run(PendingReport start) async {
    var p = start.copyWith(status: PendingStatus.retrying, clearError: true);
    await _queue.update(p);

    // 1) ¿La API responde? Petición ligera antes de subir ~1 MB en vano.
    try {
      await _repository.checkHealth();
    } on RepositoryException {
      await _scheduleRetry(p);
      return;
    }

    // 2) Foto (si la hay y aún no está subida).
    var photoUrl = p.photoUrl;
    var dropPhoto = false;
    final path = p.photoPath;
    if (photoUrl == null && path != null) {
      if (!File(path).existsSync()) {
        dropPhoto = true; // la foto ya no está: el texto es lo crítico
      } else {
        try {
          photoUrl = await _repository.uploadPhoto(
            PickedPhoto(path: path, name: path.split(Platform.pathSeparator).last),
          );
          p = p.copyWith(photoUrl: photoUrl);
          await _queue.update(p);
        } on RepositoryException catch (e) {
          final fails = p.photoFailures + 1;
          p = p.copyWith(photoFailures: fails);
          // Una foto rechazada (413/415) no mejorará reintentando.
          if (fails >= maxPhotoFailures || !e.retryable) {
            dropPhoto = true;
            _notices.add(AppStrings.pendingSentWithoutPhoto);
          } else {
            await _scheduleRetry(p);
            return;
          }
        }
      }
    }

    // 3) El reporte, con el mismo cliente_id. Un 200 por duplicado cuenta como éxito.
    try {
      final NewReport body = p.toNewReport(photoUrl: dropPhoto ? null : photoUrl);
      final folio = await _repository.submit(body);
      await _queue.complete(p.clienteId, folio);
      _notices.add(AppStrings.pendingSent);
      onSent?.call();
    } on RepositoryException catch (e) {
      if (e.retryable) {
        await _scheduleRetry(p);
      } else {
        await _queue.update(p.copyWith(status: PendingStatus.failed, error: e.message));
        _notices.add(AppStrings.pendingFailed);
      }
    }
  }

  Future<void> _scheduleRetry(PendingReport p) async {
    final delay = backoff(p.attempts, random: _random);
    await _queue.update(p.copyWith(
      status: PendingStatus.waiting,
      attempts: p.attempts + 1,
      nextAttempt: _now().add(delay),
    ));
  }

  void dispose() {
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _queue.removeListener(_ensureScheduled);
    _connSub?.cancel();
    _timer?.cancel();
    _notices.close();
  }
}
