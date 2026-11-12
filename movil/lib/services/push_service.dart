import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/utils/geo.dart';
import '../data/report_repository.dart';
import '../models/coordinates.dart';
import 'location_service.dart';

/// Datos de una notificación de alerta (`data` del mensaje FCM).
class PushTap {
  const PushTap({this.alertId, this.tipo, this.nivel});

  final int? alertId;
  final String? tipo;
  final String? nivel;

  factory PushTap.fromData(Map<String, dynamic> data) => PushTap(
        alertId: int.tryParse('${data['alerta_id'] ?? ''}'),
        tipo: data['tipo'] == null ? null : '${data['tipo']}',
        nivel: data['nivel'] == null ? null : '${data['nivel']}',
      );
}

/// Contrato de notificaciones push. Los consumidores no dependen de Firebase.
abstract class PushService {
  /// Toques sobre una notificación (app en segundo plano o cerrada, o
  /// notificación local de primer plano).
  Stream<PushTap> get taps;

  /// Se dispara al llegar un push con la app abierta (para recargar alertas).
  Stream<void> get incoming;

  /// Inicializa push. Nunca lanza: si falla, la app sigue sin push.
  Future<void> start();

  void dispose();
}

/// Sin push (modo mock, o Firebase no disponible).
class NoopPushService implements PushService {
  @override
  Stream<PushTap> get taps => const Stream.empty();

  @override
  Stream<void> get incoming => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  void dispose() {}
}

/// Handler de mensajes en segundo plano / app cerrada. Debe ser top-level.
/// Los mensajes con bloque `notification` los muestra el sistema solo.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // sin configuración de Firebase no hay nada que hacer
  }
  debugPrint('[push] mensaje en segundo plano: ${message.messageId}');
}

/// Implementación con Firebase Cloud Messaging.
class FirebasePushService with WidgetsBindingObserver implements PushService {
  FirebasePushService({
    required ReportRepository repository,
    required LocationService locationService,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _repository = repository,
        _location = locationService,
        _local = localNotifications ?? FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'alertas',
    'Alertas',
    description: 'Alertas oficiales de agua y lluvia',
    importance: Importance.high,
  );

  final ReportRepository _repository;
  final LocationService _location;
  final FlutterLocalNotificationsPlugin _local;

  final _taps = StreamController<PushTap>.broadcast();
  final _incoming = StreamController<void>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];

  String? _token;
  Coordinates? _lastSentLocation;
  bool _started = false;
  bool _sending = false;

  @override
  Stream<PushTap> get taps => _taps.stream;

  @override
  Stream<void> get incoming => _incoming.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[push] Firebase no configurado (¿falta google-services.json?): $e');
      return;
    }
    _started = true;
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;

      await _initLocalNotifications();
      await messaging.requestPermission(); // POST_NOTIFICATIONS en Android 13+

      _subs.add(FirebaseMessaging.onMessage.listen(_onForegroundMessage));
      _subs.add(FirebaseMessaging.onMessageOpenedApp
          .listen((m) => _taps.add(PushTap.fromData(m.data))));
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        // Se emite en el siguiente ciclo para que la UI ya esté escuchando.
        Future<void>.delayed(
          const Duration(milliseconds: 500),
          () => _taps.add(PushTap.fromData(initial.data)),
        );
      }

      // getToken/onTokenRefresh (token FCM clásico, el que usa firebase-admin
      // del backend) están marcados como deprecados; onRegistered entrega otro ID (FID).
      // ignore: deprecated_member_use
      _token = await messaging.getToken();
      // ignore: deprecated_member_use
      _subs.add(messaging.onTokenRefresh.listen((t) {
        _token = t;
        unawaited(_register(requestPermission: false, force: true));
      }));
      WidgetsBinding.instance.addObserver(this);
      await _register(requestPermission: true, force: true);
    } catch (e) {
      debugPrint('[push] no se pudo iniciar push: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload);
          if (data is Map<String, dynamic>) _taps.add(PushTap.fromData(data));
        } catch (_) {}
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  void _onForegroundMessage(RemoteMessage message) {
    _incoming.add(null);
    final notification = message.notification;
    if (notification == null) return;
    unawaited(_local.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_register(requestPermission: false, force: false));
    }
  }

  /// Envía token + ubicación. Con [force] false solo reenvía si el usuario se
  /// movió más del umbral desde la última ubicación enviada.
  Future<void> _register({required bool requestPermission, required bool force}) async {
    final token = _token;
    if (token == null || _sending) return;
    _sending = true;
    try {
      final loc = await _location.getCurrentLocation(requestPermission: requestPermission);
      final pos = loc.position;
      if (!force && !shouldResendLocation(_lastSentLocation, pos)) return;
      await _repository.registerDevice(
        token: token,
        lat: pos.latitude,
        lon: pos.longitude,
      );
      _lastSentLocation = pos;
    } on LocationException catch (e) {
      debugPrint('[push] sin ubicación, no se registra el dispositivo: $e');
    } on RepositoryException catch (e) {
      debugPrint('[push] no se pudo registrar el dispositivo: $e');
    } catch (e) {
      debugPrint('[push] error al registrar el dispositivo: $e');
    } finally {
      _sending = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subs) {
      s.cancel();
    }
    _taps.close();
    _incoming.close();
  }
}
