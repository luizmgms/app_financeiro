import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../../budgets/application/providers/budget_providers.dart';
import '../../../credit_cards/application/providers/credit_card_providers.dart';
import '../../../profile/application/controllers/profile_controller.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../transactions/application/providers/transaction_providers.dart';
import '../../domain/services/notification_evaluation_service.dart';
import '../providers/notification_providers.dart';

class NotificationActionState extends Equatable {
  const NotificationActionState({
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

class NotificationController extends Notifier<NotificationActionState> {
  @override
  NotificationActionState build() => const NotificationActionState();

  String _requireUserId() {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) {
      throw const AuthFailure('Faça login para gerenciar notificações.');
    }
    return user.uid;
  }

  Future<int> syncAlerts({
    DateTime? referenceDate,
    bool silent = false,
  }) async {
    if (!silent) {
      state = const NotificationActionState(isLoading: true);
    }
    try {
      final uid = _requireUserId();
      final profile = ref.read(userProfileProvider).valueOrNull;
      final transactions =
          ref.read(transactionsStreamProvider).valueOrNull ?? const [];
      final invoices = ref.read(invoicesStreamProvider).valueOrNull ?? const [];
      final cardsById = ref.read(creditCardsByIdProvider);
      final budgetInputs = ref.read(currentMonthBudgetAlertInputsProvider);

      final candidates = NotificationEvaluationService.evaluateSystemAlerts(
        transactions: transactions,
        invoices: invoices,
        cardsById: cardsById,
        reminderDaysBefore: profile?.reminderDaysBefore ?? 3,
        notificationsEnabled: profile?.notificationsEnabled ?? true,
        referenceDate: referenceDate ?? DateTime.now(),
        locale: profile?.localeCode ?? 'pt_BR',
        currencyCode: profile?.defaultCurrency ?? 'BRL',
        budgets: budgetInputs,
      );

      final created =
          await ref.read(notificationRepositoryProvider).syncSystemAlerts(
                userId: uid,
                candidates: candidates,
              );

      if (!silent) {
        state = NotificationActionState(
          successMessage: created > 0
              ? '$created novo(s) alerta(s) gerado(s).'
              : 'Central de notificações atualizada.',
        );
      }
      return created;
    } on Failure catch (failure) {
      if (!silent) {
        state = NotificationActionState(errorMessage: failure.message);
      }
      return 0;
    } catch (error) {
      if (!silent) {
        state = NotificationActionState(
          errorMessage: formatUnexpectedFailureMessage(
            error,
            fallbackMessage: 'Erro ao atualizar notificações.',
          ),
        );
      }
      return 0;
    }
  }

  Future<bool> createCustomReminder({
    required String title,
    required String body,
    required DateTime scheduledFor,
  }) async {
    state = const NotificationActionState(isLoading: true);
    try {
      final uid = _requireUserId();
      if (title.trim().isEmpty) {
        state = const NotificationActionState(
          errorMessage: 'Informe o título do lembrete.',
        );
        return false;
      }

      await ref.read(notificationRepositoryProvider).createCustomReminder(
            userId: uid,
            title: title,
            body: body,
            scheduledFor: scheduledFor,
          );
      state = const NotificationActionState(
        successMessage: 'Lembrete personalizado salvo.',
      );
      return true;
    } on Failure catch (failure) {
      state = NotificationActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = NotificationActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível criar o lembrete.',
        ),
      );
      return false;
    }
  }

  Future<void> toggleRead({
    required String notificationId,
    required bool isRead,
  }) async {
    try {
      final uid = _requireUserId();
      await ref.read(notificationRepositoryProvider).markAsRead(
            userId: uid,
            notificationId: notificationId,
            isRead: isRead,
          );
    } on Failure catch (failure) {
      state = NotificationActionState(errorMessage: failure.message);
    } catch (error) {
      state = NotificationActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Erro ao atualizar notificação.',
        ),
      );
    }
  }

  Future<void> markAllAsRead() async {
    state = const NotificationActionState(isLoading: true);
    try {
      final uid = _requireUserId();
      await ref.read(notificationRepositoryProvider).markAllAsRead(uid);
      state = const NotificationActionState(
        successMessage: 'Todas as notificações foram marcadas como lidas.',
      );
    } on Failure catch (failure) {
      state = NotificationActionState(errorMessage: failure.message);
    } catch (error) {
      state = NotificationActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Erro ao marcar notificações como lidas.',
        ),
      );
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      final uid = _requireUserId();
      await ref.read(notificationRepositoryProvider).deleteNotification(
            userId: uid,
            notificationId: notificationId,
          );
      state = const NotificationActionState(
        successMessage: 'Notificação removida.',
      );
    } on Failure catch (failure) {
      state = NotificationActionState(errorMessage: failure.message);
    } catch (error) {
      state = NotificationActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Erro ao excluir notificação.',
        ),
      );
    }
  }

  Future<void> enablePushNotifications(UserProfile currentProfile) async {
    state = const NotificationActionState(isLoading: true);
    try {
      final uid = _requireUserId();
      final service = ref.read(notificationServiceProvider);
      final result = await service.requestPermissionAndToken();

      if (result.token == null) {
        state = NotificationActionState(
          errorMessage: result.statusMessage ??
              'Não foi possível ativar notificações push neste dispositivo.',
        );
        return;
      }

      await ref.read(notificationRepositoryProvider).registerDeviceToken(
            userId: uid,
            token: result.token!,
            platform: service.platformKey,
          );

      await ref
          .read(profileControllerProvider.notifier)
          .updateNotificationPreferences(
            currentProfile: currentProfile,
            pushNotificationsEnabled: true,
          );

      state = const NotificationActionState(
        successMessage: 'Dispositivo registrado para alertas Push (FCM).',
      );
    } on Failure catch (failure) {
      state = NotificationActionState(errorMessage: failure.message);
    } catch (error) {
      state = NotificationActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Erro ao ativar notificações Push (FCM).',
        ),
      );
    }
  }
}

final notificationControllerProvider =
    NotifierProvider<NotificationController, NotificationActionState>(
  NotificationController.new,
);
