import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/trip_repository.dart';
import '../../features/import/sample_loader.dart';
import '../../l10n/generated/app_localizations.dart';
import '../reminders/reminder_scheduler.dart';
import '../trip_home/trip_providers.dart';

/// 行程清單（多個已匯入行程）。M4：讀真實資料、點擊進入行程首頁。
class TripListScreen extends ConsumerWidget {
  const TripListScreen({super.key});

  Future<void> _loadSample(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String tripId =
        await loadSampleTrip(ref.read(tripRepositoryProvider));
    // 一併建立預設提醒（與正式匯入流程一致）。
    await ref.read(reminderSchedulerProvider).createDefaults(tripId, l10n);
    if (context.mounted) context.go(AppRoutes.tripHome(tripId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<TripRow>> trips = ref.watch(allTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tripListTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(AppRoutes.settings),
            tooltip: l10n.settingsTitle,
          ),
        ],
      ),
      body: trips.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (List<TripRow> list) {
          if (list.isEmpty) {
            return _EmptyState(onLoadSample: () => _loadSample(context, ref));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (BuildContext context, int i) =>
                _TripTile(trip: list[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.import),
        icon: const Icon(Icons.file_upload_outlined),
        label: Text(l10n.importPdf),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onLoadSample});
  final Future<void> Function() onLoadSample;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.luggage_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.tripListEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (kDebugMode) ...<Widget>[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onLoadSample,
                icon: const Icon(Icons.science_outlined),
                label: Text(l10n.loadSampleTrip),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripTile extends ConsumerWidget {
  const _TripTile({required this.trip});
  final TripRow trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateFormat df = DateFormat('yyyy/MM/dd');
    final String range = (trip.startDate != null && trip.endDate != null)
        ? l10n.tripDateRange(
            df.format(trip.startDate!),
            df.format(trip.endDate!),
          )
        : '';
    final int? activeDay = activeDayIndex(trip);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          trip.title ?? trip.tourCode ?? l10n.appTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (trip.tourCode != null) Text(trip.tourCode!),
            if (range.isNotEmpty) Text(range),
            if (activeDay != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(l10n.tripInProgressDay(activeDay)),
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(AppRoutes.tripHome(trip.id)),
        onLongPress: () => _confirmDelete(context, ref),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(trip.title ?? trip.tourCode ?? l10n.appTitle),
        content: Text(l10n.commonDelete),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(tripRepositoryProvider).deleteTrip(trip.id);
    }
  }
}
