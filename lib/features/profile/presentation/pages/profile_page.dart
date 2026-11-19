import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../authentication/application/controllers/auth_controller.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../application/controllers/profile_controller.dart';
import '../../application/providers/profile_providers.dart';
import '../../domain/entities/user_profile.dart';

/// Tela completa de Perfil do Usuário:
/// edição de dados, moeda padrão, idioma, primeiro dia do mês, senha e exclusão.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedCurrency = 'BRL';
  String _selectedLocale = 'pt_BR';
  int _selectedMonthStartDay = 1;
  int _selectedReminderDays = 3;
  String? _hydratedUid;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncFormFromProfile(UserProfile profile) {
    if (_hydratedUid == profile.uid &&
        _nameController.text.isNotEmpty) {
      return;
    }
    _hydratedUid = profile.uid;
    _nameController.text = profile.displayName;
    _selectedCurrency = profile.defaultCurrency;
    _selectedLocale = profile.localeCode;
    _selectedMonthStartDay = profile.monthStartDay;
    _selectedReminderDays = profile.reminderDaysBefore;
  }

  Future<void> _saveProfile(UserProfile currentProfile) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await ref.read(profileControllerProvider.notifier).updateProfile(
          currentProfile: currentProfile,
          displayName: _nameController.text,
          defaultCurrency: _selectedCurrency,
          localeCode: _selectedLocale,
          monthStartDay: _selectedMonthStartDay,
          reminderDaysBefore: _selectedReminderDays,
        );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Alterar senha'),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha atual'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Informe a senha atual.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nova senha'),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Mínimo de 6 caracteres.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Confirmar nova senha'),
                  validator: (v) =>
                      v != newCtrl.text ? 'As senhas não coincidem.' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (dialogFormKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Atualizar'),
            ),
          ],
        );
      },
    );

    if (submitted == true && mounted) {
      await ref.read(profileControllerProvider.notifier).changePassword(
            currentPassword: currentCtrl.text,
            newPassword: newCtrl.text,
          );
    }

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  Future<void> _showDeleteAccountDialog({required bool hasPassword}) async {
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir conta permanentemente'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esta ação removerá sua conta e todos os seus dados financeiros armazenados no Firebase. Não é possível desfazer.',
                ),
                if (hasPassword) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirme sua senha atual',
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Informe sua senha para confirmar.'
                        : null,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.expense,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Excluir conta'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final deleted = await ref
          .read(profileControllerProvider.notifier)
          .deleteAccount(
            currentPassword: hasPassword ? passwordCtrl.text : null,
          );
      if (deleted && mounted) {
        context.go(AppRoutes.login);
      }
    }

    passwordCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(currentAuthUserProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final actionState = ref.watch(profileControllerProvider);
    final theme = Theme.of(context);

    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil do Usuário')),
        body: EmptyStateView(
          icon: Icons.person_outline_rounded,
          title: 'Nenhuma sessão ativa',
          description:
              'Entre com sua conta Firebase para editar seu perfil, moeda padrão e preferências mensais.',
          actionLabel: 'Ir para Login',
          onAction: () => context.push(AppRoutes.login),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil do Usuário')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => EmptyStateView(
          icon: Icons.cloud_off_rounded,
          title: 'Erro ao carregar perfil',
          description: err.toString(),
        ),
        data: (profile) {
          final effectiveProfile = profile ??
              UserProfile(
                uid: authUser.uid,
                displayName: authUser.displayName,
                email: authUser.email,
                photoUrl: authUser.photoUrl,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

          _syncFormFromProfile(effectiveProfile);
          final initials = effectiveProfile.displayName.trim().isNotEmpty
              ? effectiveProfile.displayName.trim()[0].toUpperCase()
              : 'U';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.primaryLight,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    effectiveProfile.displayName,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    effectiveProfile.email,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (authUser.hasGoogleProvider)
                                        const StatusBadge(
                                          label: 'Google',
                                          color: AppColors.transfer,
                                        ),
                                      if (authUser.hasPasswordProvider)
                                        const StatusBadge(
                                          label: 'E-mail e senha',
                                          color: AppColors.income,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (actionState.errorMessage != null) ...[
                      _ProfileBanner(
                        message: actionState.errorMessage!,
                        color: AppColors.expense,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (actionState.successMessage != null) ...[
                      _ProfileBanner(
                        message: actionState.successMessage!,
                        color: AppColors.income,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Dados e Preferências Financeiras',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Nome completo',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Informe seu nome.'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                value: _selectedCurrency,
                                decoration: const InputDecoration(
                                  labelText: 'Moeda padrão',
                                  prefixIcon: Icon(Icons.attach_money_rounded),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'BRL',
                                    child: Text('Real Brasileiro (BRL)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'USD',
                                    child: Text('Dólar Americano (USD)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'EUR',
                                    child: Text('Euro (EUR)'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedCurrency = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                value: _selectedLocale,
                                decoration: const InputDecoration(
                                  labelText: 'Idioma',
                                  prefixIcon: Icon(Icons.language_rounded),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'pt_BR',
                                    child: Text('Português (Brasil)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'en_US',
                                    child: Text('English (US)'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedLocale = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<int>(
                                value: _selectedMonthStartDay,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Primeiro dia do mês para relatórios',
                                  prefixIcon:
                                      Icon(Icons.calendar_today_outlined),
                                ),
                                items: [
                                  for (var day = 1; day <= 28; day++)
                                    DropdownMenuItem(
                                      value: day,
                                      child: Text(
                                        'Dia $day',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(
                                        () => _selectedMonthStartDay = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<int>(
                                value: [1, 2, 3, 5, 7, 15]
                                        .contains(_selectedReminderDays)
                                    ? _selectedReminderDays
                                    : 3,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Antecedência padrão para alertas',
                                  prefixIcon: Icon(
                                    Icons.notifications_active_outlined,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text('1 dia antes do vencimento'),
                                  ),
                                  DropdownMenuItem(
                                    value: 2,
                                    child: Text('2 dias antes do vencimento'),
                                  ),
                                  DropdownMenuItem(
                                    value: 3,
                                    child: Text('3 dias antes do vencimento'),
                                  ),
                                  DropdownMenuItem(
                                    value: 5,
                                    child: Text('5 dias antes do vencimento'),
                                  ),
                                  DropdownMenuItem(
                                    value: 7,
                                    child: Text('7 dias antes do vencimento'),
                                  ),
                                  DropdownMenuItem(
                                    value: 15,
                                    child: Text('15 dias antes do vencimento'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedReminderDays = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: actionState.isLoading
                                    ? null
                                    : () => _saveProfile(effectiveProfile),
                                icon: actionState.isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: const Text('Salvar alterações'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Column(
                        children: [
                          if (authUser.hasPasswordProvider)
                            ListTile(
                              leading: const Icon(Icons.password_rounded),
                              title: const Text('Alterar senha'),
                              subtitle: const Text(
                                'Exige confirmação da senha atual',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: actionState.isLoading
                                  ? null
                                  : _showChangePasswordDialog,
                            ),
                          if (authUser.hasPasswordProvider)
                            const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.logout_rounded),
                            title: const Text('Sair da conta'),
                            onTap: actionState.isLoading
                                ? null
                                : () async {
                                    await ref
                                        .read(authControllerProvider.notifier)
                                        .signOut();
                                    if (mounted) {
                                      context.go(AppRoutes.login);
                                    }
                                  },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.delete_forever_outlined,
                              color: AppColors.expense,
                            ),
                            title: const Text(
                              'Excluir conta e dados',
                              style: TextStyle(color: AppColors.expense),
                            ),
                            subtitle: const Text(
                              'Remove permanentemente seus dados no Firestore e sua autenticação',
                            ),
                            onTap: actionState.isLoading
                                ? null
                                : () => _showDeleteAccountDialog(
                                      hasPassword: authUser.hasPasswordProvider,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({
    required this.message,
    required this.color,
  });

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
