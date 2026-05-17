import 'package:flutter/material.dart';

/// Global singleton that holds the current ThemeMode.
/// Widgets that depend on theme changes should wrap in AnimatedBuilder(animation: ThemeNotifier.instance, ...).
class ThemeNotifier extends ValueNotifier<ThemeMode> {
  static final ThemeNotifier instance = ThemeNotifier._internal();
  ThemeNotifier._internal() : super(ThemeMode.light);

  bool get isDark => value == ThemeMode.dark;

  void setDark(bool dark) {
    value = dark ? ThemeMode.dark : ThemeMode.light;
  }

  void toggle() => setDark(!isDark);
}
