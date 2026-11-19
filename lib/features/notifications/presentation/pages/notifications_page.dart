import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/platform_info.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../../profile/application/controllers/profile_controller.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../application/controllers/notification_controller.dart';
import '../../application/providers/notification_providers.dart';
import '../../domain/entities/app_notification_entity.dart';
import '../widgets/custom_reminder_dialog.dart';

/// Central de Notificações e Alertas Financeiros com configuração de antecedência,
/// lembretes personalizados e suporte a FCM com guarda por plataforma.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  String _filter = 'all';

  IconData _iconForType(NotificationType type) {
    return switch (type) {
      NotificationType.overduePayable => Icons.warning_amber_rounded,
      NotificationType.upcomingPayable => Icons.event_note_rounded,
      NotificationType.invoiceDue => Icons.credit_card_rounded,
      NotificationType.budgetWarning ||
      NotificationType.budgetExceeded =>
        Icons.pie_chart_outline_rounded,
      NotificationType.expectedIncome => Icons.trending_up_rounded,
      NotificationType.customReminder => Icons.alarm_rounded,
    };
  }

  Color _colorForType(NotificationType type) {
    return switch (type) {
      NotificationType.overduePayable ||
      NotificationType.budgetExceeded =>
        AppColors.expense,
      NotificationType.upcomingPayable ||
      NotificationType.budgetWarning =>
        AppColors.warning,
      NotificationType.invoiceDue => AppColors.credit,
      NotificationType.expectedIncome => AppColors.income,
      NotificationType.customReminder => AppColors.transfer,
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NotificationActionState>(notificationControllerProvider,
        (prev, next) {
      if (!mounted) return;
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.expense,
          ),
        );
      } else if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!)),
        );
      }
    });

    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final authUser = ref.watch(currentAuthUserProvider);
    final notifState = ref.watch(notificationControllerProvider);
    final service = ref.watch(notificationServiceProvider);
    final isCompact = MediaQuery.of(context).size.width < 680;
    final theme = Theme.of(context);

    final effectiveProfile = profile ??
        (authUser != null
            ? UserProfile(
                uid: authUser.uid,
                displayName: authUser.displayName,
                email: authUser.email,
                photoUrl: authUser.photoUrl,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              )
            : null);

    final reminderDays = effectiveProfile?.reminderDaysBefore ?? 3;
    final alertsEnabled = effectiveProfile?.notificationsEnabled ?? true;
    final pushEnabled = effectiveProfile?.pushNotificationsEnabled ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações e Alertas'),
        actions: [
          if (isCompact)
            IconButton(
              tooltip: 'Atualizar alertas',
              onPressed: notifState.isLoading
                  ? null
                  : () => ref
                      .read(notificationControllerProvider.notifier)
                      .syncAlerts(),
              icon: const Icon(Icons.refresh_rounded),
            )
          else
            OutlinedButton.icon(
              onPressed: notifState.isLoading
                  ? null
                  : () => ref
                      .read(notificationControllerProvider.notifier)
                      .syncAlerts(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Atualizar'),
            ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 4),
            if (isCompact)
              IconButton(
                tooltip: 'Marcar todas como lidas',
                onPressed: notifState.isLoading
                    ? null
                    : () => ref
                        .read(notificationControllerProvider.notifier)
                        .markAllAsRead(),
                icon: const Icon(Icons.done_all_rounded),
              )
            else
              TextButton.icon(
                onPressed: notifState.isLoading
                    ? null
                    : () => ref
                        .read(notificationControllerProvider.notifier)
                        .markAllAsRead(),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Marcar lidas'),
              ),
          ],
          const SizedBox(width: 4),
          if (isCompact)
            IconButton(
              tooltip: 'Novo lembrete',
              onPressed: () => showCustomReminderDialog(context),
              icon: const Icon(Icons.add_alert_rounded),
            )
          else
            FilledButton.icon(
              onPressed: () => showCustomReminderDialog(context),
              icon: const Icon(Icons.add_alert_rounded, size: 18),
              label: const Text('Novo lembrete'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyStateView(
          icon: Icons.error_outline_rounded,
          title: 'Erro ao carregar notificações',
          description: error.toString(),
          actionLabel: 'Tentar novamente',
          onAction: () => ref.invalidate(notificationsStreamProvider),
        ),
        data: (items) {
          final visible = items.where((item) {
            return switch (_filter) {
              'unread' => !item.isRead,
              'bills' => item.type == NotificationType.upcomingPayable ||
                  item.type == NotificationType.overduePayable,
              'invoices' => item.type == NotificationType.invoiceDue,
              'custom' => item.type == NotificationType.customReminder,
              _ => true,
            };
          }).toList(growable: false);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  if (effectiveProfile != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: alertsEnabled,
                              onChanged: (value) async {
                                await ref
                                    .read(profileControllerProvider.notifier)
                                    .updateNotificationPreferences(
                                      currentProfile: effectiveProfile,
                                      notificationsEnabled: value,
                                    );
                                if (value) {
                                  await ref
                                      .read(notificationControllerProvider
                                          .notifier)
                                      .syncAlerts(silent: true);
                                }
                              },
                              title: const Text(
                                'Alertas automáticos de vencimentos e faturas',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                alertsEnabled
                                    ? 'Antecedência ativa: avisar até $reminderDays dia(s) antes'
                                    : 'Alertas automáticos pausados (lembretes manuais continuam visíveis)',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Antecedência:',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                for (final days in const [1, 2, 3, 5, 7, 15])
                                  ChoiceChip(
                                    label: Text('$days d'),
                                    selected: reminderDays == days,
                                    onSelected: alertsEnabled
                                        ? (_) async {
                                            await ref
                                                .read(profileControllerProvider
                                                    .notifier)
                                                .updateNotificationPreferences(
                                                  currentProfile:
                                                      effectiveProfile,
                                                  reminderDaysBefore: days,
                                                );
                                            await ref
                                                .read(
                                                    notificationControllerProvider
                                                        .notifier)
                                                .syncAlerts(silent: true);
                                          }
                                        : null,
                                  ),
                              ],
                            ),
                            const Divider(height: 22),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.notifications_active_outlined,
                                      size: 18,
                                      color: pushEnabled
                                          ? AppColors.income
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        service.supportsPushNotifications
                                            ? (pushEnabled
                                                ? 'Push FCM ativo neste dispositivo'
                                                : 'Receber push em segundo plano via FCM')
                                            : 'Push FCM isolado em ${PlatformInfo.platformLabel} (alertas internos ativos)',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                                if (service.supportsPushNotifications)
                                  OutlinedButton.icon(
                                    onPressed: notifState.isLoading
                                        ? null
                                        : () => ref
                                            .read(notificationControllerProvider
                                                .notifier)
                                            .enablePushNotifications(
                                                effectiveProfile),
                                    icon: const Icon(Icons.phonelink_ring_rounded,
                                        size: 17),
                                    label: Text(
                                      pushEnabled
                                          ? 'Atualizar token FCM'
                                          : 'Ativar Push FCM',
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry in const [
                          ('all', 'Todos'),
                          ('unread', 'Não lidos'),
                          ('bills', 'Contas'),
                          ('invoices', 'Faturas'),
                          ('custom', 'Lembretes'),
                        ]) ...[
                          FilterChip(
                            label: Text(entry.$2),
                            selected: _filter == entry.$1,
                            onSelected: (_) =>
                                setState(() => _filter = entry.$1),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    SizedBox(
                      height: 300,
                      child: EmptyStateView(
                        icon: Icons.notifications_none_rounded,
                        title: 'Nenhuma notificação neste filtro',
                        description:
                            'Quando houver contas próximas do vencimento, faturas abertas, receitas previstas ou lembretes criados, eles aparecerão aqui.',
                        actionLabel: 'Criar lembrete',
                        onAction: () => showCustomReminderDialog(context),
                      ),
                    )
                  else
                    for (final item in visible)
                      Builder(
                        builder: (context) {
                          final color = _colorForType(item.type);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: item.isRead
                                ? null
                                : color.withOpacity(0.05),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: color.withOpacity(0.14),
                                    foregroundColor: color,
                                    child: Icon(
                                      _iconForType(item.type),
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              item.title,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: item.isRead
                                                    ? FontWeight.w600
                                                    : FontWeight.w800,
                                              ),
                                            ),
                                            StatusBadge(
                                              label: item.type.label,
                                              color: color,
                                            ),
                                            if (!item.isRead)
                                              const StatusBadge(
                                                label: 'Nova',
                                                color: AppColors.primaryLight,
                                              ),
                                          ],
                                        ),
                                        if (item.body.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            item.body,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              item.isCustom
                                                  ? DateFormatter.shortDateTime(
                                                      item.scheduledFor,
                                                    )
                                                  : DateFormatter.shortDate(
                                                      item.scheduledFor,
                                                    ),
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                ),
                                              ),
                                              onPressed: () => ref
                                                  .read(
                                                      notificationControllerProvider
                                                          .notifier)
                                                  .toggleRead(
                                                    notificationId: item.id,
                                                    isRead: !item.isRead,
                                                  ),
                                              icon: Icon(
                                                item.isRead
                                                    ? Icons
                                                        .mark_email_unread_outlined
                                                    : Icons
                                                        .mark_email_read_outlined,
                                                size: 16,
                                              ),
                                              label: Text(
                                                item.isRead
                                                    ? 'Marcar não lida'
                                                    : 'Marcar lida',
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Excluir notificação',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(
                                                minWidth: 32,
                                                minHeight: 32,
                                              ),
                                              onPressed: () => ref
                                                  .read(
                                                      notificationControllerProvider
                                                          .notifier)
                                                  .deleteNotification(item.id),
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 18,
                                                color: AppColors.expense,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
