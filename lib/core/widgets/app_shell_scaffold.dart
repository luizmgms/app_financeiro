import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

class _ShellDestination {
  const _ShellDestination({
    required this.fullLabel,
    required this.compactLabel,
    required this.icon,
    required this.selectedIcon,
  });

  final String fullLabel;
  final String compactLabel;
  final IconData icon;
  final IconData selectedIcon;
}

const _primaryDestinations = <_ShellDestination>[
  _ShellDestination(
    fullLabel: 'Início',
    compactLabel: 'Início',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  _ShellDestination(
    fullLabel: 'Movimentações',
    compactLabel: 'Movim.',
    icon: Icons.swap_horiz_outlined,
    selectedIcon: Icons.swap_horiz_rounded,
  ),
  _ShellDestination(
    fullLabel: 'Contas',
    compactLabel: 'Contas',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
  ),
  _ShellDestination(
    fullLabel: 'Cartões',
    compactLabel: 'Cartões',
    icon: Icons.credit_card_outlined,
    selectedIcon: Icons.credit_card_rounded,
  ),
  _ShellDestination(
    fullLabel: 'Relatórios',
    compactLabel: 'Relat.',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart_rounded,
  ),
  _ShellDestination(
    fullLabel: 'Configurações',
    compactLabel: 'Ajustes',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
  ),
];

/// Scaffold principal responsivo:
/// - Mobile: barra de navegação inferior.
/// - Telas médias/grandes: menu lateral (`NavigationRail`).
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final useSideNav = width >= AppConstants.mobileBreakpoint;
    final extendedSideNav = width >= AppConstants.desktopBreakpoint;
    final theme = Theme.of(context);

    final aiFab = FloatingActionButton.extended(
      heroTag: 'ai-assistant-fab',
      onPressed: () => context.push(AppRoutes.aiAssistant),
      icon: const Icon(Icons.auto_awesome_rounded),
      label: const Text('Assistente IA'),
    );

    if (!useSideNav) {
      return Scaffold(
        body: navigationShell,
        floatingActionButton: aiFab,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final item in _primaryDestinations)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.compactLabel,
                tooltip: item.fullLabel,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      floatingActionButton: aiFab,
      body: Row(
        children: [
          NavigationRail(
            extended: extendedSideNav,
            minWidth: 76,
            minExtendedWidth: 224,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onDestinationSelected,
            labelType: extendedSideNav
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  if (extendedSideNav) ...[
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.appName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Gestão Pessoal',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            destinations: [
              for (final item in _primaryDestinations)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.fullLabel),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
