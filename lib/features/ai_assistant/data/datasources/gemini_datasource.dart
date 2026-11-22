import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/platform_info.dart';
import '../../../../firebase_options.dart';

/// Fonte de dados que se comunica exclusivamente com a Cloud Function autenticada
/// `aiAssistantQuery` (nunca expondo chave Gemini no aplicativo Flutter).
class GeminiDatasource {
  GeminiDatasource({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    http.Client? httpClient,
  })  : _functions = functions,
        _auth = auth,
        _httpClient = httpClient;

  static const String functionName = 'aiAssistantQuery';
  static const String region = 'us-central1';

  final FirebaseFunctions? _functions;
  final FirebaseAuth? _auth;
  final http.Client? _httpClient;

  Future<Map<String, dynamic>> invokeAssistantEndpoint({
    required Map<String, dynamic> payload,
  }) async {
    if (_functions == null && Firebase.apps.isEmpty) {
      throw const AppException(
        'Conecte o Firebase e faça login para utilizar o Assistente Financeiro IA.',
        code: 'ai-firebase-not-ready',
      );
    }

    final auth = _auth ?? FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      throw const AuthFailure(
        'Faça login para conversar com o Assistente Financeiro IA.',
      );
    }

    if (_functions != null || PlatformInfo.supportsNativeCloudFunctions) {
      return _invokeViaNativeCallable(payload);
    }

    final idToken = await currentUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthFailure(
        'Não foi possível obter o token de autenticação do usuário.',
      );
    }
    return _invokeViaHttpsCallableProtocol(payload, idToken);
  }

  Future<Map<String, dynamic>> _invokeViaNativeCallable(
    Map<String, dynamic> payload,
  ) async {
    try {
      final functions =
          _functions ?? FirebaseFunctions.instanceFor(region: region);
      final callable = functions.httpsCallable(
        functionName,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      final response = await callable.call<dynamic>(payload);
      return _normalizeResponseMap(response.data);
    } on FirebaseFunctionsException catch (e) {
      throw _mapFunctionsException(e);
    } on Failure {
      rethrow;
    } on TimeoutException {
      throw const NetworkFailure(
        'Tempo limite excedido ao consultar o Assistente IA. Tente novamente.',
      );
    } catch (error) {
      throw UnexpectedFailure(
        'Erro ao consultar o Assistente IA: $error',
      );
    }
  }

  Future<Map<String, dynamic>> _invokeViaHttpsCallableProtocol(
    Map<String, dynamic> payload,
    String idToken,
  ) async {
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    final uri = Uri.https(
      '$region-$projectId.cloudfunctions.net',
      '/$functionName',
    );
    final client = _httpClient ?? http.Client();
    final shouldCloseClient = _httpClient == null;

    try {
      final res = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'data': payload}),
          )
          .timeout(const Duration(seconds: 60));

      final decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;
      if (decoded is Map && decoded['error'] is Map) {
        final err = Map<String, dynamic>.from(decoded['error'] as Map);
        final status = (err['status'] as String?) ?? '';
        final message =
            (err['message'] as String?) ?? 'Erro na chamada à IA Gemini.';
        throw _mapErrorCodeAndMessage(status, message);
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw UnexpectedFailure(
          'Falha HTTP (${res.statusCode}) ao consultar o Assistente IA.',
        );
      }

      if (decoded is Map && decoded.containsKey('result')) {
        return _normalizeResponseMap(decoded['result']);
      }
      return _normalizeResponseMap(decoded);
    } on Failure {
      rethrow;
    } on TimeoutException {
      throw const NetworkFailure(
        'Tempo limite excedido ao consultar o Assistente IA. Tente novamente.',
      );
    } catch (error) {
      throw UnexpectedFailure(
        'Não foi possível conectar ao Assistente IA: $error',
      );
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }

  Map<String, dynamic> _normalizeResponseMap(dynamic raw) {
    return normalizePayloadMap(raw);
  }

  /// Converte recursivamente qualquer `Map<Object?, Object?>` (retornado pelo
  /// canal nativo/web de `cloud_functions`) em `Map<String, dynamic>`.
  static Map<String, dynamic> normalizePayloadMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(
        raw.map((key, value) => MapEntry(key.toString(), deepConvert(value))),
      );
    }
    throw const FormatException('Resposta inválida recebida da Cloud Function.');
  }

  static dynamic deepConvert(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((k, v) => MapEntry(k.toString(), deepConvert(v))),
      );
    }
    if (value is List) {
      return value.map(deepConvert).toList(growable: false);
    }
    return value;
  }

  Failure _mapFunctionsException(FirebaseFunctionsException e) {
    final fallback =
        (e.message ?? '').trim().isEmpty ? 'Falha no Assistente IA.' : e.message!.trim();
    return _mapErrorCodeAndMessage(e.code, fallback);
  }

  Failure _mapErrorCodeAndMessage(String rawCode, String message) {
    final code = rawCode.trim().toLowerCase().replaceAll('_', '-');
    return switch (code) {
      'unauthenticated' => AuthFailure(message, code: code),
      'permission-denied' ||
      'failed-precondition' ||
      'invalid-argument' ||
      'resource-exhausted' =>
        ValidationFailure(message, code: code),
      'unavailable' || 'deadline-exceeded' => NetworkFailure(message),
      _ => UnexpectedFailure(message),
    };
  }
}
