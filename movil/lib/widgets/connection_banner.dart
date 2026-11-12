import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/di/app_dependencies.dart';
import '../core/theme/app_colors.dart';

/// Banda discreta «Sin conexión» sobre la app. Desaparece sola al volver la red.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, required this.child});

  /// Contenido de la app que va debajo de la banda.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final connectivity = AppDependencies.connectivity;
    return ListenableBuilder(
      listenable: connectivity,
      builder: (context, _) {
        final offline = !connectivity.online;
        return Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: offline
                  ? Material(
                      color: AppColors.darkInk,
                      child: SafeArea(
                        bottom: false,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off, size: 14, color: Colors.white),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  AppStrings.offlineBanner,
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Expanded(
              // La banda ya cubrió la barra de estado.
              child: offline ? MediaQuery.removePadding(context: context, removeTop: true, child: child) : child,
            ),
          ],
        );
      },
    );
  }
}
