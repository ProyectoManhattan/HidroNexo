import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AguaVerApp());
  // Sin await: la app abre aunque push falle o tarde (no bloquea el arranque).
  AppDependencies.pushService.start();
}
