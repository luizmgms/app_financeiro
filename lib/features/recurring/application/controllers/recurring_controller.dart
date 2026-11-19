import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../domain/entities/recurring_rule_entity.dart';
import '../providers/recurring_providers.dart';

class RecurringActionState extends Equatable {
  const RecurringActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  @override
  List<Object?> get props => [isLoading, errorMessage, successMessage];
}

class RecurringController extends Notifier<RecurringActionState> {
  @override
  RecurringActionState build() => const RecurringActionState();

  String _requireUserId() {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) {
      throw const AuthFailure('Faça login para gerenciar contas recorrentes.');
    }
    return user.uid;
  }

  Future<bool> saveRule({
    RecurringRuleEntity? existing,
    required RecurringKind kind,
    required String description,
    required int amountCents,
    required bool isVariableAmount,
    required String categoryId,
    String? accountId,
    String? cardId,
    required RecurringFrequency frequency,
    int? customIntervalDays,
    required DateTime startDate,
    DateTime? endDate,
    String? notes,
  }) async {
    state = const RecurringActionState(isLoading: true);
    try {
      final uid = _requireUserId();
      final trimmed = description.trim();
      if (trimmed.isEmpty) {
        state = const RecurringActionState(
          errorMessage: 'Informe a descrição da recorrência.',
        );
        return false;
      }
      if (amountCents <= 0) {
        state = const RecurringActionState(
          errorMessage: 'Informe um valor maior que zero.',
        );
        return false;
      }
      if (categoryId.isEmpty) {
        state = const RecurringActionState(
          errorMessage: 'Selecione uma categoria.',
        );
        return false;
      }
      final isCard = kind == RecurringKind.expense &&
          cardId != null &&
          cardId.isNotEmpty;
      if (!isCard && (accountId == null || accountId.isEmpty)) {
        state = const RecurringActionState(
          errorMessage: 'Selecione a conta financeira vinculada.',
        );
        return false;
      }
      if (frequency == RecurringFrequency.custom &&
          (customIntervalDays == null || customIntervalDays <= 0)) {
        state = const RecurringActionState(
          errorMessage: 'Informe um intervalo válido em dias (mínimo 1).',
        );
        return false;
      }

      final normalizedStart = DateFormatter.dateOnly(startDate);
      final normalizedEnd =
          endDate != null ? DateFormatter.dateOnly(endDate) : null;
      if (normalizedEnd != null && normalizedEnd.isBefore(normalizedStart)) {
        state = const RecurringActionState(
          errorMessage: 'A data final não pode ser anterior à data inicial.',
        );
        return false;
      }

      final now = DateTime.now();
      final repo = ref.read(recurringRepositoryProvider);

      if (existing == null) {
        final newRule = RecurringRuleEntity(
          id: '',
          description: trimmed,
          kind: kind,
          amountCents: amountCents,
          isVariableAmount: isVariableAmount,
          categoryId: categoryId,
          accountId: isCard ? null : accountId,
          cardId: isCard ? cardId : null,
          frequency: frequency,
          customIntervalDays:
              frequency == RecurringFrequency.custom ? customIntervalDays : null,
          startDate: normalizedStart,
          endDate: normalizedEnd,
          status: RecurringStatus.active,
          notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
          createdAt: now,
          updatedAt: now,
        );
        await repo.createRule(userId: uid, rule: newRule);
        state = const RecurringActionState(
          successMessage: 'Recorrência criada e ocorrências geradas.',
        );
      } else {
        final updated = existing.copyWith(
          kind: kind,
          description: trimmed,
          amountCents: amountCents,
          isVariableAmount: isVariableAmount,
          categoryId: categoryId,
          accountId: isCard ? null : accountId,
          clearAccountId: isCard,
          cardId: isCard ? cardId : null,
          clearCardId: !isCard,
          frequency: frequency,
          customIntervalDays:
              frequency == RecurringFrequency.custom ? customIntervalDays : null,
          clearCustomIntervalDays: frequency != RecurringFrequency.custom,
          startDate: normalizedStart,
          endDate: normalizedEnd,
          clearEndDate: normalizedEnd == null,
          notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
          updatedAt: now,
        );
        await repo.updateRule(userId: uid, rule: updated);
        state = const RecurringActionState(
          successMessage: 'Recorrência atualizada com sucesso.',
        );
      }
      return true;
    } on Failure catch (failure) {
      state = RecurringActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = RecurringActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Erro ao salvar recorrência.',
        ),
      );
      return false;
    }
  }

  Future<bool> setStatus({
    required String ruleId,
    required RecurringStatus status,
  }) async {
    state = const RecurringActionState(isLoading: true);
    try {
      final uid = _requireUserId();
      await ref.read(recurringRepositoryProvider).setStatus(
            userId: uid,
            ruleId: ruleId,
            status: status,
          );
      final label = switch (status) {
        RecurringStatus.active => 'Recorrência retomada e sincronizada.',
        RecurringStatus.paused => 'Recorrência pausada.',
        RecurringStatus.canceled => 'Recorrência cancelada.',
      };
      state = RecurringActionState(successMessage: label);
      return true;
    } on Failure catch (failure) {
      state = RecurringActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = RecurringActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível alterar o status.',
        ),
      );
      return false;
    }
  }

  Future<bool> deleteRule(String ruleId) async {
    state = const RecurringActionState(isLoading: true);
    try {
      final uid = _requireUserId();
      await ref.read(recurringRepositoryProvider).deleteRule(
            userId: uid,
            ruleId: ruleId,
          );
      state = const RecurringActionState(
        successMessage: 'Recorrência excluída.',
      );
      return true;
    } on Failure catch (failure) {
      state = RecurringActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = RecurringActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível excluir a recorrência.',
        ),
      );
      return false;
    }
  }

  Future<int> syncNow({DateTime? referenceDate, bool silent = false}) async {
    if (!silent) {
      state = const RecurringActionState(isLoading: true);
    }
    try {
      final uid = _requireUserId();
      final created =
          await ref.read(recurringRepositoryProvider).syncOccurrences(
                userId: uid,
                referenceDate: referenceDate,
              );
      if (!silent) {
        state = RecurringActionState(
          successMessage: created > 0
              ? '$created nova(s) ocorrência(s) gerada(s) sem duplicidade.'
              : 'Recorrências já estão atualizadas.',
        );
      }
      return created;
    } on Failure catch (failure) {
      if (!silent) {
        state = RecurringActionState(errorMessage: failure.message);
      }
      return 0;
    } catch (error) {
      if (!silent) {
        state = RecurringActionState(
          errorMessage: formatUnexpectedFailureMessage(
            error,
            fallbackMessage: 'Erro ao sincronizar recorrências.',
          ),
        );
      }
      return 0;
    }
  }

  Future<bool> updateSingleCardOccurrence({
    required String transactionId,
    required String description,
    required int amountCents,
    String? notes,
  }) async {
    state = const RecurringActionState(isLoading: true);
    try {
      final uid = _requireUserId();
      if (description.trim().isEmpty || amountCents <= 0) {
        state = const RecurringActionState(
          errorMessage: 'Informe descrição e valor válidos.',
        );
        return false;
      }
      await ref.read(recurringRepositoryProvider).updateSingleCardOccurrence(
            userId: uid,
            transactionId: transactionId,
            description: description,
            amountCents: amountCents,
            notes: notes,
          );
      state = const RecurringActionState(
        successMessage: 'Ocorrência ajustada individualmente.',
      );
      return true;
    } on Failure catch (failure) {
      state = RecurringActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = RecurringActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Erro ao atualizar ocorrência no cartão.',
        ),
      );
      return false;
    }
  }
}

final recurringControllerProvider =
    NotifierProvider<RecurringController, RecurringActionState>(
  RecurringController.new,
);
