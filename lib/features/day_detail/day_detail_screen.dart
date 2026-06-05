import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../core/enums.dart';
import '../../core/launchers.dart';
import '../../data/database/app_database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../trip_home/trip_providers.dart';
import 'spot_image.dart';

/// 單日詳情：時間軸式 Spot 列表 + 飯店（撥號/地圖）+ 餐食 + 退費條款（§5.3）。
class DayDetailScreen extends ConsumerWidget {
  const DayDetailScreen({
    super.key,
    required this.tripId,
    required this.dayIndex,
  });

  final String tripId;
  final int dayIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<DayPlanRow?> day =
        ref.watch(dayProvider((tripId: tripId, dayIndex: dayIndex)));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dayLabel(dayIndex))),
      body: day.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (DayPlanRow? d) {
          if (d == null) return Center(child: Text(l10n.errorGeneric));
          return _DayBody(tripId: tripId, day: d);
        },
      ),
    );
  }
}

class _DayBody extends ConsumerWidget {
  const _DayBody({required this.tripId, required this.day});
  final String tripId;
  final DayPlanRow day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<SpotRow>> spots = ref.watch(daySpotsProvider(day.id));
    final List<FlightRow> flights =
        (ref.watch(tripFlightsProvider(tripId)).valueOrNull ?? <FlightRow>[])
            .where((FlightRow f) => f.dayIndex == day.dayIndex)
            .toList();
    final DateFormat df = DateFormat('yyyy/MM/dd (E)', 'zh');

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (day.date != null)
                Text(df.format(day.date!),
                    style: Theme.of(context).textTheme.bodySmall),
              if (day.routeSummary != null)
                Text(day.routeSummary!,
                    style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        for (final FlightRow f in flights) _FlightCard(flight: f),
        if (day.hotelName != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.hotel_outlined),
              title: Text(day.hotelName!),
              subtitle: day.hotelNameEn == null ? null : Text(day.hotelNameEn!),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (day.hotelPhone != null)
                    IconButton(
                      icon: const Icon(Icons.call),
                      tooltip: l10n.commonCall,
                      onPressed: () => Launchers.dial(context, day.hotelPhone!),
                    ),
                  IconButton(
                    icon: const Icon(Icons.map_outlined),
                    tooltip: l10n.commonMap,
                    onPressed: () => Launchers.openMap(
                      context,
                      '${day.hotelName} ${day.hotelNameEn ?? ''}'.trim(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.meals, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _MealLine(label: l10n.mealBreakfast, value: day.mealBreakfast),
                _MealLine(label: l10n.mealLunch, value: day.mealLunch),
                _MealLine(label: l10n.mealDinner, value: day.mealDinner),
              ],
            ),
          ),
        ),
        spots.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('$e'),
          ),
          data: (List<SpotRow> list) => Column(
            children: <Widget>[
              for (int i = 0; i < list.length; i++)
                _SpotTimelineTile(
                  tripId: tripId,
                  spot: list[i],
                  isLast: i == list.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MealLine extends StatelessWidget {
  const _MealLine({required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 40,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value ?? l10n.noData)),
        ],
      ),
    );
  }
}

class _FlightCard extends StatelessWidget {
  const _FlightCard({required this.flight});
  final FlightRow flight;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateFormat tf = DateFormat('MM/dd HH:mm');
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.flight_takeoff, size: 20),
                const SizedBox(width: 8),
                Text(
                  <String>[
                    flight.flightNo ?? l10n.flightLabel,
                    if (flight.carrier != null) flight.carrier!,
                  ].join(' · '),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _FlightEnd(
                    label: l10n.flightDepart,
                    airport: flight.fromAirport,
                    time: flight.departTime == null
                        ? null
                        : tf.format(flight.departTime!),
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 18),
                Expanded(
                  child: _FlightEnd(
                    label: l10n.flightArrive,
                    airport: flight.toAirport,
                    time: flight.arriveTime == null
                        ? null
                        : tf.format(flight.arriveTime!),
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FlightEnd extends StatelessWidget {
  const _FlightEnd({
    required this.label,
    required this.airport,
    required this.time,
    this.alignEnd = false,
  });
  final String label;
  final String? airport;
  final String? time;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        if (airport != null)
          Text(airport!, style: Theme.of(context).textTheme.bodyMedium),
        if (time != null)
          Text(time!, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _SpotTimelineTile extends StatelessWidget {
  const _SpotTimelineTile({
    required this.tripId,
    required this.spot,
    required this.isLast,
  });
  final String tripId;
  final SpotRow spot;
  final bool isLast;

  IconData _icon(VisitType t) => switch (t) {
        VisitType.enter => Icons.place,
        VisitType.photo => Icons.photo_camera,
        VisitType.driveBy => Icons.directions_bus,
      };

  String _visitLabel(AppLocalizations l10n, VisitType t) => switch (t) {
        VisitType.enter => l10n.visitTypeEnter,
        VisitType.photo => l10n.visitTypePhoto,
        VisitType.driveBy => l10n.visitTypeDriveBy,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () => context.push(AppRoutes.spotDetail(tripId, spot.id)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 時間軸線 + 節點
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 14),
                  Icon(_icon(spot.visitType), size: 20, color: primary),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: primary.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (spot.imagePath != null) ...<Widget>[
                          SpotImage(
                            path: spot.imagePath!,
                            width: 56,
                            height: 56,
                            borderRadius: 8,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            spot.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          _visitLabel(l10n, spot.visitType),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: primary),
                        ),
                      ],
                    ),
                    if (spot.refundNote != null)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${l10n.refundNote}: ${spot.refundNote}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
