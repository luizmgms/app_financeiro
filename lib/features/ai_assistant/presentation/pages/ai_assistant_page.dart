import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../accounts/application/providers/account_providers.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../credit_cards/application/providers/credit_card_providers.dart';
import '../../application/controllers/ai_assistant_controller.dart';
import '../../application/providers/ai_providers.dart';
import '../../domain/entities/ai_message.dart';
import '../../domain/services/ai_suggestion_validator.dart';
import '../widgets/chat_message.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/image_input_button.dart';
import '../widgets/voice_input_button.dart';

/// Interface conversacional e multimodal do Assistente Financeiro IA (Módulo 23).
class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({super.key});

  @override
  ConsumerState<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends ConsumerState<AiAssistantPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  static const _quickPrompts = <String>[
    'Gastei R\$ 45 no almoço',
    'Comprei R\$ 350 de supermercado no cartão',
    'Recebi R\$ 3.500 de salário',
    'Quanto gastei este mês?',
    'Qual cartão possui maior utilização?',
    'Quais contas vencem nos próximos dias?',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(aiAssistantControllerProvider.notifier).loadStatus();
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final controller = ref.read(aiAssistantControllerProvider.notifier);
    if (ref.read(aiAssistantControllerProvider).isListeningVoice) {
      await controller.stopVoiceInput();
    }

    // Se o usuário responder afirmativamente no chat enquanto há um cartão
    // pendente aguardando confirmação explícita, aciona o fluxo de confirmação/edição
    // em vez de reenviar ao Gemini em loop.
    const affirmativeReplies = <String>{
      'sim',
      'confirmo',
      'confirmar',
      'confirmar e salvar',
      'pode salvar',
      'ok',
      'salvar',
    };
    final normalizedReply = text
        .toLowerCase()
        .replaceAll(RegExp(r'[.!?,;:\s]+'), ' ')
        .trim();
    if (affirmativeReplies.contains(normalizedReply)) {
      final msgs = ref.read(aiAssistantControllerProvider).messages;
      AiMessage? pendingMsg;
      for (final msg in msgs.reversed) {
        if (msg.suggestion != null &&
            msg.resolution == AiSuggestionResolution.pending) {
          pendingMsg = msg;
          break;
        }
      }
      if (pendingMsg != null) {
        _inputController.clear();
        await _handleConfirmSuggestion(pendingMsg);
        return;
      }
    }

    _inputController.clear();
    await controller.sendTextMessage(text);
    _scrollToBottom();
  }

  Future<void> _handleToggleVoice() async {
    final controller = ref.read(aiAssistantControllerProvider.notifier);
    final isListening =
        ref.read(aiAssistantControllerProvider).isListeningVoice;

    if (isListening) {
      await controller.stopVoiceInput();
      return;
    }

    await controller.startVoiceInput(
      onTranscriptChanged: (recognizedText) {
        if (!mounted) return;
        _inputController.value = TextEditingValue(
          text: recognizedText,
          selection: TextSelection.collapsed(offset: recognizedText.length),
        );
      },
    );
  }

  Future<void> _handleReceiptPick({required bool fromCamera}) async {
    final caption = _inputController.text.trim();
    if (caption.isNotEmpty) {
      _inputController.clear();
    }
    await ref
        .read(aiAssistantControllerProvider.notifier)
        .pickAndAnalyzeReceipt(
          fromCamera: fromCamera,
          caption: caption.isEmpty ? null : caption,
        );
    _scrollToBottom();
  }

  Future<void> _openEditDialog(
    AiMessage message, {
    String submitLabel = 'Aplicar edição',
    bool saveAfterUpdate = false,
  }) async {
    final suggestion = message.suggestion;
    if (suggestion == null) return;

    final categories = ref.read(activeCategoriesProvider);
    final accounts = ref.read(activeAccountsProvider);
    final cards = ref.read(activeCreditCardsProvider);

    final updated = await showAiSuggestionEditDialog(
      context,
      initial: suggestion,
      categories: categories,
      accounts: accounts,
      cards: cards,
      submitLabel: submitLabel,
    );

    if (updated != null && mounted) {
      final controller = ref.read(aiAssistantControllerProvider.notifier);
      controller.updateSuggestion(message.id, updated);
      if (saveAfterUpdate) {
        await controller.confirmAndSaveSuggestion(message.id);
      }
    }
  }

  Future<void> _handleConfirmSuggestion(AiMessage message) async {
    final suggestion = message.suggestion;
    if (suggestion == null) return;

    final categories = ref.read(activeCategoriesProvider);
    final accounts = ref.read(activeAccountsProvider);
    final cards = ref.read(activeCreditCardsProvider);

    final itemsToCheck =
        suggestion.splitIntoItems && suggestion.hasMultipleItems
            ? AiSuggestionValidator.expandSplitItems(suggestion)
            : [suggestion];

    String? missingErr;
    for (final item in itemsToCheck) {
      missingErr = AiSuggestionValidator.validateReadyToConfirm(
        item,
        accounts: accounts,
        cards: cards,
        categories: categories,
      );
      if (missingErr != null) break;
    }

    if (missingErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$missingErr Complete as informações para confirmar.'),
        ),
      );
      await _openEditDialog(
        message,
        submitLabel: 'Confirmar e salvar',
        saveAfterUpdate: true,
      );
      return;
    }

    await ref
        .read(aiAssistantControllerProvider.notifier)
        .confirmAndSaveSuggestion(message.id);
  }

  void _showPrivacyDialog(BuildContext context, AiAssistantState state) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Segurança e Privacidade do Assistente IA'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• As credenciais da API Google Gemini ficam protegidas exclusivamente no servidor (Cloud Functions autenticadas) e nunca no aplicativo.',
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Imagens de notas e comprovantes são processadas em memória para extração e descartadas sem armazenamento permanente pela IA.',
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Nenhum lançamento, transferência ou pagamento de fatura é salvo sem sua confirmação explícita.',
                ),
                const SizedBox(height: 12),
                Text(
                  'Modelo configurado: ${state.activeModelName}\n'
                  'Consultas restantes hoje: ${state.quota.remainingToday} de ${state.quota.dailyLimit}',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push(AppRoutes.settings);
            },
            child: const Text('Configurações'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiAssistantControllerProvider);
    final categories = ref.watch(activeCategoriesProvider);
    final accounts = ref.watch(activeAccountsProvider);
    final cards = ref.watch(activeCreditCardsProvider);
    final mediaService = ref.watch(mediaInputServiceProvider);
    final theme = Theme.of(context);

    ref.listen<AiAssistantState>(aiAssistantControllerProvider, (prev, next) {
      if (next.messages.length != prev?.messages.length) {
        _scrollToBottom();
      }
      if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!)),
        );
      }
    });

    final canInteract = state.aiAssistantEnabled && !state.isProcessing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistente Financeiro IA'),
        actions: [
          IconButton(
            tooltip: 'Segurança e privacidade da IA',
            onPressed: () => _showPrivacyDialog(context, state),
            icon: const Icon(Icons.verified_user_outlined),
          ),
          if (state.messages.isNotEmpty)
            IconButton(
              tooltip: 'Limpar conversa',
              onPressed: state.isProcessing
                  ? null
                  : () => ref
                      .read(aiAssistantControllerProvider.notifier)
                      .clearConversation(),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
              border: Border(
                bottom: BorderSide(color: theme.dividerColor.withOpacity(0.16)),
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(
                      label: state.aiAssistantEnabled
                          ? 'Gemini AI • Confirmação manual obrigatória'
                          : 'IA desativada nas configurações',
                      color: state.aiAssistantEnabled
                          ? AppColors.aiAccent
                          : AppColors.warning,
                      icon: Icons.auto_awesome_rounded,
                    ),
                    Text(
                      'Cota hoje: ${state.quota.remainingToday}/${state.quota.dailyLimit}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!state.aiAssistantEnabled)
            MaterialBanner(
              content: const Text(
                'O Assistente IA está desativado nas preferências de privacidade.',
              ),
              actions: [
                TextButton(
                  onPressed: () => context.push(AppRoutes.settings),
                  child: const Text('Ativar em Ajustes'),
                ),
              ],
            ),
          if (state.errorMessage != null)
            Container(
              width: double.infinity,
              color: AppColors.expense.withOpacity(0.10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: AppColors.expense,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.expense,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => ref
                            .read(aiAssistantControllerProvider.notifier)
                            .clearBanners(),
                        icon: const Icon(Icons.close_rounded, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: state.messages.isEmpty
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: _WelcomePlaceholder(
                          categoriesCount: categories.length,
                          accountsCount: accounts.length,
                          cardsCount: cards.length,
                          quickPrompts: _quickPrompts,
                          enabled: canInteract,
                          onSelectPrompt: (prompt) {
                            _inputController.clear();
                            ref
                                .read(aiAssistantControllerProvider.notifier)
                                .sendTextMessage(prompt);
                          },
                          onCaptureReceipt: () =>
                              _handleReceiptPick(fromCamera: false),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: ChatMessageBubble(
                            message: message,
                            isSavingSuggestion: state.isSavingSuggestion,
                            accounts: accounts,
                            cards: cards,
                            onConfirmSuggestion: () =>
                                _handleConfirmSuggestion(message),
                            onEditSuggestion: () => _openEditDialog(message),
                            onCancelSuggestion: () => ref
                                .read(aiAssistantControllerProvider.notifier)
                                .cancelSuggestion(message.id),
                            onUpdateSuggestion: (updated) => ref
                                .read(aiAssistantControllerProvider.notifier)
                                .updateSuggestion(message.id, updated),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (state.isListeningVoice)
            Container(
              width: double.infinity,
              color: AppColors.aiAccent.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.graphic_eq_rounded,
                        size: 18,
                        color: AppColors.aiAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ouvindo sua voz... revise a transcrição no campo abaixo antes de enviar.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.aiAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (state.isProcessing)
            const LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.aiAccent,
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.dividerColor.withOpacity(0.22)),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ImageInputButtons(
                        enabled: canInteract,
                        supportsCamera: mediaService.supportsCameraCapture,
                        onCaptureCamera: () =>
                            _handleReceiptPick(fromCamera: true),
                        onPickGallery: () =>
                            _handleReceiptPick(fromCamera: false),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          enabled: state.aiAssistantEnabled,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) {
                            if (canInteract) _handleSend();
                          },
                          decoration: const InputDecoration(
                            hintText:
                                'Digite, fale ou anexe uma nota fiscal...',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      VoiceInputButton(
                        isListening: state.isListeningVoice,
                        enabled: canInteract,
                        onPressed: _handleToggleVoice,
                      ),
                      const SizedBox(width: 4),
                      IconButton.filled(
                        tooltip: 'Enviar',
                        onPressed: canInteract ? _handleSend : null,
                        icon: const Icon(Icons.send_rounded),
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

class _WelcomePlaceholder extends StatelessWidget {
  const _WelcomePlaceholder({
    required this.categoriesCount,
    required this.accountsCount,
    required this.cardsCount,
    required this.quickPrompts,
    required this.enabled,
    required this.onSelectPrompt,
    required this.onCaptureReceipt,
  });

  final int categoriesCount;
  final int accountsCount;
  final int cardsCount;
  final List<String> quickPrompts;
  final bool enabled;
  final ValueChanged<String> onSelectPrompt;
  final VoidCallback onCaptureReceipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registre por texto, voz ou foto com revisão obrigatória',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Envie frases naturais, dite pelo microfone ou fotografe cupons fiscais e comprovantes. '
                  'Você também pode perguntar sobre seus gastos, faturas, orçamentos e parcelas.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Catálogo conectado: $categoriesCount categorias • $accountsCount contas • $cardsCount cartões',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Experimente agora',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final prompt in quickPrompts)
                      ActionChip(
                        avatar: const Icon(
                          Icons.auto_awesome_outlined,
                          size: 16,
                          color: AppColors.aiAccent,
                        ),
                        label: Text(prompt),
                        onPressed:
                            enabled ? () => onSelectPrompt(prompt) : null,
                      ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.document_scanner_outlined,
                        size: 16,
                        color: AppColors.primaryLight,
                      ),
                      label: const Text('Analisar nota/comprovante'),
                      onPressed: enabled ? onCaptureReceipt : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
