import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';

/// Serviço de persistência local e cache com Hive.
class LocalStorageService {
  Box<dynamic>? _settingsBox;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Hive.initFlutter();
      _settingsBox = await Hive.openBox<dynamic>(AppConstants.settingsBoxName);
      _initialized = true;
    } catch (_) {
      // Em testes unitários ou ambientes restritos, permite seguir sem falhar.
      _initialized = false;
    }
  }

  ThemeMode loadThemeMode() {
    final stored = _settingsBox?.get(AppConstants.themeModeKey) as String?;
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    await _settingsBox?.put(AppConstants.themeModeKey, mode.name);
  }

  String loadLocaleCode() {
    return (_settingsBox?.get(AppConstants.localeCodeKey) as String?) ??
        AppConstants.defaultLocale;
  }

  Future<void> saveLocaleCode(String localeCode) async {
    await _settingsBox?.put(AppConstants.localeCodeKey, localeCode);
  }
}
