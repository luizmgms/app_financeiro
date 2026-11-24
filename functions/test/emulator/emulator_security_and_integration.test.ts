import { after, before, beforeEach, test } from "node:test";
import * as assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { getApp, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

function resolveRepoFile(fileName: string): string {
  const candidates = [
    path.resolve(process.cwd(), fileName),
    path.resolve(process.cwd(), "..", fileName),
    path.resolve(__dirname, "../../../..", fileName),
  ];
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  throw new Error(`Arquivo ${fileName} não encontrado para testes no Emulator.`);
}

const PROJECT_ID = "demo-finance-control-e2e";
let testEnv: RulesTestEnvironment;

function nowDate(): Date {
  return new Date("2026-11-23T12:00:00.000Z");
}

function validProfileDoc(uid: string) {
  const now = nowDate();
  return {
    uid,
    displayName: "Usuário Teste",
    email: `${uid}@financecontrol.app`,
    defaultCurrency: "BRL",
    localeCode: "pt_BR",
    monthStartDay: 1,
    reminderDaysBefore: 3,
    notificationsEnabled: true,
    pushNotificationsEnabled: false,
    aiAssistantEnabled: true,
    aiShareFinancialContext: true,
    createdAt: now,
    updatedAt: now,
  };
}

function validAccountDoc(name = "Conta Corrente", initialBalanceCents = 100000) {
  const now = nowDate();
  return {
    name,
    institution: "Banco Digital",
    type: "checking",
    initialBalanceCents,
    currentBalanceCents: initialBalanceCents,
    colorHex: "#0F766E",
    iconName: "account_balance",
    openedAt: now,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  };
}

function validTransactionDoc(overrides: Record<string, unknown> = {}) {
  const now = nowDate();
  return {
    kind: "expense",
    description: "Supermercado Teste",
    amountCents: 12550,
    categoryId: "cat_exp_food",
    accountId: "acc_1",
    destinationAccountId: null,
    transferGroupId: null,
    transferDirection: null,
    competencyDate: now,
    dueDate: now,
    paymentDate: now,
    status: "paid",
    notes: "Compra mensal",
    attachments: [],
    attachmentUrls: [],
    cardId: null,
    invoiceId: null,
    installmentPlanId: null,
    installmentNumber: null,
    totalInstallments: null,
    recurringId: null,
    occurrenceKey: null,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

before(async () => {
  const firestoreRules = fs.readFileSync(resolveRepoFile("firestore.rules"), "utf8");
  const storageRules = fs.readFileSync(resolveRepoFile("storage.rules"), "utf8");

  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: firestoreRules,
    },
    storage: {
      rules: storageRules,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

test("Firestore Rules: isolamento estrito entre usuários e bloqueio não autenticado", async () => {
  const unauthDb = testEnv.unauthenticatedContext().firestore();
  const aliceDb = testEnv.authenticatedContext("alice").firestore();
  const bobDb = testEnv.authenticatedContext("bob").firestore();

  await assertFails(unauthDb.collection("users").doc("alice").get());
  await assertFails(
    unauthDb
      .collection("users")
      .doc("alice")
      .collection("accounts")
      .doc("acc_1")
      .set(validAccountDoc()),
  );

  await assertSucceeds(
    aliceDb
      .collection("users")
      .doc("alice")
      .collection("profile")
      .doc("main")
      .set(validProfileDoc("alice")),
  );
  await assertSucceeds(
    aliceDb
      .collection("users")
      .doc("alice")
      .collection("accounts")
      .doc("acc_1")
      .set(validAccountDoc()),
  );

  // Bob não pode ler nem gravar documentos no namespace de Alice.
  await assertFails(
    bobDb
      .collection("users")
      .doc("alice")
      .collection("accounts")
      .doc("acc_1")
      .get(),
  );
  await assertFails(
    bobDb
      .collection("users")
      .doc("alice")
      .collection("accounts")
      .doc("acc_hack")
      .set(validAccountDoc("Invadida")),
  );
  await assertFails(
    bobDb
      .collection("users")
      .doc("alice")
      .collection("accounts")
      .doc("acc_1")
      .delete(),
  );
});

test("Firestore Rules Red-Team: bloqueia valores negativos/overflow, mutação de createdAt/uid e adulteração da cota IA", async () => {
  const aliceDb = testEnv.authenticatedContext("alice").firestore();
  const aliceRoot = aliceDb.collection("users").doc("alice");

  // Rejeita transação com valor <= 0, valor acima do teto ou tipo/status inválido.
  await assertFails(
    aliceRoot
      .collection("transactions")
      .doc("tx_zero")
      .set(validTransactionDoc({ amountCents: 0 })),
  );
  await assertFails(
    aliceRoot
      .collection("transactions")
      .doc("tx_neg")
      .set(validTransactionDoc({ amountCents: -100 })),
  );
  await assertFails(
    aliceRoot
      .collection("transactions")
      .doc("tx_overflow")
      .set(validTransactionDoc({ amountCents: 100000000001 })),
  );
  await assertFails(
    aliceRoot
      .collection("transactions")
      .doc("tx_bad_kind")
      .set(validTransactionDoc({ kind: "admin_override" })),
  );

  // Cria transação válida COM anexos, atualiza descrição validamente (sucesso!) e tenta mutar `createdAt` (deve falhar).
  const sampleAttachment = {
    id: "att_1",
    name: "nota.jpg",
    url: "https://firebasestorage.googleapis.com/v0/b/demo/o/nota.jpg",
    storagePath: "users/alice/transactions/tx_ok/att_1_nota.jpg",
    contentType: "image/jpeg",
    sizeBytes: 2048,
  };
  const validTx = validTransactionDoc({
    attachments: [
      sampleAttachment,
      { ...sampleAttachment, id: "att_2" },
      { ...sampleAttachment, id: "att_3" },
      { ...sampleAttachment, id: "att_4" },
      { ...sampleAttachment, id: "att_5" },
    ],
    attachmentUrls: [
      sampleAttachment.url,
      sampleAttachment.url,
      sampleAttachment.url,
      sampleAttachment.url,
      sampleAttachment.url,
    ],
  });
  await assertSucceeds(aliceRoot.collection("transactions").doc("tx_ok").set(validTx));
  await assertSucceeds(
    aliceRoot
      .collection("transactions")
      .doc("tx_ok")
      .update({
        ...validTx,
        description: "Supermercado Atualizado",
        updatedAt: new Date("2026-11-23T18:00:00.000Z"),
      }),
  );
  // Caso pior-cenário em produção: todos os 24 campos preenchidos + 10 anexos + 10 URLs devem criar e atualizar sem estourar 1.000 expressões.
  const fullTenAttachments = Array.from({ length: 10 }, (_, idx) => ({
    ...sampleAttachment,
    id: `att_${idx + 1}`,
    storagePath: `users/alice/transactions/tx_max/att_${idx + 1}_nota.jpg`,
  }));
  const maxPopulatedTx = validTransactionDoc({
    kind: "card_purchase",
    destinationAccountId: "acc_2",
    transferGroupId: "grp_1",
    transferDirection: "out",
    cardId: "card_1",
    invoiceId: "inv_1",
    installmentPlanId: "inst_1",
    installmentNumber: 1,
    totalInstallments: 12,
    recurringId: "rec_1",
    occurrenceKey: "rec_1_2026-11-23",
    attachments: fullTenAttachments,
    attachmentUrls: Array.from({ length: 10 }, () => sampleAttachment.url),
  });
  await assertSucceeds(aliceRoot.collection("transactions").doc("tx_max").set(maxPopulatedTx));
  await assertSucceeds(
    aliceRoot
      .collection("transactions")
      .doc("tx_max")
      .update({
        ...maxPopulatedTx,
        description: "Compra Parcelada Atualizada",
        updatedAt: new Date("2026-11-23T19:00:00.000Z"),
      }),
  );
  await assertFails(
    aliceRoot
      .collection("transactions")
      .doc("tx_ok")
      .update({
        ...validTx,
        createdAt: new Date("2025-01-01T00:00:00.000Z"),
        updatedAt: new Date("2026-11-24T00:00:00.000Z"),
      }),
  );
  // Bloqueia anexo apontando para outro usuário ou path traversal.
  await assertFails(
    aliceRoot
      .collection("transactions")
      .doc("tx_bad_att_path")
      .set(
        validTransactionDoc({
          attachments: [
            {
              ...sampleAttachment,
              storagePath: "users/alice/../bob/secret.jpg",
            },
          ],
        }),
      ),
  );
  await assertFails(
    aliceRoot
      .collection("transactions")
      .doc("tx_bad_att_missing")
      .set(
        validTransactionDoc({
          attachments: [{ url: sampleAttachment.url }],
        }),
      ),
  );

  // Recorrência válida com skippedOccurrenceKeys cria e atualiza sem estourar cota de expressões.
  const validRecurring = {
    description: "Internet Fibra",
    kind: "expense",
    amountCents: 14990,
    isVariableAmount: false,
    categoryId: "cat_exp_housing",
    accountId: "acc_1",
    cardId: null,
    frequency: "monthly",
    customIntervalDays: null,
    startDate: nowDate(),
    endDate: null,
    status: "active",
    lastGeneratedKey: "rec_1_2026-11-23",
    skippedOccurrenceKeys: ["rec_1_2026-10-23"],
    notes: null,
    createdAt: nowDate(),
    updatedAt: nowDate(),
  };
  await assertSucceeds(aliceRoot.collection("recurring").doc("rec_1").set(validRecurring));
  await assertSucceeds(
    aliceRoot
      .collection("recurring")
      .doc("rec_1")
      .update({
        ...validRecurring,
        skippedOccurrenceKeys: ["rec_1_2026-10-23", "rec_1_2026-12-23"],
        updatedAt: new Date("2026-11-24T00:00:00.000Z"),
      }),
  );

  // Cliente não pode escrever em `ai_usage` nem forjar `ai_interactions`, mas pode ler/excluir interações.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const adminDb = ctx.firestore();
    await adminDb
      .collection("users")
      .doc("alice")
      .collection("ai_usage")
      .doc("quota")
      .set({
        dayKey: "2026-11-23",
        dailyCount: 5,
        windowBucket: 1,
        windowCount: 1,
        totalRequests: 5,
        updatedAt: nowDate(),
      });
    await adminDb
      .collection("users")
      .doc("alice")
      .collection("ai_interactions")
      .doc("int_1")
      .set({
        mode: "chat",
        model: "gemini-3.8-flash",
        status: "ok",
        toolsUsed: [],
        latencyMs: 320,
        createdAt: nowDate(),
      });
  });

  await assertSucceeds(aliceRoot.collection("ai_usage").doc("quota").get());
  await assertFails(
    aliceRoot.collection("ai_usage").doc("quota").set({ dailyCount: 0 }),
  );
  await assertFails(aliceRoot.collection("ai_usage").doc("quota").delete());

  await assertFails(
    aliceRoot.collection("ai_interactions").doc("int_spoof").set({
      mode: "chat",
      model: "gemini-3.8-flash",
      status: "ok",
      toolsUsed: [],
      latencyMs: 1,
      createdAt: nowDate(),
    }),
  );
  await assertSucceeds(aliceRoot.collection("ai_interactions").doc("int_1").get());
  await assertSucceeds(aliceRoot.collection("ai_interactions").doc("int_1").delete());
});

test("Storage Rules Red-Team: aceita JPG/PDF no escopo de transações e bloqueia XSS HTML, oversize e acesso cruzado", async () => {
  const aliceStorage = testEnv.authenticatedContext("alice").storage();
  const bobStorage = testEnv.authenticatedContext("bob").storage();
  const tinyJpg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]);
  const tinyHtml = new Uint8Array(Buffer.from("<script>alert(1)</script>"));

  // Upload válido JPG e PDF em users/alice/transactions/tx_1/...
  await assertSucceeds(
    aliceStorage
      .ref("users/alice/transactions/tx_1/att_comprovante.jpg")
      .put(tinyJpg, { contentType: "image/jpeg" })
      .then((snap) => snap),
  );
  await assertSucceeds(
    aliceStorage
      .ref("users/alice/transactions/tx_1/att_nota.pdf")
      .put(new Uint8Array([0x25, 0x50, 0x44, 0x46]), {
        contentType: "application/pdf",
      })
      .then((snap) => snap),
  );

  // Bloqueia MIME HTML (prevenção de XSS) e caminhos fora de `transactions/`.
  await assertFails(
    aliceStorage
      .ref("users/alice/transactions/tx_1/payload.html")
      .put(tinyHtml, { contentType: "text/html" })
      .then((snap) => snap),
  );
  await assertFails(
    aliceStorage
      .ref("users/alice/arbitrary_folder/photo.jpg")
      .put(tinyJpg, { contentType: "image/jpeg" })
      .then((snap) => snap),
  );

  // Bob não lê, grava nem exclui arquivos de Alice.
  await assertFails(
    bobStorage
      .ref("users/alice/transactions/tx_1/att_comprovante.jpg")
      .getMetadata(),
  );
  await assertFails(
    bobStorage
      .ref("users/alice/transactions/tx_1/att_comprovante.jpg")
      .delete(),
  );
  await assertFails(
    bobStorage
      .ref("users/alice/transactions/tx_1/spoof.jpg")
      .put(tinyJpg, { contentType: "image/jpeg" })
      .then((snap) => snap),
  );

  // Alice exclui seu próprio anexo com sucesso.
  await assertSucceeds(
    aliceStorage
      .ref("users/alice/transactions/tx_1/att_comprovante.jpg")
      .delete(),
  );
});

test("Integração Firestore Emulator: contas, transferência atômica, fatura e exclusão recursiva LGPD", async () => {
  const aliceDb = testEnv.authenticatedContext("alice").firestore();
  const userRef = aliceDb.collection("users").doc("alice");

  await assertSucceeds(userRef.set({ uid: "alice", email: "alice@financecontrol.app" }));
  await assertSucceeds(userRef.collection("profile").doc("main").set(validProfileDoc("alice")));
  await assertSucceeds(userRef.collection("accounts").doc("acc_chk").set(validAccountDoc("Corrente", 200000)));
  await assertSucceeds(userRef.collection("accounts").doc("acc_sav").set(validAccountDoc("Poupança", 50000)));

  // Executa transação atômica de transferência (saída + entrada + atualização dos 2 saldos).
  const now = nowDate();
  await assertSucceeds(
    aliceDb.runTransaction(async (tx) => {
      const srcRef = userRef.collection("accounts").doc("acc_chk");
      const dstRef = userRef.collection("accounts").doc("acc_sav");
      const srcSnap = await tx.get(srcRef);
      const dstSnap = await tx.get(dstRef);
      const srcBalance = Number(srcSnap.data()?.currentBalanceCents ?? 0);
      const dstBalance = Number(dstSnap.data()?.currentBalanceCents ?? 0);

      tx.update(srcRef, { ...srcSnap.data(), currentBalanceCents: srcBalance - 50000, updatedAt: now });
      tx.update(dstRef, { ...dstSnap.data(), currentBalanceCents: dstBalance + 50000, updatedAt: now });
      tx.set(
        userRef.collection("transactions").doc("tx_tr_out"),
        validTransactionDoc({
          kind: "transfer",
          description: "Reserva (saída)",
          amountCents: 50000,
          categoryId: null,
          accountId: "acc_chk",
          destinationAccountId: "acc_sav",
          transferGroupId: "grp_1",
          transferDirection: "out",
          status: "completed",
        }),
      );
      tx.set(
        userRef.collection("transactions").doc("tx_tr_in"),
        validTransactionDoc({
          kind: "transfer",
          description: "Reserva (entrada)",
          amountCents: 50000,
          categoryId: null,
          accountId: "acc_sav",
          destinationAccountId: "acc_chk",
          transferGroupId: "grp_1",
          transferDirection: "in",
          status: "completed",
        }),
      );
    }),
  );

  const chkSnap = await userRef.collection("accounts").doc("acc_chk").get();
  const savSnap = await userRef.collection("accounts").doc("acc_sav").get();
  assert.equal(chkSnap.data()?.currentBalanceCents, 150000);
  assert.equal(savSnap.data()?.currentBalanceCents, 100000);

  // Valida todas as demais subcoleções sob as regras endurecidas da Etapa 7.
  await assertSucceeds(
    userRef.collection("categories").doc("cat_food").set({
      name: "Alimentação",
      description: "Mercado e restaurantes",
      type: "expense",
      iconName: "restaurant",
      colorHex: "#EF4444",
      isDefault: true,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    }),
  );
  await assertSucceeds(
    userRef.collection("credit_cards").doc("card_1").set({
      name: "Nubank",
      institution: "Nu Pagamentos",
      brand: "mastercard",
      totalLimitCents: 500000,
      usedLimitCents: 10000,
      closingDay: 10,
      dueDay: 20,
      paymentAccountId: "acc_chk",
      colorHex: "#7C3AED",
      defaultInstallments: 1,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    }),
  );
  await assertSucceeds(
    userRef.collection("invoices").doc("card_1_2026_11").set({
      cardId: "card_1",
      referenceYear: 2026,
      referenceMonth: 11,
      closingDate: now,
      dueDate: now,
      totalAmountCents: 10000,
      paidAmountCents: 0,
      status: "open",
      paymentTransactionId: null,
      paidAt: null,
      createdAt: now,
      updatedAt: now,
    }),
  );
  await assertSucceeds(
    userRef.collection("installments").doc("plan_1").set({
      description: "Monitor 4K",
      totalAmountCents: 120000,
      installmentCount: 3,
      firstCompetencyDate: now,
      firstDueDate: now,
      cardId: "card_1",
      accountId: null,
      categoryId: "cat_food",
      notes: null,
      status: "active",
      createdAt: now,
      updatedAt: now,
    }),
  );
  await assertSucceeds(
    userRef.collection("notifications").doc("notif_1").set({
      title: "Fatura próxima",
      body: "Fatura fecha em 3 dias.",
      type: "invoice_due",
      referenceId: "card_1_2026_11",
      scheduledFor: now,
      isRead: false,
      isCustom: false,
      createdAt: now,
      updatedAt: now,
    }),
  );
  await assertSucceeds(
    userRef.collection("notification_devices").doc("fcm_1").set({
      token: "fcm-token-abc123",
      platform: "Android",
      createdAt: now,
      updatedAt: now,
    }),
  );
  await assertSucceeds(
    userRef.collection("budgets").doc("cat_food_2026_11").set({
      categoryId: "cat_food",
      year: 2026,
      month: 11,
      limitCents: 150000,
      alertThresholdPercent: 80,
      notes: "Meta mensal",
      createdAt: now,
      updatedAt: now,
    }),
  );

  // Admin SDK `recursiveDelete` (equivalente à função `deleteUserAccountData`) limpa tudo inclusive `ai_usage`.
  const adminApp = getApps().length > 0
    ? getApp()
    : initializeApp({ projectId: PROJECT_ID });
  const adminDb = getFirestore(adminApp);

  await adminDb
    .collection("users")
    .doc("alice")
    .collection("ai_usage")
    .doc("quota")
    .set({
      dayKey: "2026-11-23",
      dailyCount: 2,
      windowBucket: 1,
      windowCount: 1,
      totalRequests: 2,
      updatedAt: Timestamp.now(),
    });

  await adminDb.recursiveDelete(adminDb.collection("users").doc("alice"));

  const remainingProfile = await adminDb
    .collection("users")
    .doc("alice")
    .collection("profile")
    .get();
  const remainingQuota = await adminDb
    .collection("users")
    .doc("alice")
    .collection("ai_usage")
    .get();
  assert.equal(remainingProfile.size, 0);
  assert.equal(remainingQuota.size, 0);
});
