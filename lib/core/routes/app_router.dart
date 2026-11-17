import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/accounts/presentation/pages/accounts_page.dart';
import '../../features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import '../../features/authentication/application/providers/auth_providers.dart';
import '../../features/authentication/presentation/pages/forgot_password_page.dart';
import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/authentication/presentation/pages/register_page.dart';
import '../../features/budgets/presentation/pages/budgets_page.dart';
import '../../features/categories/presentation/pages/categories_page.dart';
import '../../features/credit_cards/presentation/pages/credit_cards_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/installments/presentation/pages/installments_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/recurring/presentation/pages/recurring_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../../shared/providers/app_bootstrap_provider.dart';
import '../widgets/app_shell_scaffold.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateChangesProvider, (_, __) => notifyListeners());
  }
}

/// Calcula o redirecionamento de rota conforme o estado do Firebase e sessão.
String? resolveAuthRedirect({
  required bool firebaseReady,
  required bool isAuthenticated,
  required bool isAuthLoading,
  required String currentLocation,
}) {
  if (!firebaseReady || isAuthLoading) {
    return null;
  }

  final isPublicAuthRoute = AppRoutes.publicAuthRoutes.contains(currentLocation);

  if (!isAuthenticated && !isPublicAuthRoute) {
    return AppRoutes.login;
  }

  if (isAuthenticated && isPublicAuthRoute) {
    return AppRoutes.dashboard;
  }

  return null;
}

/// Provider global do GoRouter com abas persistentes, rotas secundárias e guarda de sessão.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.dashboard,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final bootstrap = ref.read(appBootstrapStateProvider);
      final authAsync = ref.read(authStateChangesProvider);

      return resolveAuthRedirect(
        firebaseReady: bootstrap.firebase.isReady,
        isAuthenticated: authAsync.valueOrNull != null,
        isAuthLoading: authAsync.isLoading,
        currentLocation: state.matchedLocation,
      );
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transactions,
                builder: (context, state) => const TransactionsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.accounts,
                builder: (context, state) => const AccountsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.creditCards,
                builder: (context, state) => const CreditCardsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                builder: (context, state) => const ReportsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.recurring,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RecurringPage(),
      ),
      GoRoute(
        path: AppRoutes.installments,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const InstallmentsPage(),
      ),
      GoRoute(
        path: AppRoutes.categories,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CategoriesPage(),
      ),
      GoRoute(
        path: AppRoutes.budgets,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BudgetsPage(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.aiAssistant,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AiAssistantPage(),
      ),
    ],
  );
});
