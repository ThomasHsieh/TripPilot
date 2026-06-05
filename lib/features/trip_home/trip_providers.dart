import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../data/repositories/trip_repository.dart';

/// 行程瀏覽用的 Riverpod providers（手寫，無 codegen）。

/// 所有行程（清單頁）。
final allTripsProvider = StreamProvider<List<TripRow>>((Ref ref) {
  return ref.watch(tripRepositoryProvider).watchTrips();
});

/// 單一行程主檔。
final tripProvider =
    StreamProvider.family<TripRow?, String>((Ref ref, String id) {
  return ref.watch(tripRepositoryProvider).watchTrip(id);
});

/// 行程的所有提醒（依 fire_at）。
final tripRemindersProvider =
    StreamProvider.family<List<ReminderRow>, String>((Ref ref, String id) {
  return ref.watch(reminderRepositoryProvider).watchReminders(id);
});

/// 行程的所有 InfoSection（須知，依 order_index）。
final tripInfoSectionsProvider =
    FutureProvider.family<List<InfoSectionRow>, String>((Ref ref, String id) {
  return ref.watch(tripRepositoryProvider).getInfoSections(id);
});

/// 行程的所有 DayPlan（依 day_index）。
final tripDaysProvider =
    StreamProvider.family<List<DayPlanRow>, String>((Ref ref, String id) {
  return ref.watch(tripRepositoryProvider).watchDays(id);
});

/// 行程的航班。
final tripFlightsProvider =
    FutureProvider.family<List<FlightRow>, String>((Ref ref, String id) {
  return ref.watch(tripRepositoryProvider).getFlights(id);
});

/// 單日（依 tripId + dayIndex）。
typedef DayKey = ({String tripId, int dayIndex});

final dayProvider =
    FutureProvider.family<DayPlanRow?, DayKey>((Ref ref, DayKey key) {
  return ref
      .watch(tripRepositoryProvider)
      .getDayByIndex(key.tripId, key.dayIndex);
});

/// 某 DayPlan 之下的景點（依 order_index）。
final daySpotsProvider =
    FutureProvider.family<List<SpotRow>, String>((Ref ref, String dayId) {
  return ref.watch(tripRepositoryProvider).getSpotsForDay(dayId);
});

/// 單一景點。
final spotProvider =
    FutureProvider.family<SpotRow?, String>((Ref ref, String spotId) {
  return ref.watch(tripRepositoryProvider).getSpot(spotId);
});

/// 計算「今天」對應的 day_index（1-based）；不在行程區間回 null。
int? activeDayIndex(TripRow trip, {DateTime? now}) {
  final DateTime? start = trip.startDate;
  final DateTime? end = trip.endDate;
  if (start == null || end == null) return null;
  final DateTime today = _dateOnly(now ?? DateTime.now());
  final DateTime s = _dateOnly(start);
  final DateTime e = _dateOnly(end);
  if (today.isBefore(s) || today.isAfter(e)) return null;
  return today.difference(s).inDays + 1;
}

/// 距出發天數（負值代表已開始/結束）。
int daysUntilStart(TripRow trip, {DateTime? now}) {
  final DateTime today = _dateOnly(now ?? DateTime.now());
  final DateTime s = _dateOnly(trip.startDate ?? today);
  return s.difference(today).inDays;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
