import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HidroNexoApp());
  // Sin await: la app abre aunque push falle o tarde (no bloquea el arranque).
  AppDependencies.pushService.start();
  // Un push con la app abierta (dataRefresh) también dispara una consulta.
  AppDependencies.dataRefresh.addListener(AppDependencies.alertWatcher.refresh);
  AppDependencies.alertWatcher.start();
  AppDependencies.connectivity.start();
  AppDependencies.pendingSender.start();
}
