import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../core/enums.dart';
import '../../data/models/parsed_trip.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/notification_service.dart';
import '../reminders/reminder_scheduler.dart';
import 'import_controller.dart';
import 'import_preview_controller.dart';
import 'trip_json_mapper.dart';

/// 解析結果預覽 / 逐欄修正（§4.1 step 6）。確認後寫入 Drift 並導向行程首頁。
class ImportPreviewScreen extends ConsumerWidget {
  const ImportPreviewScreen({super.key});

  Future<void> _onConfirm(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? tripId =
        await ref.read(previewControllerProvider.notifier).save();
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
      }
      return;
    }
    // 存檔後自動建立預設提醒（§4.1 step 7 / §6.2）。
    await ref.read(notificationServiceProvider).requestPermissions();
    await ref.read(reminderSchedulerProvider).createDefaults(tripId, l10n);
    // 清理匯入流程狀態，導向行程首頁。
    ref.read(previewControllerProvider.notifier).clear();
    ref.read(importControllerProvider.notifier).reset();
    if (context.mounted) context.go(AppRoutes.tripHome(tripId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PreviewState? state = ref.watch(previewControllerProvider);

    if (state == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.importPreviewTitle)),
        body: Center(child: Text(l10n.errorGeneric)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importPreviewTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          if (state.warnings.isNotEmpty)
            _WarningsBanner(warnings: state.warnings),
          const _SectionHeader(icon: Icons.info_outline, labelKey: 'tripInfo'),
          const _TripHeaderEditor(),
          const _SectionHeader(icon: Icons.calendar_month, labelKey: 'days'),
          ...state.trip.days.map((ParsedDay d) => _DayCard(day: d)),
          _InfoSummary(trip: state.trip),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: state.saving ? null : () => _onConfirm(context, ref),
          icon: state.saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(l10n.importConfirm),
        ),
      ),
    );
  }
}

class _WarningsBanner extends StatelessWidget {
  const _WarningsBanner({required this.warnings});
  final List<TripWarning> warnings;

  String _label(AppLocalizations l10n, TripWarningKind kind) => switch (kind) {
        TripWarningKind.dayCountMismatch => l10n.warnDayCount,
        TripWarningKind.dateDiscontinuous => l10n.warnDateGap,
        TripWarningKind.flightOutOfRange => l10n.warnFlightRange,
        TripWarningKind.meetupAfterFirstFlight => l10n.warnMeetup,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color amber = Colors.amber.shade700;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: amber.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, color: amber, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.previewWarningsTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: amber),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...warnings.map(
            (TripWarning w) => Padding(
              padding: const EdgeInsets.only(left: 28, top: 2),
              child: Text(
                w.detail != null
                    ? '• ${_label(l10n, w.kind)}（${w.detail}）'
                    : '• ${_label(l10n, w.kind)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.labelKey});
  final IconData icon;
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String label =
        labelKey == 'tripInfo' ? l10n.previewTripInfo : l10n.previewDays;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

/// 行程 header 可編輯欄位。編輯即時寫回 previewController 並重新驗證。
class _TripHeaderEditor extends ConsumerWidget {
  const _TripHeaderEditor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ParsedTrip trip = ref.watch(
      previewControllerProvider.select((PreviewState? s) => s!.trip),
    );
    final PreviewController ctrl = ref.read(previewControllerProvider.notifier);
    final DateFormat df = DateFormat('yyyy/MM/dd');

    void edit(ParsedTrip Function() build) => ctrl.updateTrip(build());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            _Field(
              label: l10n.appTitle,
              initial: trip.title,
              onChanged: (String v) => edit(() => trip.copyWith(title: v)),
            ),
            _Field(
              label: 'tour_code',
              initial: trip.tourCode,
              onChanged: (String v) => edit(() => trip.copyWith(tourCode: v)),
            ),
            _Field(
              label: l10n.leaderName,
              initial: trip.leaderName,
              onChanged: (String v) => edit(() => trip.copyWith(leaderName: v)),
            ),
            _Field(
              label: l10n.callDomestic,
              initial: trip.leaderPhoneDomestic,
              keyboardType: TextInputType.phone,
              onChanged: (String v) =>
                  edit(() => trip.copyWith(leaderPhoneDomestic: v)),
            ),
            _Field(
              label: l10n.callOverseas,
              initial: trip.leaderPhoneOverseas,
              keyboardType: TextInputType.phone,
              onChanged: (String v) =>
                  edit(() => trip.copyWith(leaderPhoneOverseas: v)),
            ),
            _Field(
              label: l10n.airportServiceLine,
              initial: trip.airportServiceLine,
              keyboardType: TextInputType.phone,
              onChanged: (String v) =>
                  edit(() => trip.copyWith(airportServiceLine: v)),
            ),
            _Field(
              label: l10n.meetupLocation,
              initial: trip.meetupLocation,
              onChanged: (String v) =>
                  edit(() => trip.copyWith(meetupLocation: v)),
            ),
            _Field(
              label: l10n.luggageTag,
              initial: trip.luggageTag,
              onChanged: (String v) => edit(() => trip.copyWith(luggageTag: v)),
            ),
            const SizedBox(height: 8),
            _ReadOnlyRow(
              label:
                  '${l10n.meetupTime} / ${df.format(trip.startDate ?? DateTime.now())}',
              value: trip.startDate == null
                  ? '—'
                  : '${df.format(trip.startDate!)} ~ ${trip.endDate == null ? '—' : df.format(trip.endDate!)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.initial,
    required this.onChanged,
    this.keyboardType,
  });
  final String label;
  final String? initial;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        initialValue: initial,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: onChanged,
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});
  final ParsedDay day;

  IconData _visitIcon(VisitType t) => switch (t) {
        VisitType.enter => Icons.place,
        VisitType.photo => Icons.photo_camera,
        VisitType.driveBy => Icons.directions_bus,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Card(
      child: ExpansionTile(
        title: Text(
          '${l10n.dayLabel(day.dayIndex)} · ${day.routeSummary ?? ''}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text(
          '${day.hotelName ?? '—'} · ${l10n.previewSpotsCount(day.spots.length)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: <Widget>[
          if (day.hotelPhone != null)
            _ReadOnlyRow(label: l10n.hotel, value: day.hotelPhone!),
          _ReadOnlyRow(
            label: l10n.mealBreakfast,
            value: day.mealBreakfast ?? '—',
          ),
          _ReadOnlyRow(label: l10n.mealLunch, value: day.mealLunch ?? '—'),
          _ReadOnlyRow(label: l10n.mealDinner, value: day.mealDinner ?? '—'),
          const Divider(),
          ...day.spots.map(
            (ParsedSpot s) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(_visitIcon(s.visitType), size: 20),
              title: Text(s.name),
              subtitle: s.refundNote == null
                  ? null
                  : Text(
                      '${l10n.refundNote}: ${s.refundNote}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSummary extends StatelessWidget {
  const _InfoSummary({required this.trip});
  final ParsedTrip trip;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: <Widget>[
          const Icon(Icons.menu_book_outlined, size: 18),
          const SizedBox(width: 8),
          Text(l10n.previewInfoCount(trip.infoSections.length)),
        ],
      ),
    );
  }
}
