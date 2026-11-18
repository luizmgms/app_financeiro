import 'package:firebase_core/firebase_core.dart';
import 'failures.dart';

/// Mapeia exceções do ecossistema Firebase para falhas de domínio legíveis.
Failure mapFirebaseFailure(
  FirebaseException error, {
  required String fallbackMessage,
}) {
  final rawDetails = error.message?.trim();
  final code = error.code.trim().toLowerCase();
  final isStorage = error.plugin == 'firebase_storage';

  switch (code) {
    case 'unavailable':
    case 'network-request-failed':
    case 'deadline-exceeded':
      return const NetworkFailure();
    case 'unauthenticated':
      return const AuthFailure(
        'Sessão expirada ou usuário não autenticado. Faça login novamente.',
        code: 'unauthenticated',
      );
    case 'permission-denied':
      return ValidationFailure(
        rawDetails != null && rawDetails.isNotEmpty
            ? 'Permissão negada ao gravar os dados (${error.code}): $rawDetails'
            : 'Permissão negada ao gravar os dados (${error.code}).',
        code: error.code,
      );
    case 'unauthorized':
    case 'storage/unauthorized':
      return const StorageFailure(
        'Sem permissão para acessar ou enviar o anexo no Firebase Storage.',
        code: 'unauthorized',
      );
    case 'canceled':
    case 'storage/canceled':
      return const StorageFailure(
        'O envio do anexo foi cancelado.',
        code: 'canceled',
      );
    default:
      final message = rawDetails != null && rawDetails.isNotEmpty
          ? (code.isNotEmpty ? '$rawDetails (${error.code})' : rawDetails)
          : (code.isNotEmpty
              ? '$fallbackMessage (${error.code})'
              : fallbackMessage);
      if (isStorage) {
        return StorageFailure(
          message,
          code: error.code.isEmpty ? null : error.code,
        );
      }
      return UnexpectedFailure(message);
  }
}

/// Converte exceções inesperadas em mensagem informativa sem mascarar o motivo.
String formatUnexpectedFailureMessage(
  Object error, {
  required String fallbackMessage,
}) {
  if (error is Failure) {
    return error.message;
  }
  if (error is FirebaseException) {
    return mapFirebaseFailure(error, fallbackMessage: fallbackMessage).message;
  }
  final raw = error.toString().trim();
  if (raw.isEmpty) {
    return fallbackMessage;
  }
  return '$fallbackMessage ($raw)';
}
