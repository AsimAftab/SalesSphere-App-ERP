import 'package:flutter/material.dart';

/// Feature module configuration constants
class ModuleConfig {
  ModuleConfig._();

  static const String auth = 'auth';
  static const String home = 'home';
  static const String attendance = 'attendance';
  static const String profile = 'profile';

  static const List<String> enabledModules = [auth, home, attendance, profile];

  static const IconData defaultModuleIcon = Icons.apps;
}
