import { test } from "node:test";
import * as assert from "node:assert/strict";
import { purgeUserAccountData } from "../src/account_cleanup";

test("purgeUserAccountData remove documentos do usuário e prefixo do Storage", async () => {
  const calls: string[] = [];
  const res = await purgeUserAccountData({
    uid: "user_123",
    recursiveDeleteUserDoc: async (uid) => {
      calls.push(`firestore:${uid}`);
    },
    deleteUserStoragePrefix: async (prefix) => {
      calls.push(`storage:${prefix}`);
    },
  });

  assert.deepEqual(calls, ["firestore:user_123", "storage:users/user_123/"]);
  assert.deepEqual(res, {
    deleted: true,
    uid: "user_123",
    storageCleaned: true,
  });
});

test("purgeUserAccountData conclui exclusão mesmo quando o Storage ainda não possui arquivos ou bucket falha", async () => {
  const warnings: string[] = [];
  const res = await purgeUserAccountData({
    uid: "user_456",
    recursiveDeleteUserDoc: async () => undefined,
    deleteUserStoragePrefix: async () => {
      throw new Error("bucket not initialized");
    },
    onStorageWarning: (msg) => warnings.push(msg),
  });

  assert.equal(res.deleted, true);
  assert.equal(res.storageCleaned, false);
  assert.equal(warnings.length, 1);
});

test("purgeUserAccountData rejeita uid vazio", async () => {
  await assert.rejects(
    purgeUserAccountData({
      uid: "",
      recursiveDeleteUserDoc: async () => undefined,
      deleteUserStoragePrefix: async () => undefined,
    }),
    /UID inválido/,
  );
});
