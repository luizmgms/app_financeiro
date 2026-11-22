import { test } from "node:test";
import * as assert from "node:assert/strict";
import { GenerateContentResponse } from "@google/genai";
import {
  getAccountingMonthWindow,
  resolveAccountingYearMonth,
} from "../src/accounting_utils";
import {
  AiGatewayTurnParams,
  AiModelGateway,
  AI_RATE_LIMITS,
  extractJsonFromModelText,
  handleAiAssistantRequest,
  validateAndNormalizeAiEnvelope,
} from "../src/ai_assistant";
import {
  aggregatePeriodTotals,
  computeCategorySpending,
  detectDuplicateTransactions,
  FinancialCatalog,
} from "../src/ai_financial_tools";

const SAMPLE_CATALOG: FinancialCatalog = {
  monthStartDay: 1,
  categories: [
    { id: "cat_food", name: "Alimentação", type: "expense" },
    { id: "cat_salary", name: "Salário", type: "income" },
    { id: "cat_transport", name: "Transporte", type: "expense" },
  ],
  accounts: [
    {
      id: "acc_chk",
      name: "Conta Corrente",
      institution: "Banco do Brasil",
      type: "checking",
      currentBalanceCents: 250000,
    },
    {
      id: "acc_sav",
      name: "Conta Poupança",
      institution: "Caixa",
      type: "savings",
      currentBalanceCents: 500000,
    },
  ],
  cards: [
    {
      id: "card_nu",
      name: "Nubank",
      institution: "Nubank",
      brand: "mastercard",
      closingDay: 5,
      dueDay: 12,
      totalLimitCents: 600000,
      usedLimitCents: 120000,
      defaultInstallments: 1,
    },
  ],
};

test("resolveAccountingYearMonth e janela BRT respeitam monthStartDay", () => {
  // Dia 10/11 antes do início do ciclo dia 15 -> pertence ao ciclo 10/2026
  const ref = new Date(Date.UTC(2026, 10, 10, 15, 0, 0));
  const cycle = resolveAccountingYearMonth(ref, 15);
  assert.deepEqual(cycle, { year: 2026, month: 10 });

  const win = getAccountingMonthWindow(cycle.year, cycle.month, 15);
  assert.equal(win.startIso, "2026-10-15");
  assert.equal(win.endIso, "2026-11-14");
});

test("aggregatePeriodTotals e computeCategorySpending não duplicam fatura/transferência e descontam estorno", () => {
  const txs = [
    {
      id: "t1",
      kind: "income",
      description: "Salário",
      amountCents: 500000,
      categoryId: "cat_salary",
      accountId: "acc_chk",
      cardId: null,
      status: "received",
      competencyDate: new Date("2026-11-05T12:00:00Z"),
      dueDate: null,
      installmentPlanId: null,
      installmentNumber: null,
      totalInstallments: null,
      recurringId: null,
    },
    {
      id: "t2",
      kind: "card_purchase",
      description: "Supermercado",
      amountCents: 35000,
      categoryId: "cat_food",
      accountId: null,
      cardId: "card_nu",
      status: "pending",
      competencyDate: new Date("2026-11-08T12:00:00Z"),
      dueDate: null,
      installmentPlanId: null,
      installmentNumber: null,
      totalInstallments: null,
      recurringId: null,
    },
    {
      id: "t3",
      kind: "card_refund",
      description: "Estorno mercado",
      amountCents: 5000,
      categoryId: "cat_food",
      accountId: null,
      cardId: "card_nu",
      status: "completed",
      competencyDate: new Date("2026-11-09T12:00:00Z"),
      dueDate: null,
      installmentPlanId: null,
      installmentNumber: null,
      totalInstallments: null,
      recurringId: null,
    },
    {
      id: "t4",
      kind: "invoice_payment",
      description: "Pagamento fatura Nubank",
      amountCents: 30000,
      categoryId: null,
      accountId: "acc_chk",
      cardId: "card_nu",
      status: "paid",
      competencyDate: new Date("2026-11-12T12:00:00Z"),
      dueDate: null,
      installmentPlanId: null,
      installmentNumber: null,
      totalInstallments: null,
      recurringId: null,
    },
    {
      id: "t5",
      kind: "transfer",
      description: "Transferência poupança",
      amountCents: 100000,
      categoryId: null,
      accountId: "acc_chk",
      cardId: null,
      status: "completed",
      competencyDate: new Date("2026-11-12T12:00:00Z"),
      dueDate: null,
      installmentPlanId: null,
      installmentNumber: null,
      totalInstallments: null,
      recurringId: null,
    },
  ];

  const totals = aggregatePeriodTotals(txs);
  assert.equal(totals.incomeCents, 500000);
  assert.equal(totals.expenseCents, 30000);
  assert.equal(totals.netResultCents, 470000);

  const catMap = new Map(SAMPLE_CATALOG.categories.map((c) => [c.id, c]));
  const cats = computeCategorySpending(txs, catMap);
  assert.equal(cats.length, 1);
  assert.equal(cats[0].spentCents, 30000);
});

test("detectDuplicateTransactions sinaliza lançamentos repetidos próximos", () => {
  const dups = detectDuplicateTransactions([
    {
      id: "a",
      kind: "expense",
      description: "Internet Fibra",
      amountCents: 8990,
      categoryId: "cat_food",
      accountId: "acc_chk",
      cardId: null,
      status: "paid",
      competencyDate: new Date("2026-11-17T12:00:00Z"),
      dueDate: null,
      installmentPlanId: null,
      installmentNumber: null,
      totalInstallments: null,
      recurringId: null,
    },
    {
      id: "b",
      kind: "expense",
      description: "Internet Fibra",
      amountCents: 8990,
      categoryId: "cat_food",
      accountId: "acc_chk",
      cardId: null,
      status: "paid",
      competencyDate: new Date("2026-11-18T12:00:00Z"),
      dueDate: null,
      installmentPlanId: null,
      installmentNumber: null,
      totalInstallments: null,
      recurringId: null,
    },
  ]);
  assert.equal(dups.length, 1);
  assert.equal(dups[0].amountCents, 8990);
});

test("validateAndNormalizeAiEnvelope resolve entidades, força requires_confirmation e extrai itens", () => {
  const raw = extractJsonFromModelText(`\`\`\`json
  {
    "intent": "transaction_proposal",
    "reply": "Identifiquei sua compra no cartão Nubank em 3x.",
    "suggestion": {
      "success": true,
      "transaction_type": "card_purchase",
      "description": "Compra no supermercado",
      "amount_cents": 35000,
      "currency": "BRL",
      "date": "2026-11-22",
      "category_suggestion": "alimentacao",
      "payment_method": "credit_card",
      "credit_card_name": "Nubank",
      "installments": 3,
      "confidence": 0.94,
      "requires_confirmation": false,
      "missing_information": [],
      "extracted_items": [
        { "description": "Hortifruti", "amount_cents": 15000, "category_suggestion": "Alimentação" },
        { "description": "Mercearia", "amount_cents": 20000, "category_suggestion": "Alimentação" }
      ]
    }
  }
  \`\`\``);

  const normalized = validateAndNormalizeAiEnvelope({
    rawJson: raw,
    catalog: SAMPLE_CATALOG,
    referenceDate: new Date("2026-11-22T15:00:00Z"),
    model: "gemini-3.8-flash",
    toolsUsed: [],
    quota: {
      dailyLimit: 60,
      dailyUsed: 1,
      remainingToday: 59,
      burstLimit: 12,
      burstWindowSeconds: 300,
    },
    interactionId: "int_1",
  });

  assert.equal(normalized.intent, "transaction_proposal");
  assert.equal(normalized.requires_confirmation, true);
  assert.ok(normalized.suggestion);
  assert.equal(normalized.suggestion.requires_confirmation, true);
  assert.equal(normalized.suggestion.category_id, "cat_food");
  assert.equal(normalized.suggestion.credit_card_id, "card_nu");
  assert.equal(normalized.suggestion.installments, 3);
  assert.equal(normalized.suggestion.extracted_items.length, 2);
});

test("validateAndNormalizeAiEnvelope detecta ambiguidade de cartões e imagens sem valor legível", () => {
  const ambiguousCatalog: FinancialCatalog = {
    ...SAMPLE_CATALOG,
    cards: [
      ...SAMPLE_CATALOG.cards,
      {
        id: "card_nu_pj",
        name: "Nubank PJ",
        institution: "Nubank",
        brand: "mastercard",
        closingDay: 10,
        dueDay: 17,
        totalLimitCents: 900000,
        usedLimitCents: 0,
        defaultInstallments: 1,
      },
    ],
  };

  // Cartão "Nu" casa parcialmente com dois cartões distintos -> ambiguidade
  const partialCard = validateAndNormalizeAiEnvelope({
    rawJson: {
      intent: "transaction_proposal",
      reply: "Identifiquei a compra, confirme o cartão.",
      suggestion: {
        success: true,
        transaction_type: "card_purchase",
        description: "Farmácia",
        amount_cents: 5890,
        currency: "BRL",
        date: "2026-11-22",
        credit_card_name: "Nu",
        confidence: 0.88,
        requires_confirmation: true,
        missing_information: [],
      },
    },
    catalog: ambiguousCatalog,
    referenceDate: new Date("2026-11-22T15:00:00Z"),
    model: "gemini-3.8-flash",
    toolsUsed: [],
    quota: {
      dailyLimit: 60,
      dailyUsed: 1,
      remainingToday: 59,
      burstLimit: 12,
      burstWindowSeconds: 300,
    },
    interactionId: "int_2",
  });

  assert.equal(partialCard.suggestion?.credit_card_id, null);
  assert.equal(partialCard.suggestion?.ambiguous_cards.length, 2);
  assert.ok(
    partialCard.suggestion?.missing_information.some((m) =>
      m.includes("Mais de um cartão"),
    ),
  );

  // Nota ilegível (amount_cents = 0) nunca inventa valor e cai em clarification_needed
  const blurry = validateAndNormalizeAiEnvelope({
    rawJson: {
      intent: "transaction_proposal",
      reply: "Foto borrada, não foi possível ler o total.",
      suggestion: {
        success: false,
        transaction_type: "expense",
        description: "Cupom fiscal ilegível",
        amount_cents: 0,
        currency: "BRL",
        date: "2026-11-22",
        confidence: 0.1,
        requires_confirmation: true,
        missing_information: ["Imagem borrada sem valor total legível."],
      },
    },
    catalog: SAMPLE_CATALOG,
    referenceDate: new Date("2026-11-22T15:00:00Z"),
    model: "gemini-3.8-flash",
    toolsUsed: [],
    quota: {
      dailyLimit: 60,
      dailyUsed: 2,
      remainingToday: 58,
      burstLimit: 12,
      burstWindowSeconds: 300,
    },
    interactionId: "int_3",
  });

  assert.equal(blurry.intent, "clarification_needed");
  assert.equal(blurry.suggestion?.success, false);
  assert.equal(blurry.suggestion?.amount_cents, 0);
});

/** Mock em memória mínimo simulando Firestore Admin para testes do handler */
function createMockFirestore(initialDocs: Record<string, Record<string, unknown>>) {
  const store = new Map<string, Record<string, unknown>>(
    Object.entries(initialDocs),
  );
  let seq = 1;

  function makeSnap(docPath: string) {
    const data = store.get(docPath);
    const id = docPath.split("/").pop() ?? "";
    return {
      id,
      exists: data !== undefined,
      ref: { path: docPath },
      data: () => data,
    };
  }

  function makeQuery(colPath: string, filters: Array<{ field: string; op: string; val: unknown }> = []) {
    return {
      where(field: string, op: string, val: unknown) {
        return makeQuery(colPath, [...filters, { field, op, val }]);
      },
      async get() {
        const prefix = `${colPath}/`;
        const docs = Array.from(store.entries())
          .filter(([path]) => {
            if (!path.startsWith(prefix)) return false;
            const rest = path.slice(prefix.length);
            return !rest.includes("/");
          })
          .filter(([, d]) =>
            filters.every((f) => {
              const v = d[f.field];
              if (f.op === "==") return v === f.val;
              if (f.op === "in" && Array.isArray(f.val)) return f.val.includes(v);
              return true;
            }),
          )
          .map(([path]) => makeSnap(path));
        return {
          empty: docs.length === 0,
          size: docs.length,
          docs,
        };
      },
    };
  }

  function makeCollection(colPath: string): Record<string, unknown> {
    const baseQuery = makeQuery(colPath);
    return {
      ...baseQuery,
      doc(docId?: string) {
        const resolvedId = docId ?? `auto_${seq++}`;
        return makeDoc(`${colPath}/${resolvedId}`);
      },
      async add(payload: Record<string, unknown>) {
        const resolvedId = `auto_${seq++}`;
        const p = `${colPath}/${resolvedId}`;
        store.set(p, payload);
        return { id: resolvedId, path: p };
      },
    };
  }

  function makeDoc(docPath: string): Record<string, unknown> {
    return {
      id: docPath.split("/").pop() ?? "",
      path: docPath,
      async get() {
        return makeSnap(docPath);
      },
      async set(payload: Record<string, unknown>, options?: { merge?: boolean }) {
        if (options?.merge && store.has(docPath)) {
          store.set(docPath, { ...store.get(docPath), ...payload });
        } else {
          store.set(docPath, payload);
        }
      },
      collection(sub: string) {
        return makeCollection(`${docPath}/${sub}`);
      },
    };
  }

  return {
    store,
    db: {
      collection(name: string) {
        return makeCollection(name);
      },
      async runTransaction<T>(fn: (tx: Record<string, unknown>) => Promise<T>): Promise<T> {
        const tx = {
          async get(docRef: { path: string }) {
            return makeSnap(docRef.path);
          },
          set(
            docRef: { path: string },
            payload: Record<string, unknown>,
            options?: { merge?: boolean },
          ) {
            if (options?.merge && store.has(docRef.path)) {
              store.set(docRef.path, { ...store.get(docRef.path), ...payload });
            } else {
              store.set(docRef.path, payload);
            }
          },
        };
        return fn(tx);
      },
    },
  };
}

test("handleAiAssistantRequest bloqueia usuário sem auth, IA desativada, rate limit e executa Function Calling", async () => {
  const { db, store } = createMockFirestore({
    "users/u1/profile/main": {
      monthStartDay: 1,
      aiAssistantEnabled: true,
      aiShareFinancialContext: true,
    },
    "users/u1/categories/c1": { name: "Alimentação", type: "expense", isActive: true },
    "users/u1/accounts/a1": {
      name: "Conta Principal",
      institution: "Itaú",
      type: "checking",
      currentBalanceCents: 300000,
      isActive: true,
    },
    "users/u1/credit_cards/k1": {
      name: "Nubank",
      institution: "Nubank",
      brand: "mastercard",
      closingDay: 5,
      dueDay: 12,
      totalLimitCents: 500000,
      usedLimitCents: 50000,
      defaultInstallments: 1,
      isActive: true,
    },
    "users/u_disabled/profile/main": {
      aiAssistantEnabled: false,
      aiShareFinancialContext: false,
    },
  });

  // 1. Sem autenticação
  await assert.rejects(
    () =>
      handleAiAssistantRequest({
        db: db as never,
        uid: "",
        requestData: { mode: "chat", prompt: "Oi" },
      }),
    /não autenticado/i,
  );

  // 2. Desativado nas configurações de privacidade
  await assert.rejects(
    () =>
      handleAiAssistantRequest({
        db: db as never,
        uid: "u_disabled",
        requestData: { mode: "chat", prompt: "Quanto gastei?" },
      }),
    /desativado nas configurações/i,
  );

  // 3. Fluxo com Function Calling (2 turnos)
  let callCount = 0;
  const mockGateway: AiModelGateway = {
    async generateContent(turn: AiGatewayTurnParams): Promise<GenerateContentResponse> {
      callCount++;
      assert.ok(turn.config.tools?.length);
      if (callCount === 1) {
        return {
          functionCalls: [
            {
              name: "get_credit_cards_status",
              args: {},
            },
          ],
          candidates: [
            {
              content: {
                role: "model",
                parts: [
                  {
                    functionCall: {
                      name: "get_credit_cards_status",
                      args: {},
                    },
                  },
                ],
              },
            },
          ],
          usageMetadata: { totalTokenCount: 100 },
        } as unknown as GenerateContentResponse;
      }
      return {
        text: JSON.stringify({
          intent: "analysis_answer",
          reply: "Seu cartão Nubank está com R$ 500,00 usados de R$ 5.000,00 (10%).",
          suggestion: null,
        }),
        usageMetadata: { totalTokenCount: 80 },
      } as unknown as GenerateContentResponse;
    },
  };

  const result = await handleAiAssistantRequest({
    db: db as never,
    uid: "u1",
    requestData: { mode: "chat", prompt: "Qual a utilização do meu cartão?" },
    gateway: mockGateway,
    referenceDate: new Date("2026-11-22T15:00:00Z"),
  });

  assert.equal(callCount, 2);
  assert.equal(result.intent, "analysis_answer");
  assert.deepEqual(result.tools_used, ["get_credit_cards_status"]);
  assert.equal((result.quota as { dailyUsed: number }).dailyUsed, 1);

  // 4. Rate limit diário atingido
  store.set("users/u1/ai_usage/quota", {
    dayKey: "2026-11-22",
    dailyCount: AI_RATE_LIMITS.dailyLimit,
    windowBucket: 1,
    windowCount: 1,
  });

  await assert.rejects(
    () =>
      handleAiAssistantRequest({
        db: db as never,
        uid: "u1",
        requestData: { mode: "chat", prompt: "Mais uma pergunta" },
        gateway: mockGateway,
        referenceDate: new Date("2026-11-22T15:00:00Z"),
      }),
    /Limite diário/i,
  );
});
