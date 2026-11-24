import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/firebase_bootstrap_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/platform_info.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../shared/providers/app_bootstrap_provider.dart';
import '../../../../shared/providers/locale_provider.dart';
import '../../../../shared/providers/theme_mode_provider.dart';
import '../../../authentication/application/controllers/auth_controller.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../../profile/application/controllers/profile_controller.dart';
import '../../../profile/application/providers/profile_providers.dart';

/// Página de configurações com sessão do usuário, alternância de tema (Material 3)
/// e preferências locais/nuvem.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final bootstrap = ref.watch(appBootstrapStateProvider);
    final authUser = ref.watch(currentAuthUserProvider);
    final userProfile = ref.watch(userProfileProvider).valueOrNull;
    final theme = Theme.of(context);
    final firebaseColor = switch (bootstrap.firebase.status) {
      FirebaseConnectionStatus.connected => AppColors.income,
      FirebaseConnectionStatus.awaitingConfiguration => AppColors.warning,
      FirebaseConnectionStatus.unsupportedPlatform => AppColors.transfer,
      FirebaseConnectionStatus.error => AppColors.expense,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: authUser != null
                          ? AppColors.primaryLight
                          : AppColors.warning.withOpacity(0.18),
                      child: Icon(
                        authUser != null
                            ? Icons.person_rounded
                            : Icons.lock_outline_rounded,
                        color: authUser != null
                            ? Colors.white
                            : AppColors.warning,
                      ),
                    ),
                    title: Text(
                      authUser != null
                          ? (userProfile?.displayName ?? authUser.displayName)
                          : 'Sessão não autenticada',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      authUser != null
                          ? '${authUser.email} • Moeda ${userProfile?.defaultCurrency ?? 'BRL'} • Dia inicial ${userProfile?.monthStartDay ?? 1}'
                          : 'Entre na sua conta para sincronizar dados no Firebase',
                    ),
                    trailing: authUser != null
                        ? OutlinedButton(
                            onPressed: () async {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .signOut();
                            },
                            child: const Text('Sair'),
                          )
                        : FilledButton(
                            onPressed: () => context.push(AppRoutes.login),
                            child: const Text('Entrar'),
                          ),
                    onTap: () => context.push(
                      authUser != null ? AppRoutes.profile : AppRoutes.login,
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
                          'Aparência (Material Design 3)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: MaterialStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 10),
                            ),
                          ),
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_outlined, size: 16),
                              label: Text(
                                'Sistema',
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_outlined, size: 16),
                              label: Text(
                                'Claro',
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_outlined, size: 16),
                              label: Text(
                                'Escuro',
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ],
                          selected: {themeMode},
                          onSelectionChanged: (selection) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(selection.first);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.language_rounded),
                        title: const Text('Idioma do aplicativo'),
                        subtitle: Text(
                          locale.languageCode == 'pt'
                              ? 'Português (Brasil) — Moeda padrão ${userProfile?.defaultCurrency ?? 'BRL'}'
                              : 'English (US)',
                        ),
                        trailing: DropdownButton<String>(
                          value: '${locale.languageCode}_${locale.countryCode}',
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                              value: 'pt_BR',
                              child: Text('pt_BR'),
                            ),
                            DropdownMenuItem(
                              value: 'en_US',
                              child: Text('en_US'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            final parts = value.split('_');
                            ref.read(localeProvider.notifier).setLocale(
                                  Locale(parts[0], parts[1]),
                                );
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Perfil do usuário'),
                        subtitle: const Text(
                          'Edição de perfil, alteração de senha, moeda e dia inicial do mês',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(AppRoutes.profile),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.category_outlined),
                        title: const Text('Categorias financeiras'),
                        subtitle: const Text(
                          'Gerenciar categorias personalizadas de receitas e despesas',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(AppRoutes.categories),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.repeat_rounded),
                        title: const Text('Contas recorrentes'),
                        subtitle: const Text(
                          'Receitas e despesas periódicas automáticas sem duplicidades',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(AppRoutes.recurring),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading:
                            const Icon(Icons.notifications_active_outlined),
                        title: const Text('Notificações e alertas'),
                        subtitle: const Text(
                          'Antecedência dos vencimentos, lembretes e Push (FCM)',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(AppRoutes.notifications),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.aiAccent,
                        ),
                        title: const Text('Privacidade e Assistente IA'),
                        subtitle: const Text(
                          'Somente metadados necessários são processados via Cloud Functions autenticadas.',
                        ),
                        trailing: IconButton(
                          tooltip: 'Abrir Assistente IA',
                          onPressed: () => context.push(AppRoutes.aiAssistant),
                          icon: const Icon(Icons.open_in_new_rounded),
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        value: userProfile?.aiAssistantEnabled ?? true,
                        onChanged: userProfile == null
                            ? null
                            : (enabled) {
                                ref
                                    .read(profileControllerProvider.notifier)
                                    .updateAiPreferences(
                                      currentProfile: userProfile,
                                      aiAssistantEnabled: enabled,
                                    );
                              },
                        title: const Text('Ativar Assistente Financeiro IA'),
                        subtitle: const Text(
                          'Permite interpretar texto, voz e comprovantes sempre com confirmação manual.',
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        value: userProfile?.aiShareFinancialContext ?? true,
                        onChanged: userProfile == null ||
                                !(userProfile.aiAssistantEnabled)
                            ? null
                            : (share) {
                                ref
                                    .read(profileControllerProvider.notifier)
                                    .updateAiPreferences(
                                      currentProfile: userProfile,
                                      aiShareFinancialContext: share,
                                    );
                              },
                        title: const Text(
                          'Consultas sobre dados reais do Firestore',
                        ),
                        subtitle: const Text(
                          'Autoriza ferramentas de leitura (resumos, faturas e metas) para perguntas no chat.',
                        ),
                      ),
                    ],
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
                          'Conexões Ativas e Diagnóstico',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StatusBadge(
                              label: bootstrap.firebase.isReady
                                  ? 'Sincronizado'
                                  : 'Esqueleto Etapa 0',
                              color: AppColors.primaryLight,
                              icon: Icons.verified_outlined,
                            ),
                            StatusBadge(
                              label: PlatformInfo.platformLabel,
                              color: AppColors.transfer,
                              icon: Icons.devices_outlined,
                            ),
                            StatusBadge(
                              label: bootstrap.localStorageInitialized
                                  ? 'Cache Hive ativo'
                                  : 'Cache Hive em memória',
                              color: AppColors.income,
                              icon: Icons.storage_outlined,
                            ),
                            StatusBadge(
                              label: bootstrap.firebase.isReady
                                  ? (bootstrap.firebase.usingEmulator
                                      ? 'Firebase Emulator'
                                      : 'Firebase conectado')
                                  : 'Firebase aguardando configuração',
                              color: firebaseColor,
                            ),
                            StatusBadge(
                              label: bootstrap.firebase.appCheckStatusLabel,
                              color: bootstrap.firebase.appCheckActive
                                  ? AppColors.income
                                  : AppColors.warning,
                              icon: Icons.verified_user_outlined,
                            ),
                            StatusBadge(
                              label: PlatformInfo.supportsNativeFcm
                                  ? 'FCM suportado'
                                  : 'FCM isolado nesta plataforma',
                              color: PlatformInfo.supportsNativeFcm
                                  ? AppColors.income
                                  : AppColors.credit,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.cloud_outlined,
                              size: 18,
                              color: firebaseColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                bootstrap.firebase.projectId != null
                                    ? '${bootstrap.firebase.message} Projeto: ${bootstrap.firebase.projectId}.'
                                    : bootstrap.firebase.message,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (bootstrap.firebase.errorDetails != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            bootstrap.firebase.errorDetails!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.expense,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
