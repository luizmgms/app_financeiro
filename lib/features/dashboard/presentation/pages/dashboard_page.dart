import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/firebase_bootstrap_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/platform_info.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../shared/models/date_period.dart';
import '../../../../shared/providers/app_bootstrap_provider.dart';
import '../../../../shared/widgets/summary_metric_card.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../../profile/application/providers/profile_providers.dart';

/// Tela inicial (Dashboard) do esqueleto do Finance Control.
/// Não exibe valores simulados: reflete o estado real de inicialização.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DatePeriodType _selectedPeriod = DatePeriodType.thisMonth;

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(appBootstrapStateProvider);
    final authUser = ref.watch(currentAuthUserProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final theme = Theme.of(context);
    final activePeriod = DatePeriod.fromType(_selectedPeriod);
    final zeroFormatted = CurrencyFormatter.formatCents(
      0,
      locale: profile?.localeCode ?? 'pt_BR',
      currencyCode: profile?.defaultCurrency ?? 'BRL',
    );

    final firebaseColor = switch (bootstrap.firebase.status) {
      FirebaseConnectionStatus.connected => AppColors.income,
      FirebaseConnectionStatus.awaitingConfiguration => AppColors.warning,
      FirebaseConnectionStatus.unsupportedPlatform => AppColors.transfer,
      FirebaseConnectionStatus.error => AppColors.expense,
    };

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Finance Control'),
            Text(
              authUser != null
                  ? 'Olá, ${profile?.displayName ?? authUser.displayName}'
                  : 'Visão geral financeira',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notificações',
            onPressed: () => context.push(AppRoutes.notifications),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: authUser != null ? 'Perfil' : 'Entrar',
            onPressed: () => context.push(
              authUser != null ? AppRoutes.profile : AppRoutes.login,
            ),
            icon: Icon(
              authUser != null
                  ? Icons.account_circle_rounded
                  : Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EnvironmentBannerCard(
                  bootstrap: bootstrap,
                  statusColor: firebaseColor,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final period in DatePeriodType.values)
                      ChoiceChip(
                        label: Text(period.label),
                        selected: _selectedPeriod == period,
                        onSelected: (_) {
                          setState(() => _selectedPeriod = period);
                        },
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '${DateFormatter.shortDate(activePeriod.start)} - '
                        '${DateFormatter.shortDate(activePeriod.end)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900
                        ? 4
                        : constraints.maxWidth >= 560
                            ? 2
                            : 1;
                    final itemWidth =
                        (constraints.maxWidth - (12 * (columns - 1))) / columns;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: SummaryMetricCard(
                            title: 'Saldo total disponível',
                            valueText: zeroFormatted,
                            subtitle: 'Aguardando contas sincronizadas',
                            icon: Icons.account_balance_wallet_outlined,
                            accentColor: AppColors.primaryLight,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: SummaryMetricCard(
                            title: 'Receitas do período',
                            valueText: zeroFormatted,
                            subtitle: 'Nenhuma receita registrada',
                            icon: Icons.trending_up_rounded,
                            accentColor: AppColors.income,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: SummaryMetricCard(
                            title: 'Despesas do período',
                            valueText: zeroFormatted,
                            subtitle: 'Nenhuma despesa registrada',
                            icon: Icons.trending_down_rounded,
                            accentColor: AppColors.expense,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: SummaryMetricCard(
                            title: 'Saldo projetado',
                            valueText: zeroFormatted,
                            subtitle: 'Inclui contas e faturas futuras',
                            icon: Icons.auto_graph_rounded,
                            accentColor: AppColors.credit,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _ChartSkeletonCard(),
                const SizedBox(height: 16),
                _ModulesDirectoryCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EnvironmentBannerCard extends StatelessWidget {
  const _EnvironmentBannerCard({
    required this.bootstrap,
    required this.statusColor,
  });

  final AppBootstrapState bootstrap;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const StatusBadge(
                  label: 'Esqueleto Etapa 0',
                  color: AppColors.primaryLight,
                  icon: Icons.verified_outlined,
                ),
                StatusBadge(
                  label: PlatformInfo.platformLabel,
                  color: AppColors.transfer,
                  icon: Icons.devices_outlined,
                ),
                StatusBadge(
                  label: bootstrap.localStorageInitialized
                      ? 'Cache Hive ativo'
                      : 'Cache Hive em memória',
                  color: AppColors.income,
                  icon: Icons.storage_outlined,
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_outlined, size: 18, color: statusColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    bootstrap.firebase.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartSkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Receitas x Despesas (estrutura fl_chart)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const StatusBadge(
                  label: 'Sem lançamentos',
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'O gráfico exibirá valores reais assim que as etapas de Firebase e Lançamentos forem conectadas.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 170,
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 50,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const labels = ['Sem 1', 'Sem 2', 'Sem 3', 'Sem 4'];
                          final idx = value.toInt();
                          if (idx < 0 || idx >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[idx],
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < 4; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: 0,
                            width: 14,
                            color: AppColors.income,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          BarChartRodData(
                            toY: 0,
                            width: 14,
                            color: AppColors.expense,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModulesDirectoryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modules = [
      ('Orçamentos', Icons.pie_chart_outline_rounded, AppRoutes.budgets),
      ('Recorrências', Icons.repeat_rounded, AppRoutes.recurring),
      ('Parcelamentos', Icons.view_week_outlined, AppRoutes.installments),
      ('Categorias', Icons.category_outlined, AppRoutes.categories),
      ('Notificações', Icons.notifications_active_outlined,
          AppRoutes.notifications),
      ('Perfil', Icons.badge_outlined, AppRoutes.profile),
      ('Autenticação', Icons.lock_outline_rounded, AppRoutes.login),
      ('Assistente IA', Icons.auto_awesome_rounded, AppRoutes.aiAssistant),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Módulos mapeados na arquitetura',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Toque para validar as rotas secundárias preparadas no GoRouter.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in modules)
                  ActionChip(
                    avatar: Icon(item.$2, size: 18),
                    label: Text(item.$1),
                    onPressed: () => context.push(item.$3),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
