/// Exceção base da camada de dados e infraestrutura do aplicativo.
class AppException implements Exception {
  const AppException(
    this.message, {
    this.code,
    this.cause,
  });

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() =>
      'AppException(code: $code, message: $message, cause: $cause)';
}

class FirebaseNotConfiguredException extends AppException {
  const FirebaseNotConfiguredException()
      : super(
          'Firebase ainda não configurado neste projeto. '
          'Execute "flutterfire configure" para gerar firebase_options.dart.',
          code: 'firebase-not-configured',
        );
}
