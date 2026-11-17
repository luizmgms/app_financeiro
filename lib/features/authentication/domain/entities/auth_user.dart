import 'package:equatable/equatable.dart';

/// Usuário autenticado na sessão atual.
class AuthUser extends Equatable {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.emailVerified = false,
    this.providerIds = const [],
  });

  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool emailVerified;
  final List<String> providerIds;

  bool get hasPasswordProvider => providerIds.contains('password');
  bool get hasGoogleProvider => providerIds.contains('google.com');

  @override
  List<Object?> get props => [
        uid,
        email,
        displayName,
        photoUrl,
        emailVerified,
        providerIds,
      ];
}
