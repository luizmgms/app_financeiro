import { test } from "node:test";
import * as assert from "node:assert/strict";
import {
  computeOccurrencesInWindow,
  evaluateNotificationCandidates,
  makeCalendarDate,
  RecurringRuleRecord,
  resolveInvoiceTarget,
} from "../src/schedule_utils";

test("computeOccurrencesInWindow mantém dia âncora 31 sem deriva e é idempotente", () => {
  const rule: RecurringRuleRecord = {
    id: "rec_aluguel",
    description: "Aluguel",
    kind: "expense",
    amountCents: 200000,
    isVariableAmount: false,
    categoryId: "cat_housing",
    accountId: "acc_1",
    frequency: "monthly",
    startDate: makeCalendarDate(2026, 1, 31),
    status: "active",
    skippedOccurrenceKeys: ["rec_aluguel_2026-02-28"],
  };

  const occurrences = computeOccurrencesInWindow(
    rule,
    makeCalendarDate(2026, 1, 15),
  );

  assert.deepEqual(
    occurrences.map((item) => item.dateKey),
    ["2026-01-31", "2026-03-31"],
  );
  assert.equal(occurrences[0].transactionDocId, "rec_rec_aluguel_2026-01-31");
  assert.equal(occurrences[1].transactionDocId, "rec_rec_aluguel_2026-03-31");
});

test("resolveInvoiceTarget alinha exatamente com a regra de fechamento do cartão", () => {
  const beforeClosing = resolveInvoiceTarget(
    "card_1",
    makeCalendarDate(2026, 11, 9),
    10,
    17,
  );
  assert.equal(beforeClosing.invoiceId, "card_1_2026_11");

  const onClosing = resolveInvoiceTarget(
    "card_1",
    makeCalendarDate(2026, 11, 10),
    10,
    17,
  );
  assert.equal(onClosing.invoiceId, "card_1_2026_12");
});

test("evaluateNotificationCandidates respeita antecedência configurada e ignora quitadas", () => {
  const refDate = makeCalendarDate(2026, 11, 18);
  const candidates = evaluateNotificationCandidates({
    transactions: [
      {
        id: "tx_overdue",
        kind: "expense",
        description: "Internet",
        amountCents: 12000,
        status: "pending",
        competencyDate: makeCalendarDate(2026, 11, 15),
        dueDate: makeCalendarDate(2026, 11, 15),
      },
      {
        id: "tx_soon",
        kind: "expense",
        description: "Energia",
        amountCents: 21050,
        status: "pending",
        competencyDate: makeCalendarDate(2026, 11, 20),
        dueDate: makeCalendarDate(2026, 11, 20),
      },
      {
        id: "tx_far",
        kind: "expense",
        description: "Condomínio",
        amountCents: 45000,
        status: "pending",
        competencyDate: makeCalendarDate(2026, 11, 25),
        dueDate: makeCalendarDate(2026, 11, 25),
      },
      {
        id: "tx_paid",
        kind: "expense",
        description: "Água",
        amountCents: 9000,
        status: "paid",
        competencyDate: makeCalendarDate(2026, 11, 19),
        dueDate: makeCalendarDate(2026, 11, 19),
      },
      {
        id: "tx_income",
        kind: "income",
        description: "Freela",
        amountCents: 350000,
        status: "pending",
        competencyDate: makeCalendarDate(2026, 11, 21),
        dueDate: makeCalendarDate(2026, 11, 21),
      },
    ],
    invoices: [
      {
        id: "card_1_2026_11",
        cardId: "card_1",
        referenceYear: 2026,
        referenceMonth: 11,
        dueDate: makeCalendarDate(2026, 11, 20),
        totalAmountCents: 100000,
        paidAmountCents: 0,
        status: "closed",
      },
    ],
    cardNamesById: { card_1: "Nubank" },
    reminderDaysBefore: 3,
    notificationsEnabled: true,
    referenceDate: refDate,
  });

  assert.deepEqual(
    candidates.map((c) => c.id),
    [
      "overdue_tx_overdue_2026-11-15",
      "due_soon_tx_soon_2026-11-20",
      "income_tx_income_2026-11-21",
      "inv_due_card_1_2026_11_2026-11-20",
    ],
  );
});
