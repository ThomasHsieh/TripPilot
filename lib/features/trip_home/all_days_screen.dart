import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../data/database/app_database.dart';
import '../../l10n/generated/app_localizations.dart';
import 'trip_providers.dart';
import 'widgets/trip_scaffold.dart';

/// 全程：所有 DayPlan 列表，點擊進入單日詳情。
class AllDaysScreen extends ConsumerWidget {
  const AllDaysScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<DayPlanRow>> days =
        ref.watch(tripDaysProvider(tripId));
    final DateFormat df = DateFormat('MM/dd (E)', 'zh');

    return TripScaffold(
      tripId: tripId,
      currentTab: TripTab.days,
      title: l10n.navAll,
      body: days.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (List<DayPlanRow> list) => ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          itemBuilder: (BuildContext context, int i) {
            final DayPlanRow d = list[i];
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${d.dayIndex}')),
                title: Text(d.routeSummary ?? l10n.dayLabel(d.dayIndex)),
                subtitle: Text(
                  <String>[
                    if (d.date != null) df.format(d.date!),
                    if (d.hotelName != null) d.hotelName!,
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push(AppRoutes.dayDetail(tripId, d.dayIndex)),
              ),
            );
          },
        ),
      ),
    );
  }
}
