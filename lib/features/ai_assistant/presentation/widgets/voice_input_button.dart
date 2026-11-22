import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Botão de entrada por voz (microfone) com feedback visual de gravação ativa.
class VoiceInputButton extends StatelessWidget {
  const VoiceInputButton({
    super.key,
    required this.isListening,
    required this.enabled,
    required this.onPressed,
  });

  final bool isListening;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: isListening ? 'Parar ditado por voz' : 'Ditar por voz',
      onPressed: enabled ? onPressed : null,
      style: isListening
          ? IconButton.styleFrom(
              backgroundColor: AppColors.expense.withOpacity(0.16),
              foregroundColor: AppColors.expense,
            )
          : IconButton.styleFrom(
              backgroundColor: AppColors.aiAccent.withOpacity(0.14),
              foregroundColor: AppColors.aiAccent,
            ),
      icon: Icon(
        isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
      ),
    );
  }
}
