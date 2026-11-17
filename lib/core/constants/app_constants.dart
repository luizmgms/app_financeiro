/// Constantes globais de configuração do Finance Control.
abstract final class AppConstants {
  static const String appName = 'Finance Control';
  static const String appSubtitle = 'Gestão Financeira Pessoal';
  static const String defaultCurrency = 'BRL';
  static const String defaultLocale = 'pt_BR';
  static const int defaultMonthStartDay = 1;

  // Breakpoints responsivos para layout mobile vs desktop/web.
  static const double mobileBreakpoint = 720;
  static const double desktopBreakpoint = 1120;

  // Caixas Hive para cache local e preferências.
  static const String settingsBoxName = 'finance_control_settings';
  static const String cacheBoxName = 'finance_control_cache';

  // Chaves de preferências locais.
  static const String themeModeKey = 'theme_mode';
  static const String localeCodeKey = 'locale_code';
}
