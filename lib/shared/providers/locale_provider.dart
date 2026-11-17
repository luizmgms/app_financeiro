import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/local_storage_service.dart';
import 'app_bootstrap_provider.dart';

/// Gerencia a localidade ativa do aplicativo (`pt_BR` padrão).
class LocaleNotifier extends Notifier<Locale> {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  Locale build() {
    final code = _storage.loadLocaleCode();
    final parts = code.split('_');
    if (parts.length == 2) {
      return Locale(parts[0], parts[1]);
    }
    return const Locale('pt', 'BR');
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final formatted = locale.countryCode != null
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
    await _storage.saveLocaleCode(formatted);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
