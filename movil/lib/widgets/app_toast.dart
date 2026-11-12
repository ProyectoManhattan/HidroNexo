import 'package:flutter/material.dart';

/// Mensaje breve flotante sobre la barra de navegación.
class AppToast {
  AppToast._();

  /// Para avisos sin contexto (por ejemplo, el reenvío en segundo plano).
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void showGlobal(String message) {
    final messenger = messengerKey.currentState;
    if (messenger != null) _show(messenger, message);
  }

  static void show(BuildContext context, String message) =>
      _show(ScaffoldMessenger.of(context), message);

  static void _show(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 3600),
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 90),
        ),
      );
  }
}
