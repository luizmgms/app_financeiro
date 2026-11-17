import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/status_badge.dart';

/// Esqueleto visual da tela do Assistente Financeiro IA (Módulo 23 — Etapa 6).
class AiAssistantPage extends StatelessWidget {
  const AiAssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistente Financeiro IA'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const StatusBadge(
                                label: 'Etapa 6 • Google Gemini via Cloud Functions',
                                color: AppColors.aiAccent,
                                icon: Icons.auto_awesome_rounded,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Registro por texto, voz e fotografia com confirmação obrigatória',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'A chave Gemini permanecerá protegida no backend (Firebase Auth + Cloud Functions). '
                                'Nenhuma movimentação é gravada sem revisão e confirmação explícita do usuário.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Exemplos de comandos suportados na Etapa 6',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const _SamplePromptTile(
                                icon: Icons.chat_bubble_outline_rounded,
                                label: '"Comprei 350 reais de supermercado no cartão Nubank."',
                              ),
                              const _SamplePromptTile(
                                icon: Icons.mic_none_rounded,
                                label: '"Hoje gastei 58,90 na farmácia no crédito."',
                              ),
                              const _SamplePromptTile(
                                icon: Icons.document_scanner_outlined,
                                label: 'Foto de nota fiscal, cupom ou comprovante PIX.',
                              ),
                              const _SamplePromptTile(
                                icon: Icons.query_stats_rounded,
                                label: '"Quanto gastei com alimentação este mês?"',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: const Row(
                    children: [
                      IconButton(
                        tooltip: 'Câmera (Etapa 6)',
                        onPressed: null,
                        icon: Icon(Icons.photo_camera_outlined),
                      ),
                      IconButton(
                        tooltip: 'Galeria (Etapa 6)',
                        onPressed: null,
                        icon: Icon(Icons.attach_file_rounded),
                      ),
                      Expanded(
                        child: TextField(
                          enabled: false,
                          decoration: InputDecoration(
                            hintText:
                                'Disponível após conectar Firebase + Cloud Functions (Etapa 6)',
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Voz (Etapa 6)',
                        onPressed: null,
                        icon: Icon(Icons.mic_none_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SamplePromptTile extends StatelessWidget {
  const _SamplePromptTile({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.aiAccent),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
