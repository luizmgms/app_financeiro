import * as admin from "firebase-admin";
import { FunctionDeclaration, Type } from "@google/genai";
import {
  formatBrtDateKey,
  getAccountingMonthWindow,
  resolveAccountingYearMonth,
} from "./accounting_utils";

export interface CatalogCategory {
  id: string;
  name: string;
  type: "income" | "expense";
}

export interface CatalogAccount {
  id: string;
  name: string;
  institution: string;
  type: string;
  currentBalanceCents: number;
}

export interface CatalogCard {
  id: string;
  name: string;
  institution: string;
  brand: string;
  closingDay: number;
  dueDay: number;
  totalLimitCents: number;
  usedLimitCents: number;
  defaultInstallments: number;
}

export interface FinancialCatalog {
  monthStartDay: number;
  categories: CatalogCategory[];
  accounts: CatalogAccount[];
  cards: CatalogCard[];
}

export interface ScopedTransactionRecord {
  id: string;
  kind: string;
  description: string;
  amountCents: number;
  categoryId: string | null;
  accountId: string | null;
  cardId: string | null;
  status: string;
  competencyDate: Date;
  dueDate: Date | null;
  installmentPlanId: string | null;
  installmentNumber: number | null;
  totalInstallments: number | null;
  recurringId: string | null;
}

export interface ScopedInvoiceRecord {
  id: string;
  cardId: string;
  referenceYear: number;
  referenceMonth: number;
  dueDate: Date;
  totalAmountCents: number;
  paidAmountCents: number;
  status: string;
}

export interface ScopedBudgetRecord {
  id: string;
  categoryId: string;
  year: number;
  month: number;
  limitCents: number;
  alertThresholdPercent: number;
}

export const AI_FUNCTION_DECLARATIONS: FunctionDeclaration[] = [
  {
    name: "get_monthly_summary",
    description:
      "Retorna o resumo financeiro do ciclo contábil solicitado (receitas, despesas incluindo compras no cartão descontados estornos, saldo total das contas, faturas em aberto e comparativo com o mês anterior). Não inclui transferências nem pagamento de fatura como despesa.",
    parameters: {
      type: Type.OBJECT,
      properties: {
        year: {
          type: Type.INTEGER,
          description: "Ano de referência (ex: 2026). Omita para usar o ciclo atual.",
        },
        month: {
          type: Type.INTEGER,
          description: "Mês de referência (1..12). Omita para usar o ciclo atual.",
        },
      },
    },
  },
  {
    name: "get_spending_by_category",
    description:
      "Retorna os gastos agrupados por categoria no mês de referência, percentual sobre o total e comparativo com o mês anterior. Permite filtrar opcionalmente pelo nome de uma categoria.",
    parameters: {
      type: Type.OBJECT,
      properties: {
        year: { type: Type.INTEGER },
        month: { type: Type.INTEGER },
        categoryName: {
          type: Type.STRING,
          description: "Nome parcial ou completo da categoria para filtro.",
        },
      },
    },
  },
  {
    name: "get_credit_cards_status",
    description:
      "Retorna os cartões de crédito ativos do usuário, limite total, utilizado, disponível, percentual de utilização e faturas abertas, fechadas ou em atraso.",
    parameters: {
      type: Type.OBJECT,
      properties: {},
    },
  },
  {
    name: "get_upcoming_bills_and_installments",
    description:
      "Retorna contas a pagar/receber pendentes ou em atraso nos próximos dias, faturas próximas do vencimento e total comprometido com parcelas futuras em aberto.",
    parameters: {
      type: Type.OBJECT,
      properties: {
        daysAhead: {
          type: Type.INTEGER,
          description: "Quantidade de dias à frente para filtrar vencimentos (padrão 30, máximo 90).",
        },
      },
    },
  },
  {
    name: "get_top_expenses_budgets_and_anomalies",
    description:
      "Retorna as maiores despesas do mês, metas de orçamento configuradas vs gasto real, recomendações de limites por categoria e possíveis lançamentos duplicados no período.",
    parameters: {
      type: Type.OBJECT,
      properties: {
        year: { type: Type.INTEGER },
        month: { type: Type.INTEGER },
        limit: {
          type: Type.INTEGER,
          description: "Número máximo de maiores despesas a listar (padrão 5, máx 15).",
        },
      },
    },
  },
];

function asDate(raw: unknown): Date {
  if (raw instanceof admin.firestore.Timestamp) return raw.toDate();
  if (raw instanceof Date) return raw;
  return new Date();
}

function asNullableDate(raw: unknown): Date | null {
  if (raw instanceof admin.firestore.Timestamp) return raw.toDate();
  if (raw instanceof Date) return raw;
  return null;
}

function normalizeText(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim();
}

function resolveTargetYearMonth(
  args: Record<string, unknown> | undefined,
  referenceDate: Date,
  monthStartDay: number,
): { year: number; month: number } {
  const active = resolveAccountingYearMonth(referenceDate, monthStartDay);
  const rawYear = typeof args?.year === "number" ? Math.trunc(args.year) : null;
  const rawMonth =
    typeof args?.month === "number" ? Math.trunc(args.month) : null;

  const year =
    rawYear !== null && rawYear >= 2000 && rawYear <= 2200
      ? rawYear
      : active.year;
  const month =
    rawMonth !== null && rawMonth >= 1 && rawMonth <= 12
      ? rawMonth
      : active.month;
  return { year, month };
}

function previousYearMonth(year: number, month: number): {
  year: number;
  month: number;
} {
  const prev = new Date(Date.UTC(year, month - 2, 1));
  return {
    year: prev.getUTCFullYear(),
    month: prev.getUTCMonth() + 1,
  };
}

/**
 * Soma receitas e despesas de um conjunto de transações respeitando as regras
 * do Finance Control (transferências e pagamento de fatura não entram como despesa).
 */
export function aggregatePeriodTotals(transactions: ScopedTransactionRecord[]): {
  incomeCents: number;
  expenseCents: number;
  cardPurchaseCents: number;
  cardRefundCents: number;
  netResultCents: number;
  transactionCount: number;
} {
  let incomeCents = 0;
  let directExpenseCents = 0;
  let cardPurchaseCents = 0;
  let cardRefundCents = 0;

  for (const tx of transactions) {
    switch (tx.kind) {
      case "income":
        incomeCents += tx.amountCents;
        break;
      case "expense":
        directExpenseCents += tx.amountCents;
        break;
      case "card_purchase":
        cardPurchaseCents += tx.amountCents;
        break;
      case "card_refund":
        cardRefundCents += tx.amountCents;
        break;
      default:
        break;
    }
  }

  const totalExpenseCents = Math.max(
    0,
    directExpenseCents + cardPurchaseCents - cardRefundCents,
  );

  return {
    incomeCents,
    expenseCents: totalExpenseCents,
    cardPurchaseCents,
    cardRefundCents,
    netResultCents: incomeCents - totalExpenseCents,
    transactionCount: transactions.length,
  };
}

/**
 * Agrupa despesas líquidas por categoria (expense + card_purchase - card_refund).
 */
export function computeCategorySpending(
  transactions: ScopedTransactionRecord[],
  categoriesById: Map<string, CatalogCategory>,
): Array<{
  categoryId: string;
  categoryName: string;
  spentCents: number;
}> {
  const totals = new Map<string, number>();

  for (const tx of transactions) {
    const catId = tx.categoryId || "__uncategorized__";
    if (tx.kind === "expense" || tx.kind === "card_purchase") {
      totals.set(catId, (totals.get(catId) ?? 0) + tx.amountCents);
    } else if (tx.kind === "card_refund") {
      totals.set(catId, (totals.get(catId) ?? 0) - tx.amountCents);
    }
  }

  const items: Array<{
    categoryId: string;
    categoryName: string;
    spentCents: number;
  }> = [];

  for (const [catId, amount] of totals.entries()) {
    if (amount <= 0) continue;
    const catName =
      catId === "__uncategorized__"
        ? "Sem categoria"
        : (categoriesById.get(catId)?.name ?? "Categoria removida");
    items.push({
      categoryId: catId,
      categoryName: catName,
      spentCents: amount,
    });
  }

  items.sort((a, b) => b.spentCents - a.spentCents);
  return items;
}

/**
 * Identifica possíveis lançamentos duplicados (mesmo valor, tipo e descrição normalizada em <= 2 dias).
 */
export function detectDuplicateTransactions(
  transactions: ScopedTransactionRecord[],
): Array<{
  description: string;
  amountCents: number;
  kind: string;
  dates: string[];
}> {
  const candidates: Array<{
    description: string;
    amountCents: number;
    kind: string;
    dates: string[];
  }> = [];

  const relevant = transactions.filter(
    (tx) =>
      (tx.kind === "expense" ||
        tx.kind === "card_purchase" ||
        tx.kind === "income") &&
      !tx.installmentPlanId &&
      !tx.recurringId,
  );

  const visited = new Set<string>();
  for (let i = 0; i < relevant.length; i++) {
    const a = relevant[i];
    if (visited.has(a.id)) continue;
    const normA = normalizeText(a.description);
    const group = [a];

    for (let j = i + 1; j < relevant.length; j++) {
      const b = relevant[j];
      if (visited.has(b.id)) continue;
      if (a.kind !== b.kind || a.amountCents !== b.amountCents) continue;
      const diffMs = Math.abs(
        a.competencyDate.getTime() - b.competencyDate.getTime(),
      );
      if (diffMs > 2 * 24 * 60 * 60 * 1000) continue;
      const normB = normalizeText(b.description);
      if (normA === normB || normA.includes(normB) || normB.includes(normA)) {
        group.push(b);
      }
    }

    if (group.length > 1) {
      for (const item of group) visited.add(item.id);
      candidates.push({
        description: a.description,
        amountCents: a.amountCents,
        kind: a.kind,
        dates: group.map((g) => formatBrtDateKey(g.competencyDate)),
      });
    }
  }

  return candidates;
}

/**
 * Carrega apenas o catálogo mínimo de metadados necessários para contexto e validação.
 */
export async function loadFinancialCatalog(
  db: admin.firestore.Firestore,
  userId: string,
): Promise<FinancialCatalog> {
  const userRef = db.collection("users").doc(userId);
  const [profileSnap, catsSnap, accountsSnap, cardsSnap] = await Promise.all([
    userRef.collection("profile").doc("main").get(),
    userRef.collection("categories").where("isActive", "==", true).get(),
    userRef.collection("accounts").where("isActive", "==", true).get(),
    userRef.collection("credit_cards").where("isActive", "==", true).get(),
  ]);

  const monthStartDay = Math.min(
    Math.max(Number(profileSnap.data()?.monthStartDay ?? 1), 1),
    28,
  );

  const categories: CatalogCategory[] = catsSnap.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      name: String(d.name ?? ""),
      type: d.type === "income" ? "income" : "expense",
    };
  });

  const accounts: CatalogAccount[] = accountsSnap.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      name: String(d.name ?? ""),
      institution: String(d.institution ?? ""),
      type: String(d.type ?? "checking"),
      currentBalanceCents: Number(d.currentBalanceCents ?? 0),
    };
  });

  const cards: CatalogCard[] = cardsSnap.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      name: String(d.name ?? ""),
      institution: String(d.institution ?? ""),
      brand: String(d.brand ?? "other"),
      closingDay: Number(d.closingDay ?? 5),
      dueDay: Number(d.dueDay ?? 12),
      totalLimitCents: Number(d.totalLimitCents ?? 0),
      usedLimitCents: Number(d.usedLimitCents ?? 0),
      defaultInstallments: Number(d.defaultInstallments ?? 1),
    };
  });

  return { monthStartDay, categories, accounts, cards };
}

async function fetchTransactionsInWindow(
  db: admin.firestore.Firestore,
  userId: string,
  start: Date,
  end: Date,
): Promise<ScopedTransactionRecord[]> {
  const snap = await db
    .collection("users")
    .doc(userId)
    .collection("transactions")
    .where("competencyDate", ">=", admin.firestore.Timestamp.fromDate(start))
    .where("competencyDate", "<=", admin.firestore.Timestamp.fromDate(end))
    .get();

  return snap.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      kind: String(d.kind ?? "expense"),
      description: String(d.description ?? ""),
      amountCents: Number(d.amountCents ?? 0),
      categoryId: d.categoryId ? String(d.categoryId) : null,
      accountId: d.accountId ? String(d.accountId) : null,
      cardId: d.cardId ? String(d.cardId) : null,
      status: String(d.status ?? "pending"),
      competencyDate: asDate(d.competencyDate),
      dueDate: asNullableDate(d.dueDate),
      installmentPlanId: d.installmentPlanId ? String(d.installmentPlanId) : null,
      installmentNumber:
        typeof d.installmentNumber === "number" ? d.installmentNumber : null,
      totalInstallments:
        typeof d.totalInstallments === "number" ? d.totalInstallments : null,
      recurringId: d.recurringId ? String(d.recurringId) : null,
    };
  });
}

/**
 * Executa exclusivamente ferramentas autorizadas de leitura sobre `users/{userId}`.
 */
export async function executeAiToolCall(params: {
  db: admin.firestore.Firestore;
  userId: string;
  catalog: FinancialCatalog;
  toolName: string;
  args: Record<string, unknown>;
  referenceDate: Date;
}): Promise<Record<string, unknown>> {
  const { db, userId, catalog, toolName, args, referenceDate } = params;
  const userRef = db.collection("users").doc(userId);
  const categoriesById = new Map(catalog.categories.map((c) => [c.id, c]));

  switch (toolName) {
    case "get_monthly_summary": {
      const target = resolveTargetYearMonth(
        args,
        referenceDate,
        catalog.monthStartDay,
      );
      const prev = previousYearMonth(target.year, target.month);
      const curWin = getAccountingMonthWindow(
        target.year,
        target.month,
        catalog.monthStartDay,
      );
      const prevWin = getAccountingMonthWindow(
        prev.year,
        prev.month,
        catalog.monthStartDay,
      );

      const [curTx, prevTx, openInvoicesSnap] = await Promise.all([
        fetchTransactionsInWindow(db, userId, curWin.start, curWin.end),
        fetchTransactionsInWindow(db, userId, prevWin.start, prevWin.end),
        userRef
          .collection("invoices")
          .where("status", "in", ["open", "closed", "overdue"])
          .get(),
      ]);

      const currentTotals = aggregatePeriodTotals(curTx);
      const previousTotals = aggregatePeriodTotals(prevTx);
      const totalAccountBalanceCents = catalog.accounts.reduce(
        (acc, item) => acc + item.currentBalanceCents,
        0,
      );
      const unpaidInvoicesCents = openInvoicesSnap.docs.reduce((acc, doc) => {
        const d = doc.data();
        const rem = Math.max(
          0,
          Number(d.totalAmountCents ?? 0) - Number(d.paidAmountCents ?? 0),
        );
        return acc + rem;
      }, 0);

      return {
        period: `${String(target.month).padStart(2, "0")}/${target.year}`,
        cycleRange: `${curWin.startIso} a ${curWin.endIso}`,
        currentMonth: currentTotals,
        previousMonth: {
          period: `${String(prev.month).padStart(2, "0")}/${prev.year}`,
          ...previousTotals,
        },
        expenseChangeCents:
          currentTotals.expenseCents - previousTotals.expenseCents,
        totalAvailableAccountBalanceCents: totalAccountBalanceCents,
        unpaidInvoicesCents,
        hasSufficientData:
          curTx.length > 0 || prevTx.length > 0 || catalog.accounts.length > 0,
      };
    }

    case "get_spending_by_category": {
      const target = resolveTargetYearMonth(
        args,
        referenceDate,
        catalog.monthStartDay,
      );
      const prev = previousYearMonth(target.year, target.month);
      const curWin = getAccountingMonthWindow(
        target.year,
        target.month,
        catalog.monthStartDay,
      );
      const prevWin = getAccountingMonthWindow(
        prev.year,
        prev.month,
        catalog.monthStartDay,
      );

      const [curTx, prevTx] = await Promise.all([
        fetchTransactionsInWindow(db, userId, curWin.start, curWin.end),
        fetchTransactionsInWindow(db, userId, prevWin.start, prevWin.end),
      ]);

      const curBreakdown = computeCategorySpending(curTx, categoriesById);
      const prevMap = new Map(
        computeCategorySpending(prevTx, categoriesById).map((c) => [
          c.categoryId,
          c.spentCents,
        ]),
      );
      const totalSpentCents = curBreakdown.reduce(
        (acc, c) => acc + c.spentCents,
        0,
      );
      const filterText =
        typeof args.categoryName === "string"
          ? normalizeText(args.categoryName)
          : "";

      const rows = curBreakdown
        .filter((item) =>
          filterText ? normalizeText(item.categoryName).includes(filterText) : true,
        )
        .map((item) => ({
          categoryName: item.categoryName,
          spentCents: item.spentCents,
          previousMonthSpentCents: prevMap.get(item.categoryId) ?? 0,
          deltaCents: item.spentCents - (prevMap.get(item.categoryId) ?? 0),
          sharePercent:
            totalSpentCents > 0
              ? Number(((item.spentCents / totalSpentCents) * 100).toFixed(1))
              : 0,
        }));

      return {
        period: `${String(target.month).padStart(2, "0")}/${target.year}`,
        totalSpentCents,
        categories: rows,
        hasSufficientData: rows.length > 0,
      };
    }

    case "get_credit_cards_status": {
      const invoicesSnap = await userRef
        .collection("invoices")
        .where("status", "in", ["open", "closed", "overdue"])
        .get();

      const cardsById = new Map(catalog.cards.map((c) => [c.id, c]));
      const cardsSummary = catalog.cards.map((card) => {
        const availableCents = Math.max(
          0,
          card.totalLimitCents - card.usedLimitCents,
        );
        const utilizationPercent =
          card.totalLimitCents > 0
            ? Number(((card.usedLimitCents / card.totalLimitCents) * 100).toFixed(1))
            : 0;
        return {
          name: card.name,
          institution: card.institution,
          brand: card.brand,
          totalLimitCents: card.totalLimitCents,
          usedLimitCents: card.usedLimitCents,
          availableLimitCents: availableCents,
          utilizationPercent,
          closingDay: card.closingDay,
          dueDay: card.dueDay,
        };
      });

      const unpaidInvoices = invoicesSnap.docs.map((doc) => {
        const d = doc.data();
        const total = Number(d.totalAmountCents ?? 0);
        const paid = Number(d.paidAmountCents ?? 0);
        return {
          cardName: cardsById.get(String(d.cardId ?? ""))?.name ?? "Cartão",
          reference: `${String(d.referenceMonth ?? 1).padStart(2, "0")}/${d.referenceYear ?? ""}`,
          dueDate: formatBrtDateKey(asDate(d.dueDate)),
          remainingCents: Math.max(0, total - paid),
          status: String(d.status ?? "open"),
        };
      });

      return {
        cards: cardsSummary,
        unpaidInvoices,
        hasSufficientData: cardsSummary.length > 0,
      };
    }

    case "get_upcoming_bills_and_installments": {
      const rawDays = typeof args.daysAhead === "number" ? args.daysAhead : 30;
      const daysAhead = Math.min(Math.max(Math.trunc(rawDays), 1), 90);
      const horizonEnd = new Date(
        referenceDate.getTime() + daysAhead * 24 * 60 * 60 * 1000,
      );

      const [pendingTxSnap, invoicesSnap] = await Promise.all([
        userRef
          .collection("transactions")
          .where("status", "in", ["pending", "overdue"])
          .get(),
        userRef
          .collection("invoices")
          .where("status", "in", ["open", "closed", "overdue"])
          .get(),
      ]);

      const cardsById = new Map(catalog.cards.map((c) => [c.id, c]));
      const bills: Array<{
        kind: string;
        description: string;
        amountCents: number;
        dueDate: string;
        status: string;
      }> = [];
      let futureInstallmentsCents = 0;
      let futureInstallmentCount = 0;

      for (const doc of pendingTxSnap.docs) {
        const d = doc.data();
        const kind = String(d.kind ?? "expense");
        const amountCents = Number(d.amountCents ?? 0);
        const dueDate = asNullableDate(d.dueDate) ?? asDate(d.competencyDate);

        if (d.installmentPlanId) {
          futureInstallmentCount += 1;
          futureInstallmentsCents += amountCents;
        }

        if (kind === "expense" || kind === "income") {
          if (dueDate.getTime() <= horizonEnd.getTime()) {
            bills.push({
              kind,
              description: String(d.description ?? ""),
              amountCents,
              dueDate: formatBrtDateKey(dueDate),
              status: String(d.status ?? "pending"),
            });
          }
        }
      }

      const invoicesDue = invoicesSnap.docs
        .map((doc) => {
          const d = doc.data();
          const remainingCents = Math.max(
            0,
            Number(d.totalAmountCents ?? 0) - Number(d.paidAmountCents ?? 0),
          );
          const dueDate = asDate(d.dueDate);
          return {
            cardName: cardsById.get(String(d.cardId ?? ""))?.name ?? "Cartão",
            remainingCents,
            dueDateObj: dueDate,
            dueDate: formatBrtDateKey(dueDate),
            status: String(d.status ?? "open"),
          };
        })
        .filter(
          (inv) =>
            inv.remainingCents > 0 &&
            inv.dueDateObj.getTime() <= horizonEnd.getTime(),
        )
        .map(({ dueDateObj: _ignored, ...rest }) => rest);

      bills.sort((a, b) => a.dueDate.localeCompare(b.dueDate));

      return {
        daysAhead,
        upcomingOrOverdueBills: bills.slice(0, 20),
        upcomingOrOverdueInvoices: invoicesDue,
        futureInstallments: {
          pendingInstallmentItemsCount: futureInstallmentCount,
          totalCommittedCents: futureInstallmentsCents,
        },
        hasSufficientData:
          bills.length > 0 || invoicesDue.length > 0 || futureInstallmentCount > 0,
      };
    }

    case "get_top_expenses_budgets_and_anomalies": {
      const target = resolveTargetYearMonth(
        args,
        referenceDate,
        catalog.monthStartDay,
      );
      const limit = Math.min(
        Math.max(typeof args.limit === "number" ? Math.trunc(args.limit) : 5, 1),
        15,
      );
      const curWin = getAccountingMonthWindow(
        target.year,
        target.month,
        catalog.monthStartDay,
      );

      const [curTx, budgetsSnap, recurringSnap] = await Promise.all([
        fetchTransactionsInWindow(db, userId, curWin.start, curWin.end),
        userRef.collection("budgets").where("year", "==", target.year).get(),
        userRef.collection("recurring").where("status", "==", "active").get(),
      ]);

      const expenseTxs = curTx
        .filter((tx) => tx.kind === "expense" || tx.kind === "card_purchase")
        .sort((a, b) => b.amountCents - a.amountCents)
        .slice(0, limit)
        .map((tx) => ({
          description: tx.description,
          amountCents: tx.amountCents,
          kind: tx.kind,
          categoryName: tx.categoryId
            ? (categoriesById.get(tx.categoryId)?.name ?? "Categoria")
            : "Sem categoria",
          date: formatBrtDateKey(tx.competencyDate),
        }));

      const categoryTotals = computeCategorySpending(curTx, categoriesById);
      const spentMap = new Map(
        categoryTotals.map((item) => [item.categoryId, item.spentCents]),
      );

      const budgets = budgetsSnap.docs
        .map((doc) => {
          const d = doc.data();
          return {
            id: doc.id,
            categoryId: String(d.categoryId ?? ""),
            year: Number(d.year ?? 0),
            month: Number(d.month ?? 0),
            limitCents: Number(d.limitCents ?? 0),
          };
        })
        .filter((b) => b.month === target.month)
        .map((b) => {
          const spentCents = spentMap.get(b.categoryId) ?? 0;
          const percentConsumed =
            b.limitCents > 0
              ? Number(((spentCents / b.limitCents) * 100).toFixed(1))
              : 0;
          return {
            categoryName:
              categoriesById.get(b.categoryId)?.name ?? "Categoria",
            limitCents: b.limitCents,
            spentCents,
            percentConsumed,
          };
        });

      const budgetedCategories = new Set(
        budgetsSnap.docs
          .filter((d) => Number(d.data().month ?? 0) === target.month)
          .map((d) => String(d.data().categoryId ?? "")),
      );
      const unbudgetedTopCategories = categoryTotals
        .filter((item) => !budgetedCategories.has(item.categoryId))
        .slice(0, 3)
        .map((item) => ({
          categoryName: item.categoryName,
          currentSpentCents: item.spentCents,
          suggestedLimitCents: Math.ceil((item.spentCents * 1.1) / 100) * 100,
        }));

      const activeRecurring = recurringSnap.docs.map((doc) => {
        const d = doc.data();
        return {
          description: String(d.description ?? ""),
          kind: String(d.kind ?? "expense"),
          amountCents: Number(d.amountCents ?? 0),
          frequency: String(d.frequency ?? "monthly"),
        };
      });

      const potentialDuplicates = detectDuplicateTransactions(curTx);

      return {
        period: `${String(target.month).padStart(2, "0")}/${target.year}`,
        topExpenses: expenseTxs,
        budgets,
        suggestedBudgetLimits: unbudgetedTopCategories,
        activeRecurringRules: activeRecurring,
        potentialDuplicates,
        hasSufficientData: curTx.length > 0 || budgets.length > 0,
      };
    }

    default:
      return { error: `Ferramenta desconhecida: ${toolName}` };
  }
}
