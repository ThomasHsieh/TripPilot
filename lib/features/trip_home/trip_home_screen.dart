import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../core/launchers.dart';
import '../../data/database/app_database.dart';
import '../../l10n/generated/app_localizations.dart';
import 'trip_providers.dart';
import 'widgets/trip_scaffold.dart';

/// 行程首頁（旅途中預設落地頁，§5.2）。
class TripHomeScreen extends ConsumerWidget {
  const TripHomeScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<TripRow?> trip = ref.watch(tripProvider(tripId));
    final AsyncValue<List<DayPlanRow>> days =
        ref.watch(tripDaysProvider(tripId));
    final AsyncValue<List<FlightRow>> flights =
        ref.watch(tripFlightsProvider(tripId));

    return TripScaffold(
      tripId: tripId,
      currentTab: TripTab.today,
      title: l10n.tripHomeTitle,
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: l10n.remindersTitle,
          onPressed: () => context.push(AppRoutes.reminders(tripId)),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: l10n.settingsTitle,
          onPressed: () => context.push(AppRoutes.settings),
        ),
      ],
      body: trip.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (TripRow? t) {
          if (t == null) return Center(child: Text(l10n.errorGeneric));
          final int? activeDay = activeDayIndex(t);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: <Widget>[
              _LeaderCard(trip: t),
              if (activeDay != null)
                _TodayCard(
                  tripId: tripId,
                  dayIndex: activeDay,
                  days: days.valueOrNull ?? const <DayPlanRow>[],
                )
              else
                _CountdownCard(
                  trip: t,
                  flights: flights.valueOrNull ?? const <FlightRow>[],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LeaderCard extends StatelessWidget {
  const _LeaderCard({required this.trip});
  final TripRow trip;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.badge_outlined),
                const SizedBox(width: 8),
                Text(l10n.leaderName,
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  trip.leaderName ?? l10n.noData,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (trip.leaderPhoneDomestic != null)
                  _CallChip(
                    label: l10n.callDomestic,
                    phone: trip.leaderPhoneDomestic!,
                  ),
                if (trip.leaderPhoneOverseas != null)
                  _CallChip(
                    label: l10n.callOverseas,
                    phone: trip.leaderPhoneOverseas!,
                  ),
                if (trip.airportServiceLine != null)
                  _CallChip(
                    label: l10n.airportServiceLine,
                    phone: trip.airportServiceLine!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CallChip extends StatelessWidget {
  const _CallChip({required this.label, required this.phone});
  final String label;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.call, size: 18),
      label: Text('$label  $phone'),
      onPressed: () => Launchers.dial(context, phone),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.tripId,
    required this.dayIndex,
    required this.days,
  });
  final String tripId;
  final int dayIndex;
  final List<DayPlanRow> days;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DayPlanRow? day =
        days.firstWhereOrNull((DayPlanRow d) => d.dayIndex == dayIndex);
    if (day == null) return const SizedBox.shrink();

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.today),
                const SizedBox(width: 8),
                Text(
                  l10n.tripInProgressDay(dayIndex),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (day.routeSummary != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                day.routeSummary!,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
            const Divider(height: 24),
            if (day.hotelName != null)
              _HotelRow(
                name: day.hotelName!,
                nameEn: day.hotelNameEn,
                phone: day.hotelPhone,
              ),
            const SizedBox(height: 8),
            _MealsRow(day: day),
            if (day.notes != null) ...<Widget>[
              const SizedBox(height: 8),
              _NoteBox(text: day.notes!),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () =>
                    context.push(AppRoutes.dayDetail(tripId, dayIndex)),
                icon: const Icon(Icons.arrow_forward),
                label: Text(l10n.viewDayDetail),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HotelRow extends StatelessWidget {
  const _HotelRow({required this.name, this.nameEn, this.phone});
  final String name;
  final String? nameEn;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.hotel_outlined, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(name, style: Theme.of(context).textTheme.bodyLarge),
              if (nameEn != null)
                Text(nameEn!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (phone != null)
          IconButton(
            icon: const Icon(Icons.call),
            tooltip: l10n.commonCall,
            onPressed: () => Launchers.dial(context, phone!),
          ),
        IconButton(
          icon: const Icon(Icons.map_outlined),
          tooltip: l10n.commonMap,
          onPressed: () =>
              Launchers.openMap(context, '$name ${nameEn ?? ''}'.trim()),
        ),
      ],
    );
  }
}

class _MealsRow extends StatelessWidget {
  const _MealsRow({required this.day});
  final DayPlanRow day;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.restaurant_outlined, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${l10n.mealBreakfast}: ${day.mealBreakfast ?? l10n.noData}\n'
            '${l10n.mealLunch}: ${day.mealLunch ?? l10n.noData}\n'
            '${l10n.mealDinner}: ${day.mealDinner ?? l10n.noData}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.push_pin_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.trip, required this.flights});
  final TripRow trip;
  final List<FlightRow> flights;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int daysLeft = daysUntilStart(trip);
    final DateFormat dt = DateFormat('MM/dd HH:mm');
    final FlightRow? firstFlight = flights
        .where((FlightRow f) => f.departTime != null)
        .sortedBy((FlightRow f) => f.departTime!)
        .firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Text(
                daysLeft > 0 ? l10n.countdownDays(daysLeft) : l10n.tripEnded,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const Divider(height: 24),
            Text(l10n.meetupInfo,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (trip.meetupTime != null)
              _InfoLine(
                icon: Icons.schedule,
                label: l10n.meetupTime,
                value: dt.format(trip.meetupTime!),
              ),
            if (trip.meetupLocation != null)
              _InfoLine(
                icon: Icons.place_outlined,
                label: l10n.meetupLocation,
                value: trip.meetupLocation!,
              ),
            if (trip.luggageTag != null)
              _InfoLine(
                icon: Icons.luggage_outlined,
                label: l10n.luggageTag,
                value: trip.luggageTag!,
              ),
            if (firstFlight != null)
              _InfoLine(
                icon: Icons.flight_takeoff,
                label: firstFlight.flightNo ?? l10n.flightLabel,
                value: dt.format(firstFlight.departTime!),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
