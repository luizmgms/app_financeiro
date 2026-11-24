import * as admin from "firebase-admin";
import { requiresAPI } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";
import {
  getAccountingMonthWindow,
  resolveAccountingYearMonth,
} from "./accounting_utils";
import { purgeUserAccountData } from "./account_cleanup";
import { handleAiAssistantRequest } from "./ai_assistant";
import {
  AlertCandidate,
  BudgetSnapshotInput,
  computeOccurrencesInWindow,
  evaluateNotificationCandidates,
  InvoiceSnapshotInput,
  RecurringFrequency,
  RecurringKind,
  RecurringRuleRecord,
  RecurringStatus,
  resolveInvoiceTarget,
  TransactionSnapshotInput,
} from "./schedule_utils";

requiresAPI(
  "aiplatform.googleapis.com",
  "Needed to query Vertex AI Gemini models for the Financial AI Assistant",
);

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const REGION = "us-central1";
const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === "true";

interface SyncStats {
  generatedOccurrences: number;
  createdAlerts: number;
  sentPushMessages: number;
}

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

async function syncUserAutomation(
  userId: string,
  referenceDate: Date,
): Promise<SyncStats> {
  const userRef = db.collection("users").doc(userId);
  const nowTs = admin.firestore.Timestamp.now();

  let generatedOccurrences = 0;

  // 1. Geração idempotente de recorrências ativas.
  const activeRulesSnap = await userRef
    .collection("recurring")
    .where("status", "==", "active")
    .get();

  for (const ruleDoc of activeRulesSnap.docs) {
    const d = ruleDoc.data();
    const rule: RecurringRuleRecord = {
      id: ruleDoc.id,
      description: String(d.description ?? ""),
      kind: (d.kind === "income" ? "income" : "expense") as RecurringKind,
      amountCents: Number(d.amountCents ?? 0),
      isVariableAmount: Boolean(d.isVariableAmount),
      categoryId: String(d.categoryId ?? ""),
      accountId: d.accountId ? String(d.accountId) : null,
      cardId: d.cardId ? String(d.cardId) : null,
      frequency: (d.frequency ?? "monthly") as RecurringFrequency,
      customIntervalDays:
        typeof d.customIntervalDays === "number" ? d.customIntervalDays : null,
      startDate: asDate(d.startDate),
      endDate: asNullableDate(d.endDate),
      status: (d.status ?? "active") as RecurringStatus,
      skippedOccurrenceKeys: Array.isArray(d.skippedOccurrenceKeys)
        ? d.skippedOccurrenceKeys.map(String)
        : [],
      notes: d.notes ? String(d.notes) : null,
    };

    const specs = computeOccurrencesInWindow(rule, referenceDate);
    if (specs.length === 0) continue;

    const addedCount = await db.runTransaction(async (tx) => {
      const freshRuleSnap = await tx.get(ruleDoc.ref);
      if (!freshRuleSnap.exists || freshRuleSnap.data()?.status !== "active") {
        return 0;
      }

      const missingSpecs = [];
      for (const spec of specs) {
        const txRef = userRef
          .collection("transactions")
          .doc(spec.transactionDocId);
        const txSnap = await tx.get(txRef);
        if (!txSnap.exists) {
          missingSpecs.push(spec);
        }
      }
      if (missingSpecs.length === 0) return 0;

      const isCardTarget = Boolean(rule.kind === "expense" && rule.cardId);

      if (isCardTarget && rule.cardId) {
        const cardRef = userRef.collection("credit_cards").doc(rule.cardId);
        const cardSnap = await tx.get(cardRef);
        if (!cardSnap.exists) return 0;
        const cardData = cardSnap.data() ?? {};
        const closingDay = Number(cardData.closingDay ?? 5);
        const dueDay = Number(cardData.dueDay ?? 12);
        const usedLimitCents = Number(cardData.usedLimitCents ?? 0);

        const cyclesByTx = new Map<
          string,
          ReturnType<typeof resolveInvoiceTarget>
        >();
        const uniqueInvoices = new Map<
          string,
          ReturnType<typeof resolveInvoiceTarget>
        >();
        for (const spec of missingSpecs) {
          const cycle = resolveInvoiceTarget(
            rule.cardId,
            spec.scheduledDate,
            closingDay,
            dueDay,
          );
          cyclesByTx.set(spec.transactionDocId, cycle);
          uniqueInvoices.set(cycle.invoiceId, cycle);
        }

        const invoiceSnaps = new Map<
          string,
          admin.firestore.DocumentSnapshot
        >();
        for (const invoiceId of uniqueInvoices.keys()) {
          const invRef = userRef.collection("invoices").doc(invoiceId);
          invoiceSnaps.set(invoiceId, await tx.get(invRef));
        }

        const addedByInvoice = new Map<string, number>();
        for (const spec of missingSpecs) {
          const cycle = cyclesByTx.get(spec.transactionDocId)!;
          const txRef = userRef
            .collection("transactions")
            .doc(spec.transactionDocId);
          tx.set(txRef, {
            kind: "card_purchase",
            description: rule.description,
            amountCents: rule.amountCents,
            categoryId: rule.categoryId,
            accountId: null,
            destinationAccountId: null,
            transferGroupId: null,
            transferDirection: null,
            competencyDate: admin.firestore.Timestamp.fromDate(
              spec.scheduledDate,
            ),
            dueDate: admin.firestore.Timestamp.fromDate(cycle.dueDate),
            paymentDate: null,
            status: "pending",
            notes: rule.notes ?? null,
            attachments: [],
            attachmentUrls: [],
            cardId: rule.cardId,
            invoiceId: cycle.invoiceId,
            installmentPlanId: null,
            installmentNumber: null,
            totalInstallments: null,
            recurringId: rule.id,
            occurrenceKey: spec.occurrenceKey,
            createdAt: nowTs,
            updatedAt: nowTs,
          });
          addedByInvoice.set(
            cycle.invoiceId,
            (addedByInvoice.get(cycle.invoiceId) ?? 0) + rule.amountCents,
          );
        }

        for (const [invoiceId, added] of addedByInvoice.entries()) {
          const invRef = userRef.collection("invoices").doc(invoiceId);
          const invSnap = invoiceSnaps.get(invoiceId);
          const cycle = uniqueInvoices.get(invoiceId)!;
          if (invSnap?.exists) {
            const currentTotal = Number(invSnap.data()?.totalAmountCents ?? 0);
            tx.update(invRef, {
              totalAmountCents: currentTotal + added,
              updatedAt: nowTs,
            });
          } else {
            tx.set(invRef, {
              cardId: rule.cardId,
              referenceYear: cycle.referenceYear,
              referenceMonth: cycle.referenceMonth,
              closingDate: admin.firestore.Timestamp.fromDate(
                cycle.closingDate,
              ),
              dueDate: admin.firestore.Timestamp.fromDate(cycle.dueDate),
              totalAmountCents: added,
              paidAmountCents: 0,
              status: "open",
              paymentTransactionId: null,
              paidAt: null,
              createdAt: nowTs,
              updatedAt: nowTs,
            });
          }
        }

        tx.update(cardRef, {
          usedLimitCents: usedLimitCents + rule.amountCents * missingSpecs.length,
          updatedAt: nowTs,
        });
      } else if (rule.accountId) {
        const accountRef = userRef.collection("accounts").doc(rule.accountId);
        const accountSnap = await tx.get(accountRef);
        if (!accountSnap.exists) return 0;

        for (const spec of missingSpecs) {
          const txRef = userRef
            .collection("transactions")
            .doc(spec.transactionDocId);
          tx.set(txRef, {
            kind: rule.kind,
            description: rule.description,
            amountCents: rule.amountCents,
            categoryId: rule.categoryId,
            accountId: rule.accountId,
            destinationAccountId: null,
            transferGroupId: null,
            transferDirection: null,
            competencyDate: admin.firestore.Timestamp.fromDate(
              spec.scheduledDate,
            ),
            dueDate: admin.firestore.Timestamp.fromDate(spec.scheduledDate),
            paymentDate: null,
            status: "pending",
            notes: rule.notes ?? null,
            attachments: [],
            attachmentUrls: [],
            cardId: null,
            invoiceId: null,
            installmentPlanId: null,
            installmentNumber: null,
            totalInstallments: null,
            recurringId: rule.id,
            occurrenceKey: spec.occurrenceKey,
            createdAt: nowTs,
            updatedAt: nowTs,
          });
        }
      } else {
        return 0;
      }

      tx.update(ruleDoc.ref, {
        lastGeneratedKey: missingSpecs[missingSpecs.length - 1].occurrenceKey,
        updatedAt: nowTs,
      });

      return missingSpecs.length;
    });

    generatedOccurrences += addedCount;
  }

  // 2. Avaliação e gravação idempotente de alertas financeiros.
  const profileSnap = await userRef.collection("profile").doc("main").get();
  const profileData = profileSnap.data() ?? {};
  const reminderDaysBefore = Number(profileData.reminderDaysBefore ?? 3);
  const notificationsEnabled =
    profileData.notificationsEnabled === undefined
      ? true
      : Boolean(profileData.notificationsEnabled);
  const pushEnabled = Boolean(profileData.pushNotificationsEnabled);

  if (!notificationsEnabled) {
    return { generatedOccurrences, createdAlerts: 0, sentPushMessages: 0 };
  }

  const [pendingTxSnap, invoicesSnap, cardsSnap, budgetsSnap, categoriesSnap] =
    await Promise.all([
      userRef
        .collection("transactions")
        .where("status", "in", ["pending", "overdue"])
        .get(),
      userRef
        .collection("invoices")
        .where("status", "in", ["open", "closed", "overdue"])
        .get(),
      userRef.collection("credit_cards").get(),
      userRef.collection("budgets").get(),
      userRef.collection("categories").get(),
    ]);

  const txInputs: TransactionSnapshotInput[] = pendingTxSnap.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      kind: String(d.kind ?? "expense"),
      description: String(d.description ?? ""),
      amountCents: Number(d.amountCents ?? 0),
      status: String(d.status ?? "pending"),
      competencyDate: asDate(d.competencyDate),
      dueDate: asNullableDate(d.dueDate),
    };
  });

  const invoiceInputs: InvoiceSnapshotInput[] = invoicesSnap.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      cardId: String(d.cardId ?? ""),
      referenceYear: Number(d.referenceYear ?? referenceDate.getUTCFullYear()),
      referenceMonth: Number(d.referenceMonth ?? referenceDate.getUTCMonth() + 1),
      dueDate: asDate(d.dueDate),
      totalAmountCents: Number(d.totalAmountCents ?? 0),
      paidAmountCents: Number(d.paidAmountCents ?? 0),
      status: String(d.status ?? "open"),
    };
  });

  const cardNamesById: Record<string, string> = {};
  for (const cardDoc of cardsSnap.docs) {
    cardNamesById[cardDoc.id] = String(cardDoc.data().name ?? "Cartão");
  }

  const categoryNamesById: Record<string, string> = {};
  for (const catDoc of categoriesSnap.docs) {
    categoryNamesById[catDoc.id] = String(catDoc.data().name ?? "Categoria");
  }

  // Avaliação de orçamentos do mês atual do usuário (caso haja metas cadastradas).
  const budgetInputs: BudgetSnapshotInput[] = [];
  if (!budgetsSnap.empty) {
    const monthStartDay = Math.min(
      Math.max(Number(profileData.monthStartDay ?? 1), 1),
      28,
    );
    const { year: curYear, month: curMonth } = resolveAccountingYearMonth(
      referenceDate,
      monthStartDay,
    );
    const { start: cycleStart, end: cycleEnd } = getAccountingMonthWindow(
      curYear,
      curMonth,
      monthStartDay,
    );
    const monthTxSnap = await userRef
      .collection("transactions")
      .where("competencyDate", ">=", admin.firestore.Timestamp.fromDate(cycleStart))
      .where("competencyDate", "<=", admin.firestore.Timestamp.fromDate(cycleEnd))
      .get();

    const spentByCategory: Record<string, number> = {};
    for (const txDoc of monthTxSnap.docs) {
      const td = txDoc.data();
      const kind = String(td.kind ?? "");
      const catId = td.categoryId ? String(td.categoryId) : "";
      if (!catId) continue;
      if (kind === "expense" || kind === "card_purchase") {
        spentByCategory[catId] =
          (spentByCategory[catId] ?? 0) + Number(td.amountCents ?? 0);
      } else if (kind === "card_refund") {
        spentByCategory[catId] =
          (spentByCategory[catId] ?? 0) - Number(td.amountCents ?? 0);
      }
    }

    for (const bDoc of budgetsSnap.docs) {
      const bd = bDoc.data();
      if (Number(bd.year) !== curYear || Number(bd.month) !== curMonth) {
        continue;
      }
      const catId = String(bd.categoryId ?? "");
      budgetInputs.push({
        id: bDoc.id,
        categoryName: categoryNamesById[catId] ?? "Categoria",
        year: curYear,
        month: curMonth,
        limitCents: Number(bd.limitCents ?? 0),
        spentCents: Math.max(0, spentByCategory[catId] ?? 0),
        alertThresholdPercent: Number(bd.alertThresholdPercent ?? 80),
      });
    }
  }

  const candidates = evaluateNotificationCandidates({
    transactions: txInputs,
    invoices: invoiceInputs,
    cardNamesById,
    reminderDaysBefore,
    notificationsEnabled,
    referenceDate,
    budgets: budgetInputs,
  }).slice(0, 40);

  let createdAlertsList: AlertCandidate[] = [];
  if (candidates.length > 0) {
    createdAlertsList = await db.runTransaction(async (tx) => {
      const toCreate: AlertCandidate[] = [];
      for (const item of candidates) {
        const ref = userRef.collection("notifications").doc(item.id);
        const snap = await tx.get(ref);
        if (!snap.exists) {
          toCreate.push(item);
        }
      }

      for (const item of toCreate) {
        const ref = userRef.collection("notifications").doc(item.id);
        tx.set(ref, {
          title: item.title,
          body: item.body,
          type: item.type,
          referenceId: item.referenceId,
          scheduledFor: admin.firestore.Timestamp.fromDate(item.scheduledFor),
          isRead: false,
          isCustom: false,
          createdAt: nowTs,
          updatedAt: nowTs,
        });
      }

      return toCreate;
    });
  }

  // 3. Envio opcional via Firebase Cloud Messaging (FCM) para tokens válidos.
  let sentPushMessages = 0;
  if (pushEnabled && createdAlertsList.length > 0) {
    const devicesSnap = await userRef.collection("notification_devices").get();
    const deviceEntries = devicesSnap.docs
      .map((doc) => ({
        ref: doc.ref,
        token: String(doc.data().token ?? ""),
      }))
      .filter((entry) => entry.token.length > 0);

    if (deviceEntries.length > 0) {
      const tokens = deviceEntries.map((entry) => entry.token);
      const firstAlert = createdAlertsList[0];
      const title =
        createdAlertsList.length === 1
          ? firstAlert.title
          : `${createdAlertsList.length} novos alertas no Finance Control`;
      const body =
        createdAlertsList.length === 1
          ? firstAlert.body
          : `${firstAlert.title} e mais ${createdAlertsList.length - 1} aviso(s).`;

      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: {
          type: firstAlert.type,
          referenceId: firstAlert.referenceId,
        },
      });

      sentPushMessages = response.successCount;

      const invalidCleanups: Promise<admin.firestore.WriteResult>[] = [];
      response.responses.forEach((res, idx) => {
        if (
          !res.success &&
          res.error &&
          (res.error.code === "messaging/registration-token-not-registered" ||
            res.error.code === "messaging/invalid-registration-token")
        ) {
          invalidCleanups.push(deviceEntries[idx].ref.delete());
        }
      });
      await Promise.all(invalidCleanups);
    }
  }

  return {
    generatedOccurrences,
    createdAlerts: createdAlertsList.length,
    sentPushMessages,
  };
}

/**
 * Execução diária agendada (06:00 BRT) para gerar recorrências pendentes e
 * despachar alertas financeiros sem duplicidades.
 */
export const scheduledFinanceAutomation = onSchedule(
  {
    schedule: "every day 06:00",
    timeZone: "America/Sao_Paulo",
    region: REGION,
  },
  async () => {
    const usersSnap = await db.collection("users").get();
    const now = new Date();
    let totalGenerated = 0;
    let totalAlerts = 0;
    let totalPush = 0;

    for (const userDoc of usersSnap.docs) {
      try {
        const res = await syncUserAutomation(userDoc.id, now);
        totalGenerated += res.generatedOccurrences;
        totalAlerts += res.createdAlerts;
        totalPush += res.sentPushMessages;
      } catch (err) {
        logger.error(`Erro na automação do usuário ${userDoc.id}`, err);
      }
    }

    logger.info("Execução diária concluída", {
      usersProcessed: usersSnap.size,
      totalGenerated,
      totalAlerts,
      totalPush,
    });
  },
);

/**
 * Gatilho autenticado sob demanda para sincronizar recorrências e alertas do usuário.
 */
export const syncAutomationOnDemand = onCall(
  {
    region: REGION,
    cors: true,
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    }
    return syncUserAutomation(request.auth.uid, new Date());
  },
);

/**
 * Endpoint autenticado do Assistente Financeiro IA (Módulo 23 — Google Gemini).
 * Valida Firebase ID Token, preferências de privacidade, rate limit diário e de rajada,
 * executa Function Calling exclusivamente de leitura e retorna JSON validado.
 */
export const aiAssistantQuery = onCall(
  {
    region: REGION,
    cors: true,
    enforceAppCheck: ENFORCE_APP_CHECK,
    timeoutSeconds: 60,
    memory: "512MiB",
    maxInstances: 20,
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    }
    const data =
      request.data && typeof request.data === "object"
        ? (request.data as Record<string, unknown>)
        : {};
    return handleAiAssistantRequest({
      db,
      uid: request.auth.uid,
      requestData: data,
    });
  },
);

/**
 * Remove recursivamente todos os documentos de `users/{uid}` (incluindo `ai_usage`
 * e `ai_interactions`) e arquivos do usuário no Firebase Storage (`users/{uid}/`).
 */
export const deleteUserAccountData = onCall(
  {
    region: REGION,
    cors: true,
    enforceAppCheck: ENFORCE_APP_CHECK,
    timeoutSeconds: 60,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Usuário não autenticado.");
    }

    return purgeUserAccountData({
      uid,
      recursiveDeleteUserDoc: async (targetUid) => {
        await db.recursiveDelete(db.collection("users").doc(targetUid));
      },
      deleteUserStoragePrefix: async (prefix) => {
        await admin.storage().bucket().deleteFiles({ prefix });
      },
      onStorageWarning: (msg, err) => {
        logger.warn(msg, err);
      },
    });
  },
);
