import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/enums.dart';
import '../../core/tz.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../data/repositories/trip_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/notification_service.dart';
import 'default_reminders.dart';

/// 協調預設提醒的建立：計算時間 → 寫入 Reminder 表 → 排程 OS 通知（§6.2）。
class ReminderScheduler {
  ReminderScheduler({
    required this.tripRepo,
    required this.reminderRepo,
    required this.notifications,
  });

  final TripRepository tripRepo;
  final ReminderRepository reminderRepo;
  final NotificationService notifications;

  /// 為某行程建立預設提醒；若已存在則先不重複（呼叫端確保只在匯入後叫一次）。
  /// 回傳建立筆數。
  Future<int> createDefaults(String tripId, AppLocalizations l10n) async {
    final TripRow? trip = await tripRepo.getTrip(tripId);
    if (trip == null) return 0;

    final List<DayPlanRow> days = await tripRepo.getDays(tripId);
    final List<FlightRow> flights = await tripRepo.getFlights(tripId);
    final FlightRow? returnFlight = flights
        .where((FlightRow f) => f.departTime != null)
        .sortedBy((FlightRow f) => f.departTime!)
        .lastOrNull;

    final List<ReminderTiming> timings = computeDefaultReminderTimings(
      meetupTime: trip.meetupTime,
      startDate: trip.startDate,
      days: days
          .map((DayPlanRow d) => (dayIndex: d.dayIndex, date: d.date))
          .toList(),
      returnFlightDepart: returnFlight?.departTime,
      returnFlightId: returnFlight?.id,
    );

    final DateFormat fmt = DateFormat('MM/dd HH:mm');
    int index = 0;
    for (final ReminderTiming t in timings) {
      final (String title, String body) =
          _textFor(t, trip, returnFlight, fmt, l10n);
      final int osId = _osId(tripId, t, index);

      await reminderRepo.addReminder(
        tripId,
        refType: t.refType,
        fireAt: t.fireAt,
        title: title,
        body: body,
        refId: t.refId,
        osNotificationId: osId,
      );
      await notifications.schedule(
        id: osId,
        title: title,
        body: body,
        when: TzHelper.fromDestinationLocal(t.fireAt),
      );
      index++;
    }
    return index;
  }

  (String, String) _textFor(
    ReminderTiming t,
    TripRow trip,
    FlightRow? returnFlight,
    DateFormat fmt,
    AppLocalizations l10n,
  ) {
    switch (t.refType) {
      case ReminderRefType.meetup:
        return (
          l10n.reminderMeetup,
          l10n.reminderMeetupBody(
            trip.meetupTime == null ? '' : fmt.format(trip.meetupTime!),
            trip.meetupLocation ?? '',
          ),
        );
      case ReminderRefType.dayStart:
        return (
          l10n.reminderDayStart,
          l10n.reminderDayStartBody(t.dayIndex ?? 0),
        );
      case ReminderRefType.flight:
        return (
          l10n.reminderReturnFlight,
          l10n.reminderReturnFlightBody(
            returnFlight?.flightNo ?? '',
            returnFlight?.departTime == null
                ? ''
                : fmt.format(returnFlight!.departTime!),
          ),
        );
      case ReminderRefType.custom:
        // 預設僅護照效期使用 custom。
        return (l10n.reminderPassport, l10n.reminderPassportBody);
    }
  }

  int _osId(String tripId, ReminderTiming t, int index) {
    final int h = tripId.hashCode ^
        (t.refType.index * 31) ^
        ((t.dayIndex ?? 0) * 131) ^
        (index * 7);
    return h & 0x7fffffff;
  }
}

final reminderSchedulerProvider = Provider<ReminderScheduler>((Ref ref) {
  return ReminderScheduler(
    tripRepo: ref.watch(tripRepositoryProvider),
    reminderRepo: ref.watch(reminderRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
});
