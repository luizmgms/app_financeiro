import 'dart:ui';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/providers/locale_provider.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/profile_providers.dart';

class ProfileActionState extends Equatable {
  const ProfileActionState({
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

/// Controller para edição de perfil, preferências, alteração de senha e exclusão da conta.
class ProfileController extends Notifier<ProfileActionState> {
  @override
  ProfileActionState build() => const ProfileActionState();

  void clearMessages() {
    state = ProfileActionState(isLoading: state.isLoading);
  }

  Future<bool> updateProfile({
    required UserProfile currentProfile,
    required String displayName,
    required String defaultCurrency,
    required String localeCode,
    required int monthStartDay,
    int? reminderDaysBefore,
    bool? notificationsEnabled,
    bool? pushNotificationsEnabled,
  }) async {
    state = const ProfileActionState(isLoading: true);
    try {
      final trimmedName = displayName.trim();
      if (trimmedName.isEmpty) {
        state = const ProfileActionState(
          errorMessage: 'Informe um nome válido para o perfil.',
        );
        return false;
      }

      final authRepo = ref.read(authRepositoryProvider);
      final profileRepo = ref.read(profileRepositoryProvider);

      if (trimmedName != currentProfile.displayName) {
        await authRepo.updateDisplayName(trimmedName);
      }

      final updated = currentProfile.copyWith(
        displayName: trimmedName,
        defaultCurrency: defaultCurrency,
        localeCode: localeCode,
        monthStartDay: monthStartDay.clamp(1, 28),
        reminderDaysBefore:
            (reminderDaysBefore ?? currentProfile.reminderDaysBefore)
                .clamp(1, 30),
        notificationsEnabled:
            notificationsEnabled ?? currentProfile.notificationsEnabled,
        pushNotificationsEnabled:
            pushNotificationsEnabled ?? currentProfile.pushNotificationsEnabled,
        updatedAt: DateTime.now(),
      );

      await profileRepo.updateProfile(updated);

      final parts = localeCode.split('_');
      if (parts.length == 2) {
        await ref
            .read(localeProvider.notifier)
            .setLocale(Locale(parts[0], parts[1]));
      }

      state = const ProfileActionState(
        successMessage: 'Perfil e preferências atualizados com sucesso.',
      );
      return true;
    } on Failure catch (failure) {
      state = ProfileActionState(errorMessage: failure.message);
      return false;
    } catch (_) {
      state = const ProfileActionState(
        errorMessage: 'Não foi possível salvar as alterações do perfil.',
      );
      return false;
    }
  }

  Future<bool> updateNotificationPreferences({
    required UserProfile currentProfile,
    int? reminderDaysBefore,
    bool? notificationsEnabled,
    bool? pushNotificationsEnabled,
  }) async {
    state = const ProfileActionState(isLoading: true);
    try {
      final updated = currentProfile.copyWith(
        reminderDaysBefore:
            (reminderDaysBefore ?? currentProfile.reminderDaysBefore)
                .clamp(1, 30),
        notificationsEnabled:
            notificationsEnabled ?? currentProfile.notificationsEnabled,
        pushNotificationsEnabled:
            pushNotificationsEnabled ?? currentProfile.pushNotificationsEnabled,
        updatedAt: DateTime.now(),
      );

      await ref.read(profileRepositoryProvider).updateProfile(updated);
      state = const ProfileActionState(
        successMessage: 'Preferências de alertas atualizadas.',
      );
      return true;
    } on Failure catch (failure) {
      state = ProfileActionState(errorMessage: failure.message);
      return false;
    } catch (_) {
      state = const ProfileActionState(
        errorMessage: 'Não foi possível atualizar preferências de notificações.',
      );
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = const ProfileActionState(isLoading: true);
    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      state = const ProfileActionState(
        successMessage: 'Senha alterada com sucesso.',
      );
      return true;
    } on Failure catch (failure) {
      state = ProfileActionState(errorMessage: failure.message);
      return false;
    } catch (_) {
      state = const ProfileActionState(
        errorMessage: 'Não foi possível alterar a senha.',
      );
      return false;
    }
  }

  /// Exclui primeiro todos os dados do usuário no Firestore enquanto a sessão
  /// ainda está autenticada e, em seguida, remove a conta no Firebase Auth.
  Future<bool> deleteAccount({String? currentPassword}) async {
    state = const ProfileActionState(isLoading: true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final profileRepo = ref.read(profileRepositoryProvider);
      final user = authRepo.currentUser;
      if (user == null) {
        state = const ProfileActionState(
          errorMessage: 'Nenhum usuário autenticado.',
        );
        return false;
      }

      if (currentPassword != null && currentPassword.isNotEmpty) {
        await authRepo.reauthenticateWithPassword(currentPassword);
      }

      await profileRepo.deleteUserData(user.uid);
      await authRepo.deleteCurrentAuthUser();

      state = const ProfileActionState();
      return true;
    } on Failure catch (failure) {
      state = ProfileActionState(errorMessage: failure.message);
      return false;
    } catch (_) {
      state = const ProfileActionState(
        errorMessage: 'Não foi possível excluir a conta neste momento.',
      );
      return false;
    }
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileActionState>(
  ProfileController.new,
);
