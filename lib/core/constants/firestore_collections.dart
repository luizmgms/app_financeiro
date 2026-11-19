/// Constantes de coleções do Cloud Firestore conforme modelagem por usuário.
abstract final class FirestoreCollections {
  static const String users = 'users';
  static const String profile = 'profile';
  static const String accounts = 'accounts';
  static const String creditCards = 'credit_cards';
  static const String transactions = 'transactions';
  static const String categories = 'categories';
  static const String recurring = 'recurring';
  static const String installments = 'installments';
  static const String invoices = 'invoices';
  static const String budgets = 'budgets';
  static const String notifications = 'notifications';
  static const String notificationDevices = 'notification_devices';
  static const String aiInteractions = 'ai_interactions';

  /// Retorna o caminho base da subcoleção isolada do usuário autenticado.
  static String userSubcollection(String userId, String collectionName) {
    assert(userId.isNotEmpty, 'userId não pode ser vazio');
    assert(collectionName.isNotEmpty, 'collectionName não pode ser vazio');
    return '$users/$userId/$collectionName';
  }
}
