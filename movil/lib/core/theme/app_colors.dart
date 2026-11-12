import 'package:flutter/material.dart';

/// Colores de marca (no cambian entre modo claro y oscuro).
class AppColors {
  AppColors._();

  static const Color blue = Color(0xFF0B5EC2);
  static const Color deep = Color(0xFF073B86);
  static const Color sky = Color(0xFF5AA2F0);
  static const Color yellow = Color(0xFFFFD21F);
  static const Color ok = Color(0xFF1A9B6C);
  static const Color warn = Color(0xFFE8912D);
  static const Color drain = Color(0xFF5B6F86);
  static const Color darkInk = Color(0xFF14233B);
}

/// Colores que sí cambian según el tema (claro/oscuro).
class AppPalette {
  const AppPalette({
    required this.ink,
    required this.muted,
    required this.line,
    required this.background,
    required this.card,
    required this.pale,
  });

  final Color ink;
  final Color muted;
  final Color line;
  final Color background;
  final Color card;
  final Color pale;

  static const AppPalette light = AppPalette(
    ink: Color(0xFF14233B),
    muted: Color(0xFF64748B),
    line: Color(0xFFDBE4F2),
    background: Color(0xFFEEF3FB),
    card: Color(0xFFFFFFFF),
    pale: Color(0xFFE6EEFB),
  );

  static const AppPalette dark = AppPalette(
    ink: Color(0xFFE8EEFB),
    muted: Color(0xFF9DB0CC),
    line: Color(0xFF223454),
    background: Color(0xFF0E1A2E),
    card: Color(0xFF16253D),
    pale: Color(0xFF1B2F52),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
