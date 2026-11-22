import * as admin from "firebase-admin";
import {
  Content,
  GenerateContentConfig,
  GenerateContentResponse,
  GoogleGenAI,
  Schema,
  Type,
} from "@google/genai";
import { HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { formatBrtDateKey } from "./accounting_utils";
import {
  AI_FUNCTION_DECLARATIONS,
  CatalogAccount,
  CatalogCard,
  CatalogCategory,
  executeAiToolCall,
  FinancialCatalog,
  loadFinancialCatalog,
} from "./ai_financial_tools";

export const DEFAULT_GEMINI_MODEL =
  process.env.GEMINI_MODEL || "gemini-3.8-flash";

export const AI_RATE_LIMITS = {
  dailyLimit: 60,
  burstWindowSeconds: 300,
  burstLimit: 12,
  maxPromptChars: 2000,
  maxImageBase64Chars: 6 * 1024 * 1024,
  maxHistoryTurns: 8,
  maxToolRounds: 4,
};

export const ALLOWED_IMAGE_MIME_TYPES = new Set([
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
]);

export type AiIntentType =
  | "transaction_proposal"
  | "clarification_needed"
  | "analysis_answer";

export interface AiReceiptLineItem {
  description: string;
  amount_cents: number;
  category_suggestion: string | null;
  category_id: string | null;
}

export interface AiTransactionSuggestionPayload {
  success: boolean;
  transaction_type: string;
  description: string;
  amount_cents: number;
  currency: string;
  date: string;
  category_suggestion: string | null;
  category_id: string | null;
  category_is_new: boolean;
  payment_method: string | null;
  credit_card_name: string | null;
  credit_card_id: string | null;
  account_name: string | null;
  account_id: string | null;
  destination_account_name: string | null;
  destination_account_id: string | null;
  installments: number;
  frequency: string | null;
  confidence: number;
  requires_confirmation: true;
  missing_information: string[];
  ambiguous_accounts: string[];
  ambiguous_cards: string[];
  merchant_name: string | null;
  discount_cents: number | null;
  tax_cents: number | null;
  notes: string | null;
  extracted_items: AiReceiptLineItem[];
  potential_duplicate_warning: string | null;
}

export interface AiAssistantEnvelope {
  id: string;
  intent: AiIntentType;
  reply: string;
  model: string;
  tools_used: string[];
  requires_confirmation: true;
  suggestion: AiTransactionSuggestionPayload | null;
  quota: AiQuotaSnapshot;
}

export interface AiQuotaSnapshot {
  dailyLimit: number;
  dailyUsed: number;
  remainingToday: number;
  burstLimit: number;
  burstWindowSeconds: number;
}

export interface AiGatewayTurnParams {
  model: string;
  contents: Content[];
  config: GenerateContentConfig;
}

export interface AiModelGateway {
  generateContent(params: AiGatewayTurnParams): Promise<GenerateContentResponse>;
}

export class GoogleGenAiGateway implements AiModelGateway {
  private readonly apiKey?: string;
  private readonly project: string;
  private readonly primaryLocation: string;
  private readonly clientsByKey = new Map<string, GoogleGenAI>();
  public lastUsedModel: string = DEFAULT_GEMINI_MODEL;

  constructor(options?: {
    apiKey?: string;
    projectId?: string;
    location?: string;
  }) {
    const rawKey = options?.apiKey ?? process.env.GEMINI_API_KEY;
    this.apiKey = rawKey && rawKey.trim().length > 0 ? rawKey.trim() : undefined;

    let firebaseProject: string | undefined;
    try {
      const cfg = process.env.FIREBASE_CONFIG
        ? (JSON.parse(process.env.FIREBASE_CONFIG) as Record<string, unknown>)
        : null;
      if (typeof cfg?.projectId === "string" && cfg.projectId.length > 0) {
        firebaseProject = cfg.projectId;
      }
    } catch {
      firebaseProject = undefined;
    }

    this.project =
      options?.projectId ||
      process.env.GOOGLE_CLOUD_PROJECT ||
      process.env.GCLOUD_PROJECT ||
      firebaseProject ||
      "finance-control-luizmgms";

    // Modelos Gemini 3.x / 4.x no Vertex AI utilizam o endpoint global por padrão.
    this.primaryLocation =
      options?.location || process.env.VERTEX_AI_LOCATION || "global";
  }

  private getClient(location: string): GoogleGenAI {
    const cacheKey = this.apiKey ? "apikey" : `vertex:${location}`;
    const cached = this.clientsByKey.get(cacheKey);
    if (cached) return cached;

    const created = this.apiKey
      ? new GoogleGenAI({ apiKey: this.apiKey })
      : new GoogleGenAI({
          vertexai: true,
          project: this.project,
          location,
        });
    this.clientsByKey.set(cacheKey, created);
    return created;
  }

  async generateContent(
    params: AiGatewayTurnParams,
  ): Promise<GenerateContentResponse> {
    const candidates: Array<{ model: string; location: string }> = this.apiKey
      ? [
          { model: params.model, location: "global" },
          { model: "gemini-3.5-flash", location: "global" },
          { model: "gemini-3.5-flash-lite", location: "global" },
          { model: "gemini-2.5-flash", location: "global" },
        ]
      : [
          { model: params.model, location: this.primaryLocation },
          { model: params.model, location: "us" },
          { model: "gemini-3.5-flash", location: "global" },
          { model: "gemini-3.5-flash-lite", location: "global" },
          { model: "gemini-2.5-flash", location: "global" },
          { model: "gemini-2.5-flash", location: "us-central1" },
        ];

    const seen = new Set<string>();
    let lastError: unknown;

    for (const candidate of candidates) {
      const key = `${candidate.model}@${candidate.location}`;
      if (seen.has(key)) continue;
      seen.add(key);

      try {
        const client = this.getClient(candidate.location);
        const response = await client.models.generateContent({
          model: candidate.model,
          contents: params.contents,
          config: params.config,
        });
        this.lastUsedModel = candidate.model;
        return response;
      } catch (err) {
        lastError = err;
        const status =
          typeof (err as { status?: unknown })?.status === "number"
            ? (err as { status: number }).status
            : undefined;
        // Só tenta modelo/região alternativa quando o modelo não existir naquele endpoint (404).
        if (status !== 404) {
          throw err;
        }
        logger.warn("Modelo/localização Gemini retornou 404, tentando alternativa", {
          model: candidate.model,
          location: candidate.location,
          errorMessage: err instanceof Error ? err.message : String(err),
        });
      }
    }

    throw lastError;
  }
}

const SUGGESTION_ITEM_SCHEMA: Schema = {
  type: Type.OBJECT,
  properties: {
    description: { type: Type.STRING },
    amount_cents: { type: Type.INTEGER },
    category_suggestion: { type: Type.STRING, nullable: true },
  },
  required: ["description", "amount_cents"],
};

const SUGGESTION_SCHEMA: Schema = {
  type: Type.OBJECT,
  nullable: true,
  properties: {
    success: { type: Type.BOOLEAN },
    transaction_type: {
      type: Type.STRING,
      enum: [
        "expense",
        "income",
        "card_purchase",
        "card_refund",
        "transfer",
        "invoice_payment",
        "recurring_expense",
        "recurring_income",
      ],
    },
    description: { type: Type.STRING },
    amount_cents: { type: Type.INTEGER },
    currency: { type: Type.STRING },
    date: { type: Type.STRING },
    category_suggestion: { type: Type.STRING, nullable: true },
    category_is_new: { type: Type.BOOLEAN, nullable: true },
    payment_method: {
      type: Type.STRING,
      nullable: true,
      enum: [
        "cash",
        "debit",
        "pix",
        "bank_transfer",
        "credit_card",
        "invoice_payment",
      ],
    },
    credit_card_name: { type: Type.STRING, nullable: true },
    account_name: { type: Type.STRING, nullable: true },
    destination_account_name: { type: Type.STRING, nullable: true },
    installments: { type: Type.INTEGER, nullable: true },
    frequency: { type: Type.STRING, nullable: true },
    confidence: { type: Type.NUMBER },
    requires_confirmation: { type: Type.BOOLEAN },
    missing_information: {
      type: Type.ARRAY,
      items: { type: Type.STRING },
    },
    merchant_name: { type: Type.STRING, nullable: true },
    discount_cents: { type: Type.INTEGER, nullable: true },
    tax_cents: { type: Type.INTEGER, nullable: true },
    notes: { type: Type.STRING, nullable: true },
    extracted_items: {
      type: Type.ARRAY,
      items: SUGGESTION_ITEM_SCHEMA,
    },
  },
  required: [
    "success",
    "transaction_type",
    "description",
    "amount_cents",
    "currency",
    "date",
    "confidence",
    "requires_confirmation",
    "missing_information",
  ],
};

export const AI_RESPONSE_SCHEMA: Schema = {
  type: Type.OBJECT,
  properties: {
    intent: {
      type: Type.STRING,
      enum: [
        "transaction_proposal",
        "clarification_needed",
        "analysis_answer",
      ],
    },
    reply: { type: Type.STRING },
    suggestion: SUGGESTION_SCHEMA,
  },
  required: ["intent", "reply"],
};

function normalizeText(raw: string): string {
  return raw
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim();
}

function matchCatalogEntities<T extends { id: string; name: string }>(
  queryName: string | null | undefined,
  entities: T[],
): { exact: T | null; matches: T[] } {
  const cleaned = (queryName ?? "").trim();
  if (!cleaned) return { exact: null, matches: [] };
  const target = normalizeText(cleaned);

  const exact = entities.find((item) => normalizeText(item.name) === target);
  if (exact) return { exact, matches: [exact] };

  const partial = entities.filter((item) => {
    const itemNorm = normalizeText(item.name);
    return itemNorm.includes(target) || target.includes(itemNorm);
  });

  if (partial.length === 1) {
    return { exact: partial[0], matches: partial };
  }
  return { exact: null, matches: partial };
}

function resolveCategoryMatch(
  categoryName: string | null | undefined,
  transactionType: string,
  categories: CatalogCategory[],
): { category: CatalogCategory | null; isNew: boolean } {
  const cleaned = (categoryName ?? "").trim();
  if (!cleaned) return { category: null, isNew: false };

  const expectedCatType =
    transactionType === "income" || transactionType === "recurring_income"
      ? "income"
      : "expense";

  const scoped = categories.filter((c) => c.type === expectedCatType);
  const directMatch = matchCatalogEntities(cleaned, scoped);
  if (directMatch.exact) {
    return { category: directMatch.exact, isNew: false };
  }
  const fallbackMatch = matchCatalogEntities(cleaned, categories);
  if (fallbackMatch.exact) {
    return { category: fallbackMatch.exact, isNew: false };
  }
  return { category: null, isNew: true };
}

export function extractJsonFromModelText(rawText: string): unknown {
  const trimmed = rawText.trim();
  if (!trimmed) return null;

  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fenced ? fenced[1].trim() : trimmed;

  try {
    return JSON.parse(candidate);
  } catch {
    const startIdx = candidate.indexOf("{");
    const endIdx = candidate.lastIndexOf("}");
    if (startIdx >= 0 && endIdx > startIdx) {
      try {
        return JSON.parse(candidate.slice(startIdx, endIdx + 1));
      } catch {
        return null;
      }
    }
    return null;
  }
}

const VALID_TRANSACTION_TYPES = new Set([
  "expense",
  "income",
  "card_purchase",
  "card_refund",
  "transfer",
  "invoice_payment",
  "recurring_expense",
  "recurring_income",
]);

/**
 * Valida, normaliza e protege o JSON retornado pelo modelo contra invenção de dados,
 * valores inválidos, ambiguidade de contas/cartões ou tentativa de auto-salvamento.
 */
export function validateAndNormalizeAiEnvelope(params: {
  rawJson: unknown;
  rawFallbackText?: string;
  catalog: FinancialCatalog;
  referenceDate: Date;
  model: string;
  toolsUsed: string[];
  quota: AiQuotaSnapshot;
  interactionId: string;
}): AiAssistantEnvelope {
  const {
    rawJson,
    rawFallbackText,
    catalog,
    referenceDate,
    model,
    toolsUsed,
    quota,
    interactionId,
  } = params;

  const todayIso = formatBrtDateKey(referenceDate);

  if (!rawJson || typeof rawJson !== "object") {
    const textReply =
      (rawFallbackText ?? "").trim() ||
      "Não foi possível interpretar completamente sua solicitação. Pode reformular com mais detalhes?";
    return {
      id: interactionId,
      intent: "analysis_answer",
      reply: textReply,
      model,
      tools_used: toolsUsed,
      requires_confirmation: true,
      suggestion: null,
      quota,
    };
  }

  const obj = rawJson as Record<string, unknown>;
  const rawIntent = typeof obj.intent === "string" ? obj.intent : "analysis_answer";
  let intent: AiIntentType =
    rawIntent === "transaction_proposal" ||
    rawIntent === "clarification_needed" ||
    rawIntent === "analysis_answer"
      ? rawIntent
      : "analysis_answer";

  let reply =
    typeof obj.reply === "string" && obj.reply.trim().length > 0
      ? obj.reply.trim()
      : "Analisei sua solicitação.";

  const rawSuggestion = obj.suggestion;
  if (!rawSuggestion || typeof rawSuggestion !== "object") {
    return {
      id: interactionId,
      intent: intent === "transaction_proposal" ? "clarification_needed" : intent,
      reply,
      model,
      tools_used: toolsUsed,
      requires_confirmation: true,
      suggestion: null,
      quota,
    };
  }

  const s = rawSuggestion as Record<string, unknown>;
  const rawType =
    typeof s.transaction_type === "string" ? s.transaction_type.trim() : "expense";
  const transactionType = VALID_TRANSACTION_TYPES.has(rawType)
    ? rawType
    : "expense";

  const description =
    typeof s.description === "string" && s.description.trim().length > 0
      ? s.description.trim().slice(0, 120)
      : "Movimentação identificada pela IA";

  const amountCentsRaw = Number(s.amount_cents ?? 0);
  const amountCents =
    Number.isFinite(amountCentsRaw) && amountCentsRaw > 0
      ? Math.round(amountCentsRaw)
      : 0;

  const rawDate = typeof s.date === "string" ? s.date.trim() : "";
  const validDate = /^\d{4}-\d{2}-\d{2}$/.test(rawDate) ? rawDate : todayIso;

  const missingInfo: string[] = Array.isArray(s.missing_information)
    ? s.missing_information
        .filter((item): item is string => typeof item === "string")
        .map((item) => item.trim())
        .filter((item) => item.length > 0)
    : [];

  if (amountCents <= 0 && !missingInfo.some((m) => /valor/i.test(m))) {
    missingInfo.push("Valor exato não identificado ou ilegível.");
  }
  if (rawDate.length === 0 || !/^\d{4}-\d{2}-\d{2}$/.test(rawDate)) {
    missingInfo.push(`Data assumida como hoje (${todayIso}); confirme ou ajuste.`);
  }

  const rawPaymentMethod =
    typeof s.payment_method === "string" ? s.payment_method.trim() : null;

  // Match categoria existente antes de sugerir nova categoria.
  const rawCategoryName =
    typeof s.category_suggestion === "string"
      ? s.category_suggestion.trim()
      : null;
  const catResolution = resolveCategoryMatch(
    rawCategoryName,
    transactionType,
    catalog.categories,
  );

  // Match conta financeira / destino.
  const rawAccountName =
    typeof s.account_name === "string" ? s.account_name.trim() : null;
  const accountMatch = matchCatalogEntities<CatalogAccount>(
    rawAccountName,
    catalog.accounts,
  );
  const ambiguousAccounts =
    accountMatch.matches.length > 1
      ? accountMatch.matches.map((a) => a.name)
      : [];
  if (ambiguousAccounts.length > 1) {
    missingInfo.push(
      `Mais de uma conta corresponde a "${rawAccountName}": ${ambiguousAccounts.join(", ")}. Escolha uma conta.`,
    );
  } else if (rawAccountName && !accountMatch.exact) {
    missingInfo.push(
      `Conta "${rawAccountName}" não encontrada nas contas ativas. Selecione uma conta cadastrada.`,
    );
  }

  const rawDestName =
    typeof s.destination_account_name === "string"
      ? s.destination_account_name.trim()
      : null;
  const destMatch = matchCatalogEntities<CatalogAccount>(
    rawDestName,
    catalog.accounts,
  );
  if (
    transactionType === "transfer" &&
    (!rawDestName || !destMatch.exact)
  ) {
    missingInfo.push("Selecione a conta de destino para a transferência.");
  }

  // Match cartão de crédito.
  const rawCardName =
    typeof s.credit_card_name === "string" ? s.credit_card_name.trim() : null;
  const cardMatch = matchCatalogEntities<CatalogCard>(
    rawCardName,
    catalog.cards,
  );
  const ambiguousCards =
    cardMatch.matches.length > 1 ? cardMatch.matches.map((c) => c.name) : [];
  if (ambiguousCards.length > 1) {
    missingInfo.push(
      `Mais de um cartão corresponde a "${rawCardName}": ${ambiguousCards.join(", ")}. Escolha qual cartão usar.`,
    );
  } else if (rawCardName && !cardMatch.exact) {
    missingInfo.push(
      `Cartão "${rawCardName}" não encontrado nos cartões ativos. Selecione o cartão correto.`,
    );
  } else if (
    (transactionType === "card_purchase" ||
      transactionType === "card_refund" ||
      transactionType === "invoice_payment") &&
    !cardMatch.exact
  ) {
    if (catalog.cards.length === 1) {
      // Apenas 1 cartão ativo não gera ambiguidade, mas ainda requer confirmação na tela.
    } else if (catalog.cards.length > 1) {
      missingInfo.push("Selecione qual cartão de crédito deve receber o lançamento.");
    }
  }

  const resolvedCard =
    cardMatch.exact ??
    ((transactionType === "card_purchase" ||
      transactionType === "card_refund" ||
      transactionType === "invoice_payment") &&
    catalog.cards.length === 1 &&
    !rawCardName
      ? catalog.cards[0]
      : null);

  const rawInstallments = Number(s.installments ?? 1);
  const installments =
    Number.isFinite(rawInstallments) && rawInstallments >= 1
      ? Math.min(Math.trunc(rawInstallments), 48)
      : 1;

  const rawConfidence = Number(s.confidence ?? 0);
  const confidence = Number.isFinite(rawConfidence)
    ? Math.min(Math.max(rawConfidence, 0), 1)
    : 0;

  const extractedItems: AiReceiptLineItem[] = [];
  if (Array.isArray(s.extracted_items)) {
    for (const rawItem of s.extracted_items) {
      if (!rawItem || typeof rawItem !== "object") continue;
      const itemObj = rawItem as Record<string, unknown>;
      const itemDesc =
        typeof itemObj.description === "string"
          ? itemObj.description.trim()
          : "";
      const itemCents = Math.round(Number(itemObj.amount_cents ?? 0));
      if (!itemDesc || !Number.isFinite(itemCents) || itemCents <= 0) continue;
      const itemCatRaw =
        typeof itemObj.category_suggestion === "string"
          ? itemObj.category_suggestion.trim()
          : rawCategoryName;
      const itemCatRes = resolveCategoryMatch(
        itemCatRaw,
        transactionType,
        catalog.categories,
      );
      extractedItems.push({
        description: itemDesc.slice(0, 120),
        amount_cents: itemCents,
        category_suggestion: itemCatRes.category?.name ?? itemCatRaw ?? null,
        category_id: itemCatRes.category?.id ?? null,
      });
    }
  }

  const isActionable = amountCents > 0 && s.success !== false;
  if (!isActionable) {
    intent = "clarification_needed";
  } else {
    intent = "transaction_proposal";
  }

  const normalizedSuggestion: AiTransactionSuggestionPayload = {
    success: isActionable,
    transaction_type: transactionType,
    description,
    amount_cents: amountCents,
    currency:
      typeof s.currency === "string" && s.currency.trim().length > 0
        ? s.currency.trim()
        : "BRL",
    date: validDate,
    category_suggestion:
      catResolution.category?.name ?? rawCategoryName ?? null,
    category_id: catResolution.category?.id ?? null,
    category_is_new: catResolution.isNew && Boolean(rawCategoryName),
    payment_method: rawPaymentMethod,
    credit_card_name: resolvedCard?.name ?? null,
    credit_card_id: resolvedCard?.id ?? null,
    account_name: accountMatch.exact?.name ?? null,
    account_id: accountMatch.exact?.id ?? null,
    destination_account_name: destMatch.exact?.name ?? null,
    destination_account_id: destMatch.exact?.id ?? null,
    installments,
    frequency:
      typeof s.frequency === "string" && s.frequency.trim().length > 0
        ? s.frequency.trim()
        : null,
    confidence,
    // Regra fundamental: nunca autoriza salvamento automático.
    requires_confirmation: true,
    missing_information: missingInfo,
    ambiguous_accounts: ambiguousAccounts,
    ambiguous_cards: ambiguousCards,
    merchant_name:
      typeof s.merchant_name === "string" && s.merchant_name.trim().length > 0
        ? s.merchant_name.trim()
        : null,
    discount_cents:
      typeof s.discount_cents === "number" && s.discount_cents > 0
        ? Math.round(s.discount_cents)
        : null,
    tax_cents:
      typeof s.tax_cents === "number" && s.tax_cents > 0
        ? Math.round(s.tax_cents)
        : null,
    notes:
      typeof s.notes === "string" && s.notes.trim().length > 0
        ? s.notes.trim().slice(0, 400)
        : null,
    extracted_items: extractedItems,
    potential_duplicate_warning: null,
  };

  if (missingInfo.length > 0 && isActionable) {
    reply = `${reply} Revise os pontos sinalizados antes de confirmar.`;
  }

  return {
    id: interactionId,
    intent,
    reply,
    model,
    tools_used: toolsUsed,
    requires_confirmation: true,
    suggestion: normalizedSuggestion,
    quota,
  };
}

function buildSystemInstruction(params: {
  catalog: FinancialCatalog;
  referenceDate: Date;
  allowFinancialContext: boolean;
  isReceiptMode: boolean;
}): string {
  const { catalog, referenceDate, allowFinancialContext, isReceiptMode } =
    params;
  const todayIso = formatBrtDateKey(referenceDate);

  const categoriesList =
    catalog.categories.length > 0
      ? catalog.categories.map((c) => `${c.name} (${c.type})`).join("; ")
      : "nenhuma cadastrada";

  const accountsList =
    catalog.accounts.length > 0
      ? catalog.accounts.map((a) => `${a.name} [${a.type}]`).join("; ")
      : "nenhuma cadastrada";

  const cardsList =
    catalog.cards.length > 0
      ? catalog.cards
          .map(
            (c) =>
              `${c.name} (${c.brand}, fecha dia ${c.closingDay}, vence dia ${c.dueDay})`,
          )
          .join("; ")
      : "nenhum cadastrado";

  const contextRule = allowFinancialContext
    ? "Para perguntas sobre gastos, saldos, cartões, faturas, orçamentos, parcelas ou recomendações, utilize EXCLUSIVAMENTE as ferramentas autorizadas de leitura (Function Calling). Se não houver dados suficientes após consultar as ferramentas, informe explicitamente."
    : "O usuário desativou o compartilhamento de dados financeiros históricos nas configurações de privacidade. Não invente dados e oriente o usuário a habilitar essa opção em Configurações caso faça perguntas analíticas.";

  const modeHint = isReceiptMode
    ? "Você está analisando uma imagem de documento financeiro (nota fiscal, cupom, comprovante PIX/cartão ou recibo). Se a imagem estiver borrada, cortada ou ilegível, defina intent='clarification_needed', success=false, amount_cents=0 e descreva em missing_information o que não pôde ser lido. Quando houver múltiplos itens legíveis, preencha extracted_items além do valor total."
    : "Identifique se o usuário deseja registrar uma movimentação (despesa, receita, compra no cartão, estorno no cartão, transferência, pagamento de fatura, recorrência) OU fazer uma pergunta/análise financeira.";

  return [
    "Você é o Assistente Financeiro IA do aplicativo Finance Control. Responda sempre em português (Brasil).",
    `Data atual (BRT): ${todayIso}. Dia inicial do mês contábil: dia ${catalog.monthStartDay}.`,
    modeHint,
    contextRule,
    `Categorias cadastradas pelo usuário: ${categoriesList}.`,
    `Contas ativas do usuário: ${accountsList}.`,
    `Cartões ativos do usuário: ${cardsList}.`,
    "REGRAS INVIOLÁVEIS:",
    "1. NUNCA salve, execute ou prometa salvar automaticamente uma movimentação; requires_confirmation deve ser sempre true.",
    "2. NUNCA invente valores, datas, contas bancárias ou cartões de crédito que não estejam no comando ou no catálogo acima.",
    "3. Converta valores monetários exatamente para centavos inteiros (amount_cents), ex: R$ 58,90 -> 5890.",
    "4. Diferencie sempre compra no cartão (transaction_type='card_purchase', payment_method='credit_card') de pagamento da fatura do cartão (transaction_type='invoice_payment', payment_method='invoice_payment').",
    "5. Para sugestões de lançamento, prefira exatamente os nomes de categorias, contas e cartões existentes do catálogo. Se nenhuma categoria existente servir, sugira o melhor nome e marque category_is_new=true. Se houver ambiguidade entre contas/cartões, preencha missing_information.",
    "6. Em propostas de lançamento (`intent: 'transaction_proposal'`), oriente o usuário na propriedade `reply` a revisar o cartão exibido abaixo e tocar no botão 'Confirmar e salvar' ou 'Editar', nunca dizendo para digitar 'confirmo' no chat.",
    "7. Responda em formato JSON válido seguindo a estrutura { intent, reply, suggestion }.",
  ].join("\n");
}

async function checkPotentialDuplicateInDb(params: {
  db: admin.firestore.Firestore;
  userId: string;
  suggestion: AiTransactionSuggestionPayload;
}): Promise<string | null> {
  const { db, userId, suggestion } = params;
  if (!suggestion.success || suggestion.amount_cents <= 0) return null;

  const targetDate = new Date(`${suggestion.date}T12:00:00Z`);
  if (Number.isNaN(targetDate.getTime())) return null;

  const minDate = new Date(targetDate.getTime() - 3 * 24 * 60 * 60 * 1000);
  const maxDate = new Date(targetDate.getTime() + 3 * 24 * 60 * 60 * 1000);

  const snap = await db
    .collection("users")
    .doc(userId)
    .collection("transactions")
    .where("competencyDate", ">=", admin.firestore.Timestamp.fromDate(minDate))
    .where("competencyDate", "<=", admin.firestore.Timestamp.fromDate(maxDate))
    .get();

  const normDesc = normalizeText(suggestion.description);
  const targetKind =
    suggestion.transaction_type === "recurring_expense"
      ? "expense"
      : suggestion.transaction_type === "recurring_income"
        ? "income"
        : suggestion.transaction_type;

  for (const doc of snap.docs) {
    const d = doc.data();
    const amount = Number(d.amountCents ?? 0);
    const kind = String(d.kind ?? "");
    const desc = normalizeText(String(d.description ?? ""));
    if (amount !== suggestion.amount_cents) continue;
    if (kind !== targetKind) continue;
    if (desc === normDesc || desc.includes(normDesc) || normDesc.includes(desc)) {
      const existingDate = d.competencyDate instanceof admin.firestore.Timestamp
        ? formatBrtDateKey(d.competencyDate.toDate())
        : suggestion.date;
      return `Possível duplicidade detectada: já existe "${String(d.description ?? "")}" no mesmo valor em ${existingDate}.`;
    }
  }

  return null;
}

/**
 * Lê e/ou consome atomicamente a cota e o limite de rajada do usuário em `users/{uid}/ai_usage/quota`.
 */
export async function checkAndConsumeAiQuota(params: {
  db: admin.firestore.Firestore;
  userId: string;
  referenceDate: Date;
  consume: boolean;
}): Promise<AiQuotaSnapshot> {
  const { db, userId, referenceDate, consume } = params;
  const quotaRef = db
    .collection("users")
    .doc(userId)
    .collection("ai_usage")
    .doc("quota");

  const dayKey = formatBrtDateKey(referenceDate);
  const windowBucket = Math.floor(
    referenceDate.getTime() / (AI_RATE_LIMITS.burstWindowSeconds * 1000),
  );

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(quotaRef);
    const d = snap.data() ?? {};

    const dailyUsed =
      String(d.dayKey ?? "") === dayKey ? Number(d.dailyCount ?? 0) : 0;
    const burstUsed =
      Number(d.windowBucket ?? -1) === windowBucket
        ? Number(d.windowCount ?? 0)
        : 0;

    if (consume) {
      if (dailyUsed >= AI_RATE_LIMITS.dailyLimit) {
        throw new HttpsError(
          "resource-exhausted",
          `Limite diário de ${AI_RATE_LIMITS.dailyLimit} consultas ao Assistente IA atingido. Tente novamente amanhã.`,
        );
      }
      if (burstUsed >= AI_RATE_LIMITS.burstLimit) {
        throw new HttpsError(
          "resource-exhausted",
          "Muitas solicitações em sequência. Aguarde alguns instantes antes de enviar novamente.",
        );
      }

      const nextDaily = dailyUsed + 1;
      const nextBurst = burstUsed + 1;

      tx.set(
        quotaRef,
        {
          dayKey,
          dailyCount: nextDaily,
          windowBucket,
          windowCount: nextBurst,
          totalRequests: Number(d.totalRequests ?? 0) + 1,
          updatedAt: admin.firestore.Timestamp.fromDate(referenceDate),
        },
        { merge: true },
      );

      return {
        dailyLimit: AI_RATE_LIMITS.dailyLimit,
        dailyUsed: nextDaily,
        remainingToday: Math.max(0, AI_RATE_LIMITS.dailyLimit - nextDaily),
        burstLimit: AI_RATE_LIMITS.burstLimit,
        burstWindowSeconds: AI_RATE_LIMITS.burstWindowSeconds,
      };
    }

    return {
      dailyLimit: AI_RATE_LIMITS.dailyLimit,
      dailyUsed,
      remainingToday: Math.max(0, AI_RATE_LIMITS.dailyLimit - dailyUsed),
      burstLimit: AI_RATE_LIMITS.burstLimit,
      burstWindowSeconds: AI_RATE_LIMITS.burstWindowSeconds,
    };
  });
}

function buildConversationHistoryContents(
  rawHistory: unknown,
): Content[] {
  if (!Array.isArray(rawHistory)) return [];
  const slice = rawHistory.slice(-AI_RATE_LIMITS.maxHistoryTurns);
  const contents: Content[] = [];
  for (const item of slice) {
    if (!item || typeof item !== "object") continue;
    const obj = item as Record<string, unknown>;
    const role = obj.role === "assistant" ? "model" : "user";
    const text =
      typeof obj.content === "string"
        ? obj.content.trim().slice(0, 1200)
        : "";
    if (!text) continue;
    contents.push({ role, parts: [{ text }] });
  }
  return contents;
}

/**
 * Orquestrador principal da Cloud Function `aiAssistantQuery`.
 */
export async function handleAiAssistantRequest(params: {
  db: admin.firestore.Firestore;
  uid: string;
  requestData: Record<string, unknown>;
  gateway?: AiModelGateway;
  referenceDate?: Date;
}): Promise<Record<string, unknown>> {
  const { db, uid, requestData, referenceDate = new Date() } = params;
  const gateway = params.gateway ?? new GoogleGenAiGateway();
  const startedAtMs = Date.now();

  if (!uid) {
    throw new HttpsError("unauthenticated", "Usuário não autenticado.");
  }

  const mode =
    typeof requestData.mode === "string" ? requestData.mode.trim() : "chat";

  const userRef = db.collection("users").doc(uid);
  const profileSnap = await userRef.collection("profile").doc("main").get();
  const profileData = profileSnap.data() ?? {};
  const aiAssistantEnabled =
    profileData.aiAssistantEnabled === undefined
      ? true
      : Boolean(profileData.aiAssistantEnabled);
  const aiShareFinancialContext =
    profileData.aiShareFinancialContext === undefined
      ? true
      : Boolean(profileData.aiShareFinancialContext);

  if (mode === "status") {
    const quota = await checkAndConsumeAiQuota({
      db,
      userId: uid,
      referenceDate,
      consume: false,
    });
    return {
      quota,
      privacy: {
        aiAssistantEnabled,
        aiShareFinancialContext,
      },
      model: DEFAULT_GEMINI_MODEL,
    };
  }

  if (!aiAssistantEnabled) {
    throw new HttpsError(
      "failed-precondition",
      "O Assistente Financeiro IA está desativado nas configurações de privacidade.",
    );
  }

  if (mode !== "chat" && mode !== "receipt_image") {
    throw new HttpsError("invalid-argument", `Modo não suportado: ${mode}`);
  }

  const promptText =
    typeof requestData.prompt === "string" ? requestData.prompt.trim() : "";
  if (mode === "chat" && promptText.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "Informe uma mensagem ou transcrição para enviar ao assistente.",
    );
  }
  if (promptText.length > AI_RATE_LIMITS.maxPromptChars) {
    throw new HttpsError(
      "invalid-argument",
      `Mensagem excede o limite de ${AI_RATE_LIMITS.maxPromptChars} caracteres.`,
    );
  }

  let imageBase64 = "";
  let imageMimeType = "";
  if (mode === "receipt_image") {
    imageBase64 =
      typeof requestData.imageBase64 === "string"
        ? requestData.imageBase64.trim()
        : "";
    imageMimeType =
      typeof requestData.mimeType === "string"
        ? requestData.mimeType.trim().toLowerCase()
        : "";

    if (!imageBase64) {
      throw new HttpsError(
        "invalid-argument",
        "Nenhuma imagem enviada para análise.",
      );
    }
    if (imageBase64.length > AI_RATE_LIMITS.maxImageBase64Chars) {
      throw new HttpsError(
        "invalid-argument",
        "Imagem muito grande. Envie uma imagem de até 4,5 MB.",
      );
    }
    if (!ALLOWED_IMAGE_MIME_TYPES.has(imageMimeType)) {
      throw new HttpsError(
        "invalid-argument",
        "Formato de imagem não suportado. Utilize JPG, PNG ou WEBP.",
      );
    }
  }

  // Consumo atômico da cota antes de invocar o Gemini (proteção contra abuso/custos).
  const quota = await checkAndConsumeAiQuota({
    db,
    userId: uid,
    referenceDate,
    consume: true,
  });

  const catalog = await loadFinancialCatalog(db, uid);
  const systemInstruction = buildSystemInstruction({
    catalog,
    referenceDate,
    allowFinancialContext: aiShareFinancialContext,
    isReceiptMode: mode === "receipt_image",
  });

  const toolsUsed: string[] = [];
  const contents: Content[] = buildConversationHistoryContents(
    requestData.history,
  );

  if (mode === "receipt_image") {
    const caption =
      promptText ||
      "Analise esta imagem de comprovante/nota fiscal, extraia os dados financeiros e respeite as regras de não invenção.";
    contents.push({
      role: "user",
      parts: [
        { text: caption },
        {
          inlineData: {
            mimeType: imageMimeType,
            data: imageBase64,
          },
        },
      ],
    });
  } else {
    contents.push({
      role: "user",
      parts: [{ text: promptText }],
    });
  }

  let finalModelText = "";
  let totalTokens = 0;

  try {
    if (mode === "receipt_image" || !aiShareFinancialContext) {
      const response = await gateway.generateContent({
        model: DEFAULT_GEMINI_MODEL,
        contents,
        config: {
          systemInstruction,
          temperature: 0.15,
          responseMimeType: "application/json",
          responseSchema: AI_RESPONSE_SCHEMA,
        },
      });
      finalModelText = response.text ?? "";
      totalTokens += response.usageMetadata?.totalTokenCount ?? 0;
    } else {
      // Loop controlado de Function Calling para consultas e cálculos reais.
      const workingContents = [...contents];
      for (let round = 0; round <= AI_RATE_LIMITS.maxToolRounds; round++) {
        const response = await gateway.generateContent({
          model: DEFAULT_GEMINI_MODEL,
          contents: workingContents,
          config: {
            systemInstruction,
            temperature: 0.2,
            tools: [{ functionDeclarations: AI_FUNCTION_DECLARATIONS }],
          },
        });
        totalTokens += response.usageMetadata?.totalTokenCount ?? 0;

        const calls = response.functionCalls ?? [];
        if (calls.length === 0 || round === AI_RATE_LIMITS.maxToolRounds) {
          finalModelText = response.text ?? "";
          break;
        }

        const modelContent = response.candidates?.[0]?.content;
        if (modelContent) {
          workingContents.push(modelContent);
        }

        const responseParts = [];
        for (const call of calls) {
          const toolName = call.name ?? "";
          if (!toolName) continue;
          toolsUsed.push(toolName);
          const result = await executeAiToolCall({
            db,
            userId: uid,
            catalog,
            toolName,
            args: (call.args as Record<string, unknown>) ?? {},
            referenceDate,
          });
          responseParts.push({
            functionResponse: {
              name: toolName,
              response: result,
            },
          });
        }

        workingContents.push({
          role: "user",
          parts: responseParts,
        });
      }

      // Se a resposta após Function Calling não veio em JSON limpo mas aparenta ser
      // uma proposta estruturada ou ambiguidade JSON quebrada, tenta estruturar sem ferramentas.
      const parsedAttempt = extractJsonFromModelText(finalModelText);
      if (!parsedAttempt && finalModelText.trim().startsWith("{")) {
        const structuredResp = await gateway.generateContent({
          model: DEFAULT_GEMINI_MODEL,
          contents: [
            {
              role: "user",
              parts: [
                {
                  text: `Converta exatamente o seguinte rascunho em JSON válido segundo o schema:\n\n${finalModelText}`,
                },
              ],
            },
          ],
          config: {
            systemInstruction,
            temperature: 0,
            responseMimeType: "application/json",
            responseSchema: AI_RESPONSE_SCHEMA,
          },
        });
        finalModelText = structuredResp.text ?? finalModelText;
        totalTokens += structuredResp.usageMetadata?.totalTokenCount ?? 0;
      }
    }
  } catch (error) {
    const errObj = error as { status?: unknown; code?: unknown };
    const errorStatus =
      typeof errObj?.status === "number" ? errObj.status : undefined;
    const errorMessage =
      error instanceof Error ? error.message : String(error);

    logger.error("Erro na invocação Gemini", {
      uid,
      mode,
      errorStatus,
      errorMessage,
    });
    await userRef.collection("ai_interactions").add({
      mode,
      model:
        gateway instanceof GoogleGenAiGateway
          ? gateway.lastUsedModel
          : DEFAULT_GEMINI_MODEL,
      status: "error",
      errorStatus: errorStatus ?? null,
      errorDetail: errorMessage.slice(0, 240),
      toolsUsed,
      latencyMs: Date.now() - startedAtMs,
      createdAt: admin.firestore.Timestamp.fromDate(referenceDate),
    });

    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError(
      "unavailable",
      "O serviço de IA Gemini não pôde processar a solicitação neste momento. Verifique a configuração da API no projeto ou tente novamente.",
    );
  }

  const parsedJson = extractJsonFromModelText(finalModelText);
  const interactionRef = userRef.collection("ai_interactions").doc();
  const resolvedModel =
    gateway instanceof GoogleGenAiGateway
      ? gateway.lastUsedModel
      : DEFAULT_GEMINI_MODEL;

  const envelope = validateAndNormalizeAiEnvelope({
    rawJson: parsedJson,
    rawFallbackText: finalModelText,
    catalog,
    referenceDate,
    model: resolvedModel,
    toolsUsed: Array.from(new Set(toolsUsed)),
    quota,
    interactionId: interactionRef.id,
  });

  if (envelope.suggestion && envelope.suggestion.success) {
    const dupWarning = await checkPotentialDuplicateInDb({
      db,
      userId: uid,
      suggestion: envelope.suggestion,
    });
    if (dupWarning) {
      envelope.suggestion.potential_duplicate_warning = dupWarning;
    }
  }

  // Registro de auditoria sem armazenar bytes brutos da imagem do usuário.
  await interactionRef.set({
    mode,
    intent: envelope.intent,
    model: resolvedModel,
    status: "ok",
    promptPreview: promptText.slice(0, 160),
    replyPreview: envelope.reply.slice(0, 240),
    hasSuggestion: Boolean(envelope.suggestion),
    toolsUsed: envelope.tools_used,
    totalTokens,
    latencyMs: Date.now() - startedAtMs,
    createdAt: admin.firestore.Timestamp.fromDate(referenceDate),
  });

  return envelope as unknown as Record<string, unknown>;
}
