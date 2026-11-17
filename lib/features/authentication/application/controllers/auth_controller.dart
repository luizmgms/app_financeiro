import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../providers/auth_providers.dart';

class AuthActionState extends Equatable {
  const AuthActionState({
    this.isLoading = false,
    this.errorMessage,
    this.infoMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? infoMessage;

  @override
  List<Object?> get props => [isLoading, errorMessage, infoMessage];
}

/// Controller responsável pelas operações de autenticação sem lógica nas telas.
class AuthController extends Notifier<AuthActionState> {
  @override
  AuthActionState build() => const AuthActionState();

  void clearMessages() {
    state = AuthActionState(isLoading: state.isLoading);
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AuthActionState(isLoading: true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final profileRepo = ref.read(profileRepositoryProvider);
      final user = await authRepo.signInWithEmail(
        email: email,
        password: password,
      );
      await profileRepo.ensureProfile(user: user);
      state = const AuthActionState();
      return true;
    } on Failure catch (failure) {
      state = AuthActionState(errorMessage: failure.message);
      return false;
    } catch (_) {
      state = const AuthActionState(
        errorMessage: 'Não foi possível entrar. Tente novamente.',
      );
      return false;
    }
  }

  Future<bool> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AuthActionState(isLoading: true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final profileRepo = ref.read(profileRepositoryProvider);
      final user = await authRepo.registerWithEmail(
        name: name,
        email: email,
        password: password,
      );
      await profileRepo.ensureProfile(user: user);
      state = const AuthActionState();
      return true;
    } on Failure catch (failure) {
      state = AuthActionState(errorMessage: failure.message);
      return false;
    } catch (_) {
      state = const AuthActionState(
        errorMessage: 'Não foi possível concluir o cadastro.',
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = const AuthActionState(isLoading: true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final profileRepo = ref.read(profileRepositoryProvider);
      final user = await authRepo.signInWithGoogle();
      await profileRepo.ensureProfile(user: user);
      state = const AuthActionState();
      return true;
    } on Failure catch (failure) {
      state = AuthActionState(errorMessage: failure.message);
      return false;
    } catch (_) {
      state = const AuthActionState(
        errorMessage: 'Erro ao autenticar com a conta Google.',
      );
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail({required String email}) async {
    state = const AuthActionState(isLoading: true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(
            email: email,
          );
      state = const AuthActionState(
        infoMessage:
            'Enviamos um link de redefinição de senha para o seu e-mail.',
      );
      return true;
    } on Failure catch (failure) {
      state = AuthActionState(errorMessage: failure.message);
      return false;
    } catch (_) {
      state = const AuthActionState(
        errorMessage: 'Não foi possível enviar o e-mail de recuperação.',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AuthActionState(isLoading: true);
    try {
      await ref.read(authRepositoryProvider).signOut();
      state = const AuthActionState();
    } on Failure catch (failure) {
      state = AuthActionState(errorMessage: failure.message);
    } catch (_) {
      state = const AuthActionState(
        errorMessage: 'Erro ao encerrar a sessão.',
      );
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthActionState>(
  AuthController.new,
);
