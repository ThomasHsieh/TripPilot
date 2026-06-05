import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/enums.dart';
import '../../core/tz.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/notification_service.dart';
import '../trip_home/trip_providers.dart';
import 'reminder_scheduler.dart';

/// 通知是否已啟用（Android 可查）。供權限引導橫幅使用。
final notifEnabledProvider = FutureProvider.autoDispose<bool>((Ref ref) {
  return ref.watch(notificationServiceProvider).areEnabled();
});

/// 提醒管理（§6.3）：清單、逐筆開關、全域開關、建立預設、權限請求。
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key, required this.tripId});

  final String tripId;

  Future<void> _toggle(
    WidgetRef ref,
    ReminderRow r,
    bool enabled,
  ) async {
    await ref.read(reminderRepositoryProvider).setEnabled(r.id, enabled);
    final NotificationService notif = ref.read(notificationServiceProvider);
    final int? osId = r.osNotificationId;
    if (osId == null) return;
    if (enabled) {
      await notif.schedule(
        id: osId,
        title: r.title,
        body: r.body,
        when: TzHelper.fromDestinationLocal(r.fireAt),
      );
    } else {
      await notif.cancel(osId);
    }
  }

  Future<void> _setAll(WidgetRef ref, List<ReminderRow> list, bool on) async {
    for (final ReminderRow r in list) {
      if (r.enabled != on) await _toggle(ref, r, on);
    }
  }

  Future<void> _createDefaults(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    await ref.read(notificationServiceProvider).requestPermissions();
    final int n =
        await ref.read(reminderSchedulerProvider).createDefaults(tripId, l10n);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.remindersCreated(n))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<ReminderRow>> reminders =
        ref.watch(tripRemindersProvider(tripId));
    final DateFormat fmt = DateFormat('yyyy/MM/dd HH:mm');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.remindersTitle)),
      body: Column(
        children: <Widget>[
          const _PermissionBanner(),
          Expanded(child: _buildList(context, ref, reminders, fmt)),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ReminderRow>> reminders,
    DateFormat fmt,
  ) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return reminders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => Center(child: Text('$e')),
      data: (List<ReminderRow> list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(l10n.remindersEmpty),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _createDefaults(context, ref),
                  icon: const Icon(Icons.add_alert_outlined),
                  label: Text(l10n.reminderDayStart),
                ),
              ],
            ),
          );
        }
        final bool allOn = list.every((ReminderRow r) => r.enabled);
        return ListView(
          children: <Widget>[
            SwitchListTile(
              title: Text(l10n.remindersEnableAll),
              value: allOn,
              onChanged: (bool v) => _setAll(ref, list, v),
            ),
            const Divider(height: 1),
            for (final ReminderRow r in list)
              SwitchListTile(
                title: Text(r.title),
                subtitle: Text(
                  <String>[
                    fmt.format(r.fireAt),
                    if (r.body != null) r.body!,
                  ].join('\n'),
                ),
                isThreeLine: r.body != null,
                secondary: Icon(_iconFor(r.refType)),
                value: r.enabled,
                onChanged: (bool v) => _toggle(ref, r, v),
              ),
          ],
        );
      },
    );
  }

  IconData _iconFor(ReminderRefType t) => switch (t) {
        ReminderRefType.meetup => Icons.groups_outlined,
        ReminderRefType.flight => Icons.flight_outlined,
        ReminderRefType.dayStart => Icons.wb_sunny_outlined,
        ReminderRefType.custom => Icons.notifications_outlined,
      };
}

/// 通知權限被拒時的引導橫幅（§8）。
class _PermissionBanner extends ConsumerWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<bool> enabled = ref.watch(notifEnabledProvider);
    return enabled.maybeWhen(
      data: (bool on) {
        if (on) return const SizedBox.shrink();
        return Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                const Icon(Icons.notifications_off_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.reminderPermissionDenied)),
                TextButton(
                  onPressed: () async {
                    await ref
                        .read(notificationServiceProvider)
                        .requestPermissions();
                    ref.invalidate(notifEnabledProvider);
                  },
                  child: Text(l10n.enableNotifications),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
