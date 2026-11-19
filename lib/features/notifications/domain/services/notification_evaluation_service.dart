import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../credit_cards/domain/entities/credit_card_entity.dart';
import '../../../credit_cards/domain/entities/invoice_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../entities/app_notification_entity.dart';

/// Entrada opcional de orçamento mensal para avaliação de alertas de limite.
class BudgetAlertEvaluationInput {
  const BudgetAlertEvaluationInput({
    required this.budgetId,
    required this.categoryName,
    required this.year,
    required this.month,
    required this.limitCents,
    required this.spentCents,
    this.alertThresholdPercent = 80,
  });

  final String budgetId;
  final String categoryName;
  final int year;
  final int month;
  final int limitCents;
  final int spentCents;
  final int alertThresholdPercent;
}

/// Serviço puro e determinístico para gerar alertas financeiros sem duplicação,
/// respeitando a antecedência configurada pelo usuário (`reminderDaysBefore`).
abstract final class NotificationEvaluationService {
  static List<AppNotificationEntity> evaluateSystemAlerts({
    required List<TransactionEntity> transactions,
    required List<InvoiceEntity> invoices,
    required Map<String, CreditCardEntity> cardsById,
    required int reminderDaysBefore,
    required bool notificationsEnabled,
    required DateTime referenceDate,
    String locale = 'pt_BR',
    String currencyCode = 'BRL',
    List<BudgetAlertEvaluationInput> budgets =
        const <BudgetAlertEvaluationInput>[],
  }) {
    if (!notificationsEnabled) {
      return const <AppNotificationEntity>[];
    }

    final safeLeadDays = reminderDaysBefore.clamp(1, 30);
    final todayStart = DateFormatter.dateOnly(referenceDate);
    final windowEnd = todayStart.add(Duration(days: safeLeadDays));
    final alerts = <AppNotificationEntity>[];

    String fmtMoney(int cents) => CurrencyFormatter.formatCents(
          cents,
          locale: locale,
          currencyCode: currencyCode,
        );

    String countdownLabel(DateTime targetDay) {
      final diffDays = targetDay.difference(todayStart).inDays;
      if (diffDays == 0) return 'vence hoje';
      if (diffDays == 1) return 'vence amanhã';
      return 'vence em $diffDays dias';
    }

    // 1. Contas a pagar (vencidas e próximas) + receitas previstas.
    for (final tx in transactions) {
      if (tx.status.isSettled) continue;

      if (tx.kind == TransactionKind.expense) {
        final targetDay = DateFormatter.dateOnly(tx.dueDate ?? tx.competencyDate);
        final ymd = DateFormatter.isoDateKey(targetDay);
        final formattedDate = DateFormatter.shortDate(targetDay, locale: locale);
        final amountText = fmtMoney(tx.amountCents);

        if (targetDay.isBefore(todayStart)) {
          alerts.add(
            AppNotificationEntity(
              id: 'overdue_${tx.id}_$ymd',
              title: 'Conta vencida: ${tx.description}',
              body: 'Venceu em $formattedDate • Valor $amountText.',
              type: NotificationType.overduePayable,
              referenceId: tx.id,
              scheduledFor: targetDay,
              isRead: false,
              isCustom: false,
              createdAt: referenceDate,
              updatedAt: referenceDate,
            ),
          );
        } else if (!targetDay.isAfter(windowEnd)) {
          alerts.add(
            AppNotificationEntity(
              id: 'due_soon_${tx.id}_$ymd',
              title: 'Conta a vencer: ${tx.description}',
              body:
                  '${countdownLabel(targetDay)[0].toUpperCase()}${countdownLabel(targetDay).substring(1)} ($formattedDate) • Valor $amountText.',
              type: NotificationType.upcomingPayable,
              referenceId: tx.id,
              scheduledFor: targetDay,
              isRead: false,
              isCustom: false,
              createdAt: referenceDate,
              updatedAt: referenceDate,
            ),
          );
        }
      } else if (tx.kind == TransactionKind.income) {
        final targetDay = DateFormatter.dateOnly(tx.dueDate ?? tx.competencyDate);
        if (!targetDay.isBefore(todayStart) && !targetDay.isAfter(windowEnd)) {
          final ymd = DateFormatter.isoDateKey(targetDay);
          final formattedDate =
              DateFormatter.shortDate(targetDay, locale: locale);
          final amountText = fmtMoney(tx.amountCents);
          alerts.add(
            AppNotificationEntity(
              id: 'income_${tx.id}_$ymd',
              title: 'Receita prevista: ${tx.description}',
              body:
                  'Previsão de recebimento em $formattedDate • Valor $amountText.',
              type: NotificationType.expectedIncome,
              referenceId: tx.id,
              scheduledFor: targetDay,
              isRead: false,
              isCustom: false,
              createdAt: referenceDate,
              updatedAt: referenceDate,
            ),
          );
        }
      }
    }

    // 2. Faturas de cartão próximas do vencimento ou vencidas.
    for (final invoice in invoices) {
      if (invoice.status == InvoiceStatus.paid ||
          invoice.remainingAmountCents <= 0) {
        continue;
      }

      final dueDay = DateFormatter.dateOnly(invoice.dueDate);
      final ymd = DateFormatter.isoDateKey(dueDay);
      final cardName = cardsById[invoice.cardId]?.name ?? 'Cartão de crédito';
      final formattedDate = DateFormatter.shortDate(dueDay, locale: locale);
      final amountText = fmtMoney(invoice.remainingAmountCents);

      if (dueDay.isBefore(todayStart)) {
        alerts.add(
          AppNotificationEntity(
            id: 'inv_overdue_${invoice.id}_$ymd',
            title: 'Fatura vencida • $cardName',
            body:
                'Fatura ${invoice.referenceLabel} venceu em $formattedDate • Restante $amountText.',
            type: NotificationType.invoiceDue,
            referenceId: invoice.id,
            scheduledFor: dueDay,
            isRead: false,
            isCustom: false,
            createdAt: referenceDate,
            updatedAt: referenceDate,
          ),
        );
      } else if (!dueDay.isAfter(windowEnd)) {
        alerts.add(
          AppNotificationEntity(
            id: 'inv_due_${invoice.id}_$ymd',
            title: 'Fatura próxima do vencimento • $cardName',
            body:
                'Fatura ${invoice.referenceLabel} ${countdownLabel(dueDay)} ($formattedDate) • Total $amountText.',
            type: NotificationType.invoiceDue,
            referenceId: invoice.id,
            scheduledFor: dueDay,
            isRead: false,
            isCustom: false,
            createdAt: referenceDate,
            updatedAt: referenceDate,
          ),
        );
      }
    }

    // 3. Orçamentos (próximo do limite e ultrapassado).
    for (final budget in budgets) {
      if (budget.limitCents <= 0) continue;
      final refMonth =
          '${budget.month.toString().padLeft(2, '0')}/${budget.year}';
      final pct = (budget.spentCents * 100 / budget.limitCents).round();

      if (budget.spentCents > budget.limitCents) {
        alerts.add(
          AppNotificationEntity(
            id: 'budget_over_${budget.budgetId}_${budget.year}_${budget.month}',
            title: 'Orçamento ultrapassado: ${budget.categoryName}',
            body:
                'Consumo de ${fmtMoney(budget.spentCents)} sobre limite de ${fmtMoney(budget.limitCents)} ($pct%) em $refMonth.',
            type: NotificationType.budgetExceeded,
            referenceId: budget.budgetId,
            scheduledFor: todayStart,
            isRead: false,
            isCustom: false,
            createdAt: referenceDate,
            updatedAt: referenceDate,
          ),
        );
      } else if (pct >= budget.alertThresholdPercent) {
        alerts.add(
          AppNotificationEntity(
            id: 'budget_warn_${budget.budgetId}_${budget.year}_${budget.month}',
            title: 'Orçamento próximo do limite: ${budget.categoryName}',
            body:
                'Você já utilizou $pct% (${fmtMoney(budget.spentCents)} de ${fmtMoney(budget.limitCents)}) em $refMonth.',
            type: NotificationType.budgetWarning,
            referenceId: budget.budgetId,
            scheduledFor: todayStart,
            isRead: false,
            isCustom: false,
            createdAt: referenceDate,
            updatedAt: referenceDate,
          ),
        );
      }
    }

    alerts.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return alerts;
  }
}
