import '../entities/recurring_rule_entity.dart';

/// Contrato de persistência e geração idempotente de contas recorrentes.
abstract interface class RecurringRepository {
  Stream<List<RecurringRuleEntity>> watchRules(String userId);

  Future<RecurringRuleEntity> createRule({
    required String userId,
    required RecurringRuleEntity rule,
    DateTime? referenceDate,
  });

  Future<void> updateRule({
    required String userId,
    required RecurringRuleEntity rule,
  });

  Future<void> setStatus({
    required String userId,
    required String ruleId,
    required RecurringStatus status,
  });

  Future<void> deleteRule({
    required String userId,
    required String ruleId,
  });

  /// Gera lançamentos futuros/pendentes elegíveis sem duplicar ocorrências existentes.
  /// Retorna a quantidade de novas transações criadas.
  Future<int> syncOccurrences({
    required String userId,
    DateTime? referenceDate,
  });

  /// Edita pontualmente uma única ocorrência em cartão vinculada a recorrência,
  /// ajustando faturas e limite utilizado sem alterar a série nem outras ocorrências.
  Future<void> updateSingleCardOccurrence({
    required String userId,
    required String transactionId,
    required String description,
    required int amountCents,
    String? notes,
  });
}
