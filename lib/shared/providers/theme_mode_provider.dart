import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/local_storage_service.dart';
import 'app_bootstrap_provider.dart';

/// Gerencia o tema claro/escuro com persistência em Hive.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  ThemeMode build() {
    return _storage.loadThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _storage.saveThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
