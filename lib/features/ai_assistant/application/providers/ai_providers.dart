import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/gemini_datasource.dart';
import '../../data/datasources/media_input_service.dart';
import '../../data/datasources/voice_input_service.dart';
import '../../data/repositories/ai_repository_impl.dart';
import '../../domain/repositories/ai_repository.dart';
import '../controllers/ai_assistant_controller.dart';

final geminiDatasourceProvider = Provider<GeminiDatasource>((ref) {
  return GeminiDatasource();
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepositoryImpl(ref.watch(geminiDatasourceProvider));
});

final voiceInputServiceProvider = Provider<VoiceInputService>((ref) {
  return SpeechToTextVoiceInputService();
});

final mediaInputServiceProvider = Provider<MediaInputService>((ref) {
  return ImagePickerMediaInputService();
});

final aiAssistantControllerProvider =
    NotifierProvider<AiAssistantController, AiAssistantState>(
  AiAssistantController.new,
);
