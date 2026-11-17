import 'package:equatable/equatable.dart';

/// Falha tipada exposta pelas camadas de domínio e aplicação.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'Sem conexão no momento. Verifique sua internet.',
  ]) : super(code: 'network-error');
}

final class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

final class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.code});
}

final class NotConfiguredFailure extends Failure {
  const NotConfiguredFailure([
    super.message = 'Serviço Firebase ainda não configurado neste ambiente.',
  ]) : super(code: 'not-configured');
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([
    super.message = 'Ocorreu um erro inesperado ao processar a operação.',
  ]) : super(code: 'unexpected');
}
