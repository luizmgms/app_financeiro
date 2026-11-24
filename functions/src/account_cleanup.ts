export interface PurgeUserAccountDeps {
  uid: string;
  recursiveDeleteUserDoc: (uid: string) => Promise<void>;
  deleteUserStoragePrefix: (prefix: string) => Promise<void>;
  onStorageWarning?: (message: string, error: unknown) => void;
}

export interface PurgeUserAccountResult {
  deleted: true;
  uid: string;
  storageCleaned: boolean;
}

/**
 * Executa a exclusão recursiva LGPD de todos os documentos de `users/{uid}` e
 * limpa arquivos no Firebase Storage sem abortar caso o bucket ainda esteja vazio.
 */
export async function purgeUserAccountData(
  deps: PurgeUserAccountDeps,
): Promise<PurgeUserAccountResult> {
  const { uid, recursiveDeleteUserDoc, deleteUserStoragePrefix, onStorageWarning } = deps;
  if (!uid || uid.trim().length === 0) {
    throw new Error("UID inválido para exclusão de conta.");
  }

  await recursiveDeleteUserDoc(uid);

  let storageCleaned = false;
  try {
    await deleteUserStoragePrefix(`users/${uid}/`);
    storageCleaned = true;
  } catch (err) {
    onStorageWarning?.(`Limpeza opcional de Storage para ${uid} ignorada`, err);
  }

  return {
    deleted: true,
    uid,
    storageCleaned,
  };
}
