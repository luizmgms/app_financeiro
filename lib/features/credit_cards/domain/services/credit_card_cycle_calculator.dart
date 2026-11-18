import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import '../../../../shared/models/money.dart';
import '../entities/invoice_entity.dart';

/// Ciclo calculado de uma fatura para uma compra ou parcela específica.
class InvoiceCycleTarget extends Equatable {
  const InvoiceCycleTarget({
    required this.invoiceId,
    required this.cardId,
    required this.referenceYear,
    required this.referenceMonth,
    required this.closingDate,
    required this.dueDate,
    required this.competencyDate,
  });

  final String invoiceId;
  final String cardId;
  final int referenceYear;
  final int referenceMonth;
  final DateTime closingDate;
  final DateTime dueDate;
  final DateTime competencyDate;

  @override
  List<Object?> get props => [
        invoiceId,
        cardId,
        referenceYear,
        referenceMonth,
        closingDate,
        dueDate,
        competencyDate,
      ];
}

/// Item individual de uma compra parcelada já alocado em sua fatura ou vencimento.
class InstallmentSlice extends Equatable {
  const InstallmentSlice({
    required this.installmentNumber,
    required this.totalInstallments,
    required this.amountCents,
    required this.competencyDate,
    required this.dueDate,
    this.invoiceTarget,
  });

  final int installmentNumber;
  final int totalInstallments;
  final int amountCents;
  final DateTime competencyDate;
  final DateTime dueDate;
  final InvoiceCycleTarget? invoiceTarget;

  @override
  List<Object?> get props => [
        installmentNumber,
        totalInstallments,
        amountCents,
        competencyDate,
        dueDate,
        invoiceTarget,
      ];
}

/// Motor puro de cálculo de ciclos de fechamento/vencimento de faturas e parcelamentos.
abstract final class CreditCardCycleCalculator {
  /// Gera o identificador determinístico da fatura `{cardId}_{YYYY}_{MM}`.
  static String buildInvoiceId({
    required String cardId,
    required int referenceYear,
    required int referenceMonth,
  }) {
    final mm = referenceMonth.toString().padLeft(2, '0');
    return '${cardId}_${referenceYear}_$mm';
  }

  /// Último dia válido de um mês/ano.
  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  /// Cria uma data ajustando o dia ao limite máximo do mês (ex.: 31 em fevereiro -> 28/29).
  static DateTime clampDate(int year, int month, int desiredDay) {
    final normalizedMonthDate = DateTime(year, month, 1);
    final y = normalizedMonthDate.year;
    final m = normalizedMonthDate.month;
    final maxDay = daysInMonth(y, m);
    final safeDay = desiredDay.clamp(1, maxDay);
    return DateTime(y, m, safeDay, 12);
  }

  /// Adiciona [monthOffset] meses a [baseDate] preservando o dia dentro do limite do mês alvo.
  static DateTime addMonths(DateTime baseDate, int monthOffset) {
    final targetFirst = DateTime(baseDate.year, baseDate.month + monthOffset, 1);
    return clampDate(targetFirst.year, targetFirst.month, baseDate.day);
  }

  /// Determina a fatura alvo para uma compra realizada em [purchaseDate],
  /// deslocada em [installmentOffset] meses (0 para 1ª parcela, 1 para 2ª, etc.).
  ///
  /// Regra de corte:
  /// - Compras realizadas **antes** do dia efetivo de fechamento do mês entram na
  ///   fatura que fecha naquele próprio mês.
  /// - Compras realizadas **no dia de fechamento ou após** entram na fatura do
  ///   mês subsequente.
  /// - Se `dueDay < closingDay` (ex.: fecha dia 25 e vence dia 5), a data de
  ///   vencimento cai no mês seguinte ao mês de fechamento.
  static InvoiceCycleTarget resolveInvoiceForPurchase({
    required String cardId,
    required DateTime purchaseDate,
    required int closingDay,
    required int dueDay,
    int installmentOffset = 0,
  }) {
    final purchaseMonthClosing = clampDate(
      purchaseDate.year,
      purchaseDate.month,
      closingDay,
    );
    final purchaseDayOnly = DateTime(
      purchaseDate.year,
      purchaseDate.month,
      purchaseDate.day,
    );
    final closingDayOnly = DateTime(
      purchaseMonthClosing.year,
      purchaseMonthClosing.month,
      purchaseMonthClosing.day,
    );

    final baseMonthShift = !purchaseDayOnly.isBefore(closingDayOnly) ? 1 : 0;
    final totalShift = baseMonthShift + installmentOffset;

    final refMonthFirst = DateTime(
      purchaseDate.year,
      purchaseDate.month + totalShift,
      1,
    );
    final refYear = refMonthFirst.year;
    final refMonth = refMonthFirst.month;

    final closingDate = clampDate(refYear, refMonth, closingDay);
    final dueDate = dueDay >= closingDay
        ? clampDate(refYear, refMonth, dueDay)
        : clampDate(refYear, refMonth + 1, dueDay);

    final competencyDate = installmentOffset == 0
        ? DateTime(
            purchaseDate.year,
            purchaseDate.month,
            purchaseDate.day,
            12,
          )
        : addMonths(purchaseDate, installmentOffset);

    return InvoiceCycleTarget(
      invoiceId: buildInvoiceId(
        cardId: cardId,
        referenceYear: refYear,
        referenceMonth: refMonth,
      ),
      cardId: cardId,
      referenceYear: refYear,
      referenceMonth: refMonth,
      closingDate: closingDate,
      dueDate: dueDate,
      competencyDate: competencyDate,
    );
  }

  /// Gera as parcelas de uma compra no cartão com distribuição exata de centavos
  /// e alocação automática nas faturas correspondentes.
  static List<InstallmentSlice> buildCardInstallmentSchedule({
    required String cardId,
    required int totalAmountCents,
    required int installmentCount,
    required DateTime purchaseDate,
    required int closingDay,
    required int dueDay,
  }) {
    final parts =
        Money(cents: totalAmountCents).splitEqually(installmentCount);
    return List<InstallmentSlice>.generate(installmentCount, (index) {
      final target = resolveInvoiceForPurchase(
        cardId: cardId,
        purchaseDate: purchaseDate,
        closingDay: closingDay,
        dueDay: dueDay,
        installmentOffset: index,
      );
      return InstallmentSlice(
        installmentNumber: index + 1,
        totalInstallments: installmentCount,
        amountCents: parts[index].cents,
        competencyDate: target.competencyDate,
        dueDate: target.dueDate,
        invoiceTarget: target,
      );
    }, growable: false);
  }

  /// Gera as parcelas de uma despesa parcelada direta em conta/boleto
  /// com distribuição exata de centavos.
  static List<InstallmentSlice> buildAccountInstallmentSchedule({
    required int totalAmountCents,
    required int installmentCount,
    required DateTime purchaseDate,
    required DateTime firstDueDate,
  }) {
    final parts =
        Money(cents: totalAmountCents).splitEqually(installmentCount);
    return List<InstallmentSlice>.generate(installmentCount, (index) {
      return InstallmentSlice(
        installmentNumber: index + 1,
        totalInstallments: installmentCount,
        amountCents: parts[index].cents,
        competencyDate: addMonths(purchaseDate, index),
        dueDate: addMonths(firstDueDate, index),
      );
    }, growable: false);
  }

  /// Calcula o limite total comprometido a partir das faturas do cartão.
  static int calculateUsedLimitFromInvoices(
    Iterable<InvoiceEntity> invoices, {
    String? cardId,
  }) {
    var used = 0;
    for (final inv in invoices) {
      if (cardId != null && inv.cardId != cardId) continue;
      if (inv.status == InvoiceStatus.paid) continue;
      used += inv.remainingAmountCents;
    }
    return math.max(0, used);
  }
}
