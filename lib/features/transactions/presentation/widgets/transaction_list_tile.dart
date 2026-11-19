import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/icon_catalog.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../credit_cards/domain/entities/credit_card_entity.dart';
import '../../domain/entities/transaction_attachment.dart';
import '../../domain/entities/transaction_entity.dart';

/// Card compacto e reutilizável para exibir uma movimentação financeira.
class TransactionListTile extends StatelessWidget {
  const TransactionListTile({
    super.key,
    required this.transaction,
    this.category,
    this.account,
    this.counterpartyAccount,
    this.card,
    this.locale = 'pt_BR',
    this.currencyCode = 'BRL',
    this.onTap,
    this.onMarkAsSettled,
    this.onEdit,
    this.onDuplicate,
    this.onDelete,
  });

  final TransactionEntity transaction;
  final CategoryEntity? category;
  final AccountEntity? account;
  final AccountEntity? counterpartyAccount;
  final CreditCardEntity? card;
  final String locale;
  final String currencyCode;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsSettled;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  Future<void> _showAttachmentsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Comprovantes (${transaction.attachments.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                for (final att in transaction.attachments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      att.isImage
                          ? Icons.image_outlined
                          : Icons.picture_as_pdf_outlined,
                      color: AppColors.primaryLight,
                    ),
                    title: Text(att.name),
                    subtitle: Text(
                      '${(att.sizeBytes / 1024).toStringAsFixed(1)} KB',
                    ),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => _openAttachment(context, att),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAttachment(
    BuildContext context,
    TransactionAttachment attachment,
  ) async {
    if (attachment.isImage) {
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(attachment.name),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 640,
                  maxHeight: 520,
                ),
                child: InteractiveViewer(
                  child: Image.network(
                    attachment.url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Não foi possível carregar a imagem.'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(attachment.url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effStatus = transaction.effectiveStatus();
    final isTransfer = transaction.kind == TransactionKind.transfer;
    final isCardRefund = transaction.kind == TransactionKind.cardRefund;
    final isInflow = transaction.kind == TransactionKind.income ||
        isCardRefund ||
        (isTransfer &&
            transaction.transferDirection == TransferDirection.inflow);

    final badgeColor = switch (transaction.kind) {
      TransactionKind.transfer => AppColors.transfer,
      TransactionKind.income || TransactionKind.cardRefund => AppColors.income,
      TransactionKind.expense ||
      TransactionKind.cardPurchase ||
      TransactionKind.invoicePayment =>
        category != null
            ? ColorUtils.fromHex(category!.colorHex, fallback: AppColors.expense)
            : AppColors.expense,
    };

    final iconData = isTransfer
        ? Icons.swap_horiz_rounded
        : isCardRefund
            ? Icons.replay_rounded
            : IconCatalog.resolve(
                category?.iconName,
                fallback: isInflow
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
              );

    final amountColor = isTransfer
        ? AppColors.transfer
        : isInflow
            ? AppColors.income
            : AppColors.expense;

    final signedPrefix = isInflow ? '+' : '-';
    final amountText =
        '$signedPrefix ${CurrencyFormatter.formatCents(transaction.amountCents, locale: locale, currencyCode: currencyCode)}';

    final statusColor = switch (effStatus) {
      TransactionStatus.paid || TransactionStatus.received => AppColors.income,
      TransactionStatus.completed => AppColors.transfer,
      TransactionStatus.pending => AppColors.warning,
      TransactionStatus.overdue => AppColors.expense,
    };

    final isCardPurchase = transaction.kind == TransactionKind.cardPurchase;
    final isInvoicePayment = transaction.kind == TransactionKind.invoicePayment;
    final canEditOrDuplicate = transaction.kind == TransactionKind.income ||
        transaction.kind == TransactionKind.expense;

    final statusLabel = isTransfer
        ? 'Transferência'
        : isInvoicePayment
            ? 'Fatura Paga'
            : isCardRefund
                ? 'Estorno no Cartão'
                : effStatus.label;

    final accountLabel = isTransfer && counterpartyAccount != null
        ? (transaction.transferDirection == TransferDirection.outflow
            ? '${account?.name ?? 'Conta'} -> ${counterpartyAccount!.name}'
            : '${counterpartyAccount!.name} -> ${account?.name ?? 'Conta'}')
        : (isCardPurchase || isCardRefund)
            ? 'Cartão: ${card?.name ?? 'Cartão de crédito'}'
            : (account?.name ?? 'Sem conta');

    final subtitleParts = <String>[
      if (!isTransfer && category != null) category!.name,
      accountLabel,
      DateFormatter.shortDate(transaction.competencyDate, locale: locale),
      if (transaction.dueDate != null && !effStatus.isSettled)
        'Venc. ${DateFormatter.shortDate(transaction.dueDate!, locale: locale)}',
    ];

    final canSettle = !isTransfer &&
        !effStatus.isSettled &&
        canEditOrDuplicate &&
        onMarkAsSettled != null;

    return Card(
      child: InkWell(
        onTap: onTap ?? (canEditOrDuplicate ? onEdit : null),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: badgeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitleParts.join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBadge(label: statusLabel, color: statusColor),
                        if (isCardPurchase)
                          const StatusBadge(
                            label: 'Cartão',
                            color: AppColors.credit,
                            icon: Icons.credit_card_rounded,
                          ),
                        if ((transaction.totalInstallments ?? 1) > 1)
                          StatusBadge(
                            label:
                                '${transaction.installmentNumber}/${transaction.totalInstallments}',
                            color: AppColors.primaryLight,
                          ),
                        if (transaction.recurringId != null &&
                            transaction.recurringId!.isNotEmpty)
                          const StatusBadge(
                            label: 'Recorrente',
                            color: AppColors.transfer,
                            icon: Icons.repeat_rounded,
                          ),
                        if (transaction.attachments.isNotEmpty)
                          InkWell(
                            onTap: () => _showAttachmentsSheet(context),
                            borderRadius: BorderRadius.circular(999),
                            child: StatusBadge(
                              label:
                                  '${transaction.attachments.length} anexo(s)',
                              color: AppColors.primaryLight,
                              icon: Icons.attach_file_rounded,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    amountText,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canSettle)
                        IconButton(
                          tooltip: transaction.kind == TransactionKind.income
                              ? 'Marcar como recebida'
                              : 'Marcar como paga',
                          visualDensity: VisualDensity.compact,
                          onPressed: onMarkAsSettled,
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: AppColors.income,
                            size: 20,
                          ),
                        ),
                      if ((canEditOrDuplicate &&
                              (onEdit != null || onDuplicate != null)) ||
                          (!isInvoicePayment && onDelete != null))
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          onSelected: (value) {
                            switch (value) {
                              case 'settle':
                                onMarkAsSettled?.call();
                                break;
                              case 'edit':
                                onEdit?.call();
                                break;
                              case 'duplicate':
                                onDuplicate?.call();
                                break;
                              case 'delete':
                                onDelete?.call();
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            if (canSettle)
                              PopupMenuItem(
                                value: 'settle',
                                child: Text(
                                  transaction.kind == TransactionKind.income
                                      ? 'Confirmar recebimento'
                                      : 'Confirmar pagamento',
                                ),
                              ),
                            if (canEditOrDuplicate && onEdit != null)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                            if (canEditOrDuplicate && onDuplicate != null)
                              const PopupMenuItem(
                                value: 'duplicate',
                                child: Text('Duplicar'),
                              ),
                            if (!isInvoicePayment && onDelete != null)
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
  }
}
