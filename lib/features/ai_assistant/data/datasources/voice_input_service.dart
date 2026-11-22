import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Abstração para reconhecimento de voz desacoplada da UI e testável com mocks.
abstract interface class VoiceInputService {
  bool get isPlatformSupported;

  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String errorMessage)? onError,
  });

  Future<void> startListening({
    required void Function(String recognizedText, bool isFinal) onResult,
  });

  Future<void> stopListening();

  Future<void> cancelListening();
}

class SpeechToTextVoiceInputService implements VoiceInputService {
  SpeechToTextVoiceInputService({SpeechToText? speechToText})
      : _speech = speechToText ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;

  @override
  bool get isPlatformSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String errorMessage)? onError,
  }) async {
    if (!isPlatformSupported) return false;
    if (_initialized) return true;

    try {
      final available = await _speech.initialize(
        onStatus: (status) => onStatus?.call(status),
        onError: (error) => onError?.call(error.errorMsg),
      );
      _initialized = available;
      return available;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> startListening({
    required void Function(String recognizedText, bool isFinal) onResult,
  }) async {
    if (!isPlatformSupported) {
      throw UnsupportedError(
        'Reconhecimento de voz nativo indisponível nesta plataforma desktop. Digite ou cole o texto.',
      );
    }

    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        throw StateError(
          'Permissão de microfone negada ou reconhecimento de voz indisponível.',
        );
      }
    }

    final localeId = await _resolvePortugueseLocale();

    await _speech.listen(
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
    );
  }

  /// Garante tag BCP-47 `pt-BR` para transcrição em Português (Brasil) no Android e Web,
  /// sem sobrescrever para inglês (`en-US`) quando o navegador/sistema listar apenas o idioma padrão.
  static String resolvePortugueseLocaleId(
    List<LocaleName> availableLocales, {
    bool preferHyphen = true,
  }) {
    const fallback = 'pt-BR';
    for (final locale in availableLocales) {
      final raw = locale.localeId.trim();
      final lower = raw.toLowerCase().replaceAll('_', '-');
      if (lower == 'pt-br') {
        return preferHyphen ? 'pt-BR' : raw;
      }
    }
    for (final locale in availableLocales) {
      final raw = locale.localeId.trim();
      final lower = raw.toLowerCase().replaceAll('_', '-');
      if (lower.startsWith('pt')) {
        return preferHyphen ? raw.replaceAll('_', '-') : raw;
      }
    }
    return fallback;
  }

  Future<String> _resolvePortugueseLocale() async {
    try {
      final locales = await _speech.locales();
      final preferHyphen =
          kIsWeb || defaultTargetPlatform == TargetPlatform.android;
      return resolvePortugueseLocaleId(
        locales,
        preferHyphen: preferHyphen,
      );
    } catch (_) {
      return 'pt-BR';
    }
  }

  @override
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  @override
  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
