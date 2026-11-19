export type RecurringKind = "income" | "expense";

export type RecurringFrequency =
  | "daily"
  | "weekly"
  | "biweekly"
  | "monthly"
  | "bimonthly"
  | "quarterly"
  | "semiannual"
  | "annual"
  | "custom";

export type RecurringStatus = "active" | "paused" | "canceled";

export interface RecurringRuleRecord {
  id: string;
  description: string;
  kind: RecurringKind;
  amountCents: number;
  isVariableAmount: boolean;
  categoryId: string;
  accountId?: string | null;
  cardId?: string | null;
  frequency: RecurringFrequency;
  customIntervalDays?: number | null;
  startDate: Date;
  endDate?: Date | null;
  status: RecurringStatus;
  skippedOccurrenceKeys?: string[];
  notes?: string | null;
}

export interface RecurringOccurrenceSpec {
  recurringId: string;
  occurrenceKey: string;
  transactionDocId: string;
  scheduledDate: Date;
  dateKey: string;
}

export interface InvoiceCycleTarget {
  invoiceId: string;
  cardId: string;
  referenceYear: number;
  referenceMonth: number;
  closingDate: Date;
  dueDate: Date;
}

export type NotificationType =
  | "upcoming_payable"
  | "overdue_payable"
  | "invoice_due"
  | "budget_warning"
  | "budget_exceeded"
  | "expected_income"
  | "custom_reminder";

export interface AlertCandidate {
  id: string;
  title: string;
  body: string;
  type: NotificationType;
  referenceId: string;
  scheduledFor: Date;
}

export interface TransactionSnapshotInput {
  id: string;
  kind: string;
  description: string;
  amountCents: number;
  status: string;
  competencyDate: Date;
  dueDate?: Date | null;
}

export interface InvoiceSnapshotInput {
  id: string;
  cardId: string;
  referenceYear: number;
  referenceMonth: number;
  dueDate: Date;
  totalAmountCents: number;
  paidAmountCents: number;
  status: string;
}

export interface BudgetSnapshotInput {
  id: string;
  categoryName: string;
  year: number;
  month: number;
  limitCents: number;
  spentCents: number;
  alertThresholdPercent?: number;
}

const SETTLED_STATUSES = new Set(["paid", "received", "completed"]);

/**
 * Normaliza uma data UTC ao meio-dia (12:00 UTC) evitando deslocamentos por fuso horário.
 */
export function normalizeCalendarDate(date: Date, timeZone = "America/Sao_Paulo"): Date {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const [y, m, d] = formatter.format(date).split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d, 12, 0, 0, 0));
}

export function makeCalendarDate(year: number, month: number, day: number): Date {
  return new Date(Date.UTC(year, month - 1, day, 12, 0, 0, 0));
}

export function isoDateKey(date: Date): string {
  const y = date.getUTCFullYear().toString().padStart(4, "0");
  const m = (date.getUTCMonth() + 1).toString().padStart(2, "0");
  const d = date.getUTCDate().toString().padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export function shortPtDate(date: Date): string {
  const d = date.getUTCDate().toString().padStart(2, "0");
  const m = (date.getUTCMonth() + 1).toString().padStart(2, "0");
  const y = date.getUTCFullYear().toString().padStart(4, "0");
  return `${d}/${m}/${y}`;
}

export function formatBrlCents(cents: number): string {
  const abs = Math.abs(cents) / 100;
  const formatted = abs.toLocaleString("pt-BR", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return cents < 0 ? `-R$ ${formatted}` : `R$ ${formatted}`;
}

export function daysInMonthUtc(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0, 12, 0, 0, 0)).getUTCDate();
}

export function addDaysUtc(date: Date, days: number): Date {
  return new Date(date.getTime() + days * 86_400_000);
}

export function addMonthsClampingDay(anchor: Date, monthsToAdd: number): Date {
  const totalMonths =
    anchor.getUTCFullYear() * 12 + anchor.getUTCMonth() + monthsToAdd;
  const targetYear = Math.floor(totalMonths / 12);
  const targetMonth = (totalMonths % 12) + 1;
  const maxDay = daysInMonthUtc(targetYear, targetMonth);
  const clampedDay = Math.min(anchor.getUTCDate(), maxDay);
  return makeCalendarDate(targetYear, targetMonth, clampedDay);
}

export function dateAtOccurrenceIndex(
  anchorStartDate: Date,
  occurrenceIndex: number,
  frequency: RecurringFrequency,
  customIntervalDays?: number | null,
): Date {
  if (occurrenceIndex <= 0) return anchorStartDate;

  switch (frequency) {
    case "daily":
      return addDaysUtc(anchorStartDate, occurrenceIndex);
    case "weekly":
      return addDaysUtc(anchorStartDate, occurrenceIndex * 7);
    case "biweekly":
      return addDaysUtc(anchorStartDate, occurrenceIndex * 14);
    case "monthly":
      return addMonthsClampingDay(anchorStartDate, occurrenceIndex);
    case "bimonthly":
      return addMonthsClampingDay(anchorStartDate, occurrenceIndex * 2);
    case "quarterly":
      return addMonthsClampingDay(anchorStartDate, occurrenceIndex * 3);
    case "semiannual":
      return addMonthsClampingDay(anchorStartDate, occurrenceIndex * 6);
    case "annual":
      return addMonthsClampingDay(anchorStartDate, occurrenceIndex * 12);
    case "custom": {
      const interval =
        customIntervalDays && customIntervalDays > 0 ? customIntervalDays : 1;
      return addDaysUtc(anchorStartDate, occurrenceIndex * interval);
    }
  }
}

export function defaultHorizonEnd(
  referenceDay: Date,
  frequency: RecurringFrequency,
  customIntervalDays?: number | null,
): Date {
  let daysAhead = 90;
  if (frequency === "daily") {
    daysAhead = 14;
  } else if (frequency === "weekly" || frequency === "biweekly") {
    daysAhead = 45;
  } else if (
    frequency === "custom" &&
    customIntervalDays != null &&
    customIntervalDays < 7
  ) {
    daysAhead = 21;
  }
  return addDaysUtc(referenceDay, daysAhead);
}

export function computeOccurrencesInWindow(
  rule: RecurringRuleRecord,
  referenceDate: Date,
  maxOccurrences = 30,
): RecurringOccurrenceSpec[] {
  if (rule.status !== "active" || !rule.id) return [];

  const anchor = normalizeCalendarDate(rule.startDate);
  const refDay = normalizeCalendarDate(referenceDate);
  const lookbackStart = addDaysUtc(refDay, -60);
  const lowerBound =
    anchor.getTime() > lookbackStart.getTime() ? anchor : lookbackStart;

  let upperBound = defaultHorizonEnd(
    refDay,
    rule.frequency,
    rule.customIntervalDays,
  );
  if (rule.endDate) {
    const endDay = normalizeCalendarDate(rule.endDate);
    if (endDay.getTime() < anchor.getTime()) return [];
    if (endDay.getTime() < upperBound.getTime()) {
      upperBound = endDay;
    }
  }
  if (upperBound.getTime() < anchor.getTime()) return [];

  const skipped = new Set(rule.skippedOccurrenceKeys ?? []);
  const specs: RecurringOccurrenceSpec[] = [];

  for (let idx = 0; idx < 5000; idx++) {
    const candidate = dateAtOccurrenceIndex(
      anchor,
      idx,
      rule.frequency,
      rule.customIntervalDays,
    );
    if (candidate.getTime() > upperBound.getTime()) break;
    if (candidate.getTime() < lowerBound.getTime()) continue;

    const dKey = isoDateKey(candidate);
    const occKey = `${rule.id}_${dKey}`;
    if (skipped.has(occKey)) continue;

    specs.push({
      recurringId: rule.id,
      occurrenceKey: occKey,
      transactionDocId: `rec_${occKey}`,
      scheduledDate: candidate,
      dateKey: dKey,
    });

    if (specs.length >= maxOccurrences) break;
  }

  return specs;
}

export function resolveInvoiceTarget(
  cardId: string,
  purchaseDate: Date,
  closingDay: number,
  dueDay: number,
): InvoiceCycleTarget {
  const year = purchaseDate.getUTCFullYear();
  const month = purchaseDate.getUTCMonth() + 1;
  const maxClosing = daysInMonthUtc(year, month);
  const safeClosing = Math.min(Math.max(closingDay, 1), maxClosing);
  const purchaseClosing = makeCalendarDate(year, month, safeClosing);

  const shift = purchaseDate.getTime() >= purchaseClosing.getTime() ? 1 : 0;
  const totalMonths = year * 12 + (month - 1) + shift;
  const refYear = Math.floor(totalMonths / 12);
  const refMonth = (totalMonths % 12) + 1;

  const closingDate = makeCalendarDate(
    refYear,
    refMonth,
    Math.min(Math.max(closingDay, 1), daysInMonthUtc(refYear, refMonth)),
  );

  let dueYear = refYear;
  let dueMonth = refMonth;
  if (dueDay < closingDay) {
    const nextMonthTotal = refYear * 12 + (refMonth - 1) + 1;
    dueYear = Math.floor(nextMonthTotal / 12);
    dueMonth = (nextMonthTotal % 12) + 1;
  }
  const dueDate = makeCalendarDate(
    dueYear,
    dueMonth,
    Math.min(Math.max(dueDay, 1), daysInMonthUtc(dueYear, dueMonth)),
  );

  const mm = refMonth.toString().padStart(2, "0");
  return {
    invoiceId: `${cardId}_${refYear}_${mm}`,
    cardId,
    referenceYear: refYear,
    referenceMonth: refMonth,
    closingDate,
    dueDate,
  };
}

export function evaluateNotificationCandidates(params: {
  transactions: TransactionSnapshotInput[];
  invoices: InvoiceSnapshotInput[];
  cardNamesById: Record<string, string>;
  reminderDaysBefore: number;
  notificationsEnabled: boolean;
  referenceDate: Date;
  budgets?: BudgetSnapshotInput[];
}): AlertCandidate[] {
  if (!params.notificationsEnabled) return [];

  const leadDays = Math.min(Math.max(params.reminderDaysBefore || 3, 1), 30);
  const todayStart = normalizeCalendarDate(params.referenceDate);
  const windowEnd = addDaysUtc(todayStart, leadDays);
  const alerts: AlertCandidate[] = [];

  for (const tx of params.transactions) {
    if (SETTLED_STATUSES.has(tx.status)) continue;

    if (tx.kind === "expense") {
      const targetDay = normalizeCalendarDate(tx.dueDate ?? tx.competencyDate);
      const ymd = isoDateKey(targetDay);
      const formattedDate = shortPtDate(targetDay);
      const amount = formatBrlCents(tx.amountCents);

      if (targetDay.getTime() < todayStart.getTime()) {
        alerts.push({
          id: `overdue_${tx.id}_${ymd}`,
          title: `Conta vencida: ${tx.description}`,
          body: `Venceu em ${formattedDate} • Valor ${amount}.`,
          type: "overdue_payable",
          referenceId: tx.id,
          scheduledFor: targetDay,
        });
      } else if (targetDay.getTime() <= windowEnd.getTime()) {
        const diffDays = Math.round(
          (targetDay.getTime() - todayStart.getTime()) / 86_400_000,
        );
        const countdown =
          diffDays === 0
            ? "Vence hoje"
            : diffDays === 1
              ? "Vence amanhã"
              : `Vence em ${diffDays} dias`;
        alerts.push({
          id: `due_soon_${tx.id}_${ymd}`,
          title: `Conta a vencer: ${tx.description}`,
          body: `${countdown} (${formattedDate}) • Valor ${amount}.`,
          type: "upcoming_payable",
          referenceId: tx.id,
          scheduledFor: targetDay,
        });
      }
    } else if (tx.kind === "income") {
      const targetDay = normalizeCalendarDate(tx.dueDate ?? tx.competencyDate);
      if (
        targetDay.getTime() >= todayStart.getTime() &&
        targetDay.getTime() <= windowEnd.getTime()
      ) {
        const ymd = isoDateKey(targetDay);
        alerts.push({
          id: `income_${tx.id}_${ymd}`,
          title: `Receita prevista: ${tx.description}`,
          body: `Previsão de recebimento em ${shortPtDate(targetDay)} • Valor ${formatBrlCents(tx.amountCents)}.`,
          type: "expected_income",
          referenceId: tx.id,
          scheduledFor: targetDay,
        });
      }
    }
  }

  for (const inv of params.invoices) {
    const remaining = Math.max(0, inv.totalAmountCents - inv.paidAmountCents);
    if (inv.status === "paid" || remaining <= 0) continue;

    const dueDay = normalizeCalendarDate(inv.dueDate);
    const ymd = isoDateKey(dueDay);
    const cardName = params.cardNamesById[inv.cardId] ?? "Cartão de crédito";
    const refLabel = `${inv.referenceMonth.toString().padStart(2, "0")}/${inv.referenceYear}`;

    if (dueDay.getTime() < todayStart.getTime()) {
      alerts.push({
        id: `inv_overdue_${inv.id}_${ymd}`,
        title: `Fatura vencida • ${cardName}`,
        body: `Fatura ${refLabel} venceu em ${shortPtDate(dueDay)} • Restante ${formatBrlCents(remaining)}.`,
        type: "invoice_due",
        referenceId: inv.id,
        scheduledFor: dueDay,
      });
    } else if (dueDay.getTime() <= windowEnd.getTime()) {
      alerts.push({
        id: `inv_due_${inv.id}_${ymd}`,
        title: `Fatura próxima do vencimento • ${cardName}`,
        body: `Fatura ${refLabel} vence em ${shortPtDate(dueDay)} • Total ${formatBrlCents(remaining)}.`,
        type: "invoice_due",
        referenceId: inv.id,
        scheduledFor: dueDay,
      });
    }
  }

  for (const budget of params.budgets ?? []) {
    if (budget.limitCents <= 0) continue;
    const threshold = budget.alertThresholdPercent ?? 80;
    const pct = Math.round((budget.spentCents * 100) / budget.limitCents);
    const refLabel = `${budget.month.toString().padStart(2, "0")}/${budget.year}`;

    if (budget.spentCents > budget.limitCents) {
      alerts.push({
        id: `budget_over_${budget.id}_${budget.year}_${budget.month}`,
        title: `Orçamento ultrapassado: ${budget.categoryName}`,
        body: `Consumo de ${formatBrlCents(budget.spentCents)} sobre limite de ${formatBrlCents(budget.limitCents)} (${pct}%) em ${refLabel}.`,
        type: "budget_exceeded",
        referenceId: budget.id,
        scheduledFor: todayStart,
      });
    } else if (pct >= threshold) {
      alerts.push({
        id: `budget_warn_${budget.id}_${budget.year}_${budget.month}`,
        title: `Orçamento próximo do limite: ${budget.categoryName}`,
        body: `Você já utilizou ${pct}% (${formatBrlCents(budget.spentCents)} de ${formatBrlCents(budget.limitCents)}) em ${refLabel}.`,
        type: "budget_warning",
        referenceId: budget.id,
        scheduledFor: todayStart,
      });
    }
  }

  return alerts;
}
