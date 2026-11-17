/// Rotas nomeadas e caminhos tipados do GoRouter.
abstract final class AppRoutes {
  static const String dashboard = '/';
  static const String transactions = '/transactions';
  static const String accounts = '/accounts';
  static const String creditCards = '/credit-cards';
  static const String reports = '/reports';
  static const String settings = '/settings';

  // Autenticação e recuperação de conta.
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Módulos secundários acessíveis a partir das telas principais e atalhos.
  static const String recurring = '/recurring';
  static const String installments = '/installments';
  static const String categories = '/categories';
  static const String budgets = '/budgets';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String aiAssistant = '/ai-assistant';

  static const Set<String> publicAuthRoutes = {
    login,
    register,
    forgotPassword,
  };
}
