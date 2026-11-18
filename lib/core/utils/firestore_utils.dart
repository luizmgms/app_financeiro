import 'package:cloud_firestore/cloud_firestore.dart';

/// Utilitários compartilhados de serialização e integridade para o Cloud Firestore.
abstract final class FirestoreUtils {
  /// Normaliza uma data para precisão de milissegundos.
  ///
  /// No Flutter Web, `Timestamp.toDate()` converte via `Date` de JavaScript,
  /// descartando microssegundos. Persistir datas já normalizadas em milissegundos
  /// evita divergências entre plataformas.
  static DateTime normalizeToMillis(DateTime date) {
    return DateTime.fromMillisecondsSinceEpoch(
      date.millisecondsSinceEpoch,
      isUtc: date.isUtc,
    );
  }

  /// Converte [date] em [Timestamp] com precisão de milissegundos.
  static Timestamp toMillisTimestamp(DateTime date) {
    return Timestamp.fromDate(normalizeToMillis(date));
  }

  /// Converte [date] anulável em [Timestamp] com precisão de milissegundos.
  static Timestamp? toNullableMillisTimestamp(DateTime? date) {
    if (date == null) return null;
    return toMillisTimestamp(date);
  }

  /// Remove `createdAt` de mapas usados em `.update(...)` ou merge parciais.
  ///
  /// Essencial no Flutter Web: `cloud_firestore_web` decodifica e recodifica
  /// `Timestamp` via `Date` (apenas milissegundos). Reenviar `createdAt` em
  /// um `.update()` para documentos gravados com microssegundos (ex.: Android)
  /// trunca o campo e falha em regras como `areImmutableFieldsUnchanged(['createdAt'])`.
  static Map<String, dynamic> withoutCreatedAt(Map<String, dynamic> payload) {
    if (!payload.containsKey('createdAt')) return payload;
    return Map<String, dynamic>.of(payload)..remove('createdAt');
  }
}
