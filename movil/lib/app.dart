import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'screens/citizen/citizen_shell.dart';

/// Widget raíz: tema claro/oscuro y vista del ciudadano.
class HidroNexoApp extends StatelessWidget {
  const HidroNexoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const CitizenShell(),
    );
  }
}
