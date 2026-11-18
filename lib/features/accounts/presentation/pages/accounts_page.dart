import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/icon_catalog.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../application/controllers/account_controller.dart';
import '../../application/providers/account_providers.dart';
import '../../domain/entities/account_entity.dart';
import '../widgets/account_form_dialog.dart';
import '../widgets/transfer_form_dialog.dart';
import 'account_statement_page.dart';

/// Tela de gerenciamento de contas financeiras, saldos e transferências.
class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  bool _showArchived = false;

  void _openStatement(AccountEntity account) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountStatementPage(accountId: account.id),
      ),
    );
  }

  Future<void> _confirmDelete(AccountEntity account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conta'),
        content: Text(
          'Deseja excluir a conta "${account.name}"? '
          'Se ela possuir movimentações no extrato, será necessário arquivá-la.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await ref
        .read(accountControllerProvider.notifier)
        .deleteAccount(account.id);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AccountActionState>(accountControllerProvider, (prev, next) {
      if (!mounted) return;
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.expense,
          ),
        );
      } else if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!)),
        );
      }
    });

    final accountsAsync = ref.watch(accountsStreamProvider);
    final totalBalanceCents = ref.watch(totalAvailableBalanceCentsProvider);
    final activeCount = ref.watch(activeAccountsProvider).length;
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final locale = profile?.localeCode ?? 'pt_BR';
    final currency = profile?.defaultCurrency ?? 'BRL';
    final theme = Theme.of(context);

    final isCompact = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas'),
        actions: [
          if (activeCount >= 2) ...[
            if (isCompact)
              IconButton(
                tooltip: 'Transferir',
                onPressed: () => showTransferFormDialog(context),
                icon: const Icon(Icons.swap_horiz_rounded),
              )
            else
              OutlinedButton.icon(
                onPressed: () => showTransferFormDialog(context),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Transferir'),
              ),
            const SizedBox(width: 4),
          ],
          if (isCompact)
            IconButton(
              tooltip: 'Nova conta',
              onPressed: () => showAccountFormDialog(context),
              icon: const Icon(Icons.add_circle_outline_rounded),
            )
          else
            FilledButton.icon(
              onPressed: () => showAccountFormDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nova conta'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyStateView(
          icon: Icons.error_outline_rounded,
          title: 'Erro ao carregar contas',
          description: error.toString(),
          actionLabel: 'Tentar novamente',
          onAction: () => ref.invalidate(accountsStreamProvider),
        ),
        data: (accounts) {
          final visible = accounts
              .where((acc) => _showArchived || acc.isActive)
              .toList(growable: false);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Saldo total em contas ativas',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormatter.formatCents(
                                    totalBalanceCents,
                                    locale: locale,
                                    currencyCode: currency,
                                  ),
                                  style:
                                      theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: totalBalanceCents >= 0
                                        ? AppColors.primaryLight
                                        : AppColors.expense,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$activeCount conta(s) ativa(s)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            FilterChip(
                              label: const Text('Mostrar arquivadas'),
                              selected: _showArchived,
                              onSelected: (value) {
                                setState(() => _showArchived = value);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: visible.isEmpty
                        ? EmptyStateView(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Nenhuma conta cadastrada',
                            description:
                                'Cadastre sua conta corrente, poupança, carteira ou dinheiro em espécie para controlar saldos e transferências.',
                            actionLabel: 'Cadastrar primeira conta',
                            onAction: () => showAccountFormDialog(context),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final account = visible[index];
                              final accent =
                                  ColorUtils.fromHex(account.colorHex);
                              final iconData = IconCatalog.resolve(
                                account.iconName,
                                fallback: Icons.account_balance_rounded,
                              );

                              return Card(
                                child: InkWell(
                                  onTap: () => _openStatement(account),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: accent.withOpacity(0.14),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Icon(iconData, color: accent),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 4,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  Text(
                                                    account.name,
                                                    style: theme
                                                        .textTheme.titleMedium
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  StatusBadge(
                                                    label: account.isActive
                                                        ? 'Ativa'
                                                        : 'Arquivada',
                                                    color: account.isActive
                                                        ? AppColors.income
                                                        : AppColors.warning,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                [
                                                  account.type.label,
                                                  if (account
                                                      .institution.isNotEmpty)
                                                    account.institution,
                                                  'Aberta em ${DateFormatter.shortDate(account.openedAt, locale: locale)}',
                                                ].join(' • '),
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              CurrencyFormatter.formatCents(
                                                account.currentBalanceCents,
                                                locale: locale,
                                                currencyCode: currency,
                                              ),
                                              style: theme
                                                  .textTheme.titleMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    account.currentBalanceCents >=
                                                            0
                                                        ? AppColors.income
                                                        : AppColors.expense,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TextButton(
                                                  onPressed: () =>
                                                      _openStatement(account),
                                                  child: const Text('Extrato'),
                                                ),
                                                PopupMenuButton<String>(
                                                  onSelected: (action) {
                                                    switch (action) {
                                                      case 'statement':
                                                        _openStatement(account);
                                                        break;
                                                      case 'transfer':
                                                        showTransferFormDialog(
                                                          context,
                                                          initialSourceAccountId:
                                                              account.id,
                                                        );
                                                        break;
                                                      case 'edit':
                                                        showAccountFormDialog(
                                                          context,
                                                          existing: account,
                                                        );
                                                        break;
                                                      case 'archive':
                                                        ref
                                                            .read(
                                                                accountControllerProvider
                                                                    .notifier)
                                                            .setArchived(
                                                              accountId:
                                                                  account.id,
                                                              archived: account
                                                                  .isActive,
                                                            );
                                                        break;
                                                      case 'delete':
                                                        _confirmDelete(account);
                                                        break;
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    const PopupMenuItem(
                                                      value: 'statement',
                                                      child: Text('Ver extrato'),
                                                    ),
                                                    if (account.isActive &&
                                                        activeCount >= 2)
                                                      const PopupMenuItem(
                                                        value: 'transfer',
                                                        child: Text(
                                                          'Transferir desta conta',
                                                        ),
                                                      ),
                                                    const PopupMenuItem(
                                                      value: 'edit',
                                                      child: Text('Editar'),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'archive',
                                                      child: Text(
                                                        account.isActive
                                                            ? 'Arquivar'
                                                            : 'Reativar',
                                                      ),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'delete',
                                                      child: Text('Excluir'),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
