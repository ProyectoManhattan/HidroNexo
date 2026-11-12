import 'package:flutter/material.dart';

/// Mensaje breve flotante sobre la barra de navegación.
class AppToast {
  AppToast._();

  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 2400),
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 90),
        ),
      );
  }
}
