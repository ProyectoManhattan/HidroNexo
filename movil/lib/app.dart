import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'core/di/app_dependencies.dart';
import 'core/theme/app_theme.dart';
import 'screens/citizen/alert_presenter.dart';
import 'screens/citizen/citizen_shell.dart';

/// Navegador raíz: permite abrir la alerta a pantalla completa desde cualquier pantalla.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Widget raíz: tema claro/oscuro y vista del ciudadano.
class HidroNexoApp extends StatefulWidget {
  const HidroNexoApp({super.key});

  @override
  State<HidroNexoApp> createState() => _HidroNexoAppState();
}

class _HidroNexoAppState extends State<HidroNexoApp> {
  late final AlertPresenter _presenter = AlertPresenter(
    watcher: AppDependencies.alertWatcher,
    navigatorKey: appNavigatorKey,
  );

  @override
  void initState() {
    super.initState();
    // Si ya hay alertas pendientes al montar, se muestran en cuanto haya navegador.
    WidgetsBinding.instance.addPostFrameCallback((_) => _presenter.check());
  }

  @override
  void dispose() {
    _presenter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const CitizenShell(),
    );
  }
}
