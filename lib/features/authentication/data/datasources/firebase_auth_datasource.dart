import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/platform_info.dart';
import '../../domain/entities/auth_user.dart';

/// Fonte de dados remota conectada ao Firebase Authentication e Google Sign-In.
class FirebaseAuthDatasource {
  FirebaseAuthDatasource({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn;

  final FirebaseAuth? _firebaseAuth;
  final GoogleSignIn? _googleSignIn;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;
  GoogleSignIn get _google => _googleSignIn ?? GoogleSignIn();

  Stream<AuthUser?> authStateChanges() {
    return _auth.authStateChanges().map(_mapUser);
  }

  AuthUser? get currentUser => _mapUser(_auth.currentUser);

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = _mapUser(credential.user);
      if (user == null) {
        throw const AuthFailure('Não foi possível obter os dados da sessão.');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  Future<AuthUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthFailure('Erro ao criar usuário no Firebase Auth.');
      }
      await firebaseUser.updateDisplayName(name.trim());
      await firebaseUser.reload();
      final refreshed = _mapUser(_auth.currentUser ?? firebaseUser);
      if (refreshed == null) {
        throw const AuthFailure('Usuário criado, mas sessão indisponível.');
      }
      return refreshed;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  Future<AuthUser> signInWithGoogle() async {
    if (!PlatformInfo.supportsNativeGoogleSignIn) {
      throw const AuthFailure(
        'Login com Google não está disponível nesta plataforma desktop. Utilize e-mail e senha.',
        code: 'unsupported-platform',
      );
    }

    try {
      if (kIsWeb) {
        final credential = await _auth.signInWithPopup(GoogleAuthProvider());
        final user = _mapUser(credential.user);
        if (user == null) {
          throw const AuthFailure('Login com Google não retornou usuário.');
        }
        return user;
      }

      final googleAccount = await _google.signIn();
      if (googleAccount == null) {
        throw const AuthFailure(
          'Login com Google cancelado pelo usuário.',
          code: 'cancelled',
        );
      }

      final googleAuth = await googleAccount.authentication;
      final oauthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = _mapUser(userCredential.user);
      if (user == null) {
        throw const AuthFailure('Falha ao autenticar conta Google.');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw AuthFailure('Não foi possível concluir o login com Google: $e');
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Nenhum usuário autenticado.');
    }
    try {
      await user.updateDisplayName(displayName.trim());
      await user.reload();
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  Future<void> reauthenticateWithPassword(String currentPassword) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthFailure('Sessão inválida para reautenticação.');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Nenhum usuário autenticado.');
    }
    try {
      await reauthenticateWithPassword(currentPassword);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  Future<void> deleteCurrentAuthUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Nenhum usuário autenticado.');
    }
    try {
      await user.delete();
      if (!kIsWeb && PlatformInfo.supportsNativeGoogleSignIn) {
        try {
          await _google.signOut();
        } catch (_) {
          // Ignora erro caso não tenha sessão Google ativa.
        }
      }
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb && PlatformInfo.supportsNativeGoogleSignIn) {
      try {
        await _google.signOut();
      } catch (_) {
        // Ignora erro caso o usuário não tenha entrado com Google.
      }
    }
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) return null;
    final email = user.email ?? '';
    final fallbackName =
        email.contains('@') ? email.split('@').first : 'Usuário';
    return AuthUser(
      uid: user.uid,
      email: email,
      displayName: (user.displayName?.trim().isNotEmpty == true)
          ? user.displayName!.trim()
          : fallbackName,
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
      providerIds: user.providerData
          .map((info) => info.providerId)
          .toList(growable: false),
    );
  }

  AuthFailure _mapAuthException(FirebaseAuthException error) {
    final message = switch (error.code) {
      'invalid-email' => 'O endereço de e-mail informado não é válido.',
      'user-disabled' => 'Esta conta foi desativada. Entre em contato com o suporte.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'E-mail ou senha incorretos.',
      'email-already-in-use' =>
        'Já existe uma conta cadastrada com este e-mail.',
      'weak-password' =>
        'A senha é muito fraca. Utilize pelo menos 6 caracteres.',
      'operation-not-allowed' =>
        'Este método de login ainda não está habilitado no Firebase Console.',
      'too-many-requests' =>
        'Muitas tentativas seguidas. Aguarde alguns instantes e tente novamente.',
      'network-request-failed' =>
        'Falha de conexão com a internet. Verifique sua rede.',
      'requires-recent-login' =>
        'Por segurança, confirme sua senha atual antes de concluir esta ação.',
      'popup-closed-by-user' =>
        'Janela de autenticação fechada antes de concluir o login.',
      _ => error.message ?? 'Erro de autenticação (${error.code}).',
    };
    return AuthFailure(message, code: error.code);
  }
}
