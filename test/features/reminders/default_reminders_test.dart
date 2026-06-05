import 'package:flutter_test/flutter_test.dart';
import 'package:trip_pilot/core/enums.dart';
import 'package:trip_pilot/features/reminders/default_reminders.dart';

/// M6 / §9.1：預設提醒時間計算（提前量、晨報時間）。
void main() {
  test('集合提醒：集合時間前 2 小時（§9.3 → 05:25）', () {
    final List<ReminderTiming> r = computeDefaultReminderTimings(
      meetupTime: DateTime(2026, 6, 13, 7, 25),
    );
    final ReminderTiming meetup =
        r.firstWhere((ReminderTiming t) => t.refType == ReminderRefType.meetup);
    expect(meetup.fireAt, DateTime(2026, 6, 13, 5, 25));
  });

  test('護照效期：出發前 30 天 09:00', () {
    final List<ReminderTiming> r = computeDefaultReminderTimings(
      startDate: DateTime(2026, 6, 13),
    );
    final ReminderTiming passport =
        r.firstWhere((ReminderTiming t) => t.refType == ReminderRefType.custom);
    expect(passport.fireAt, DateTime(2026, 5, 14, 9));
  });

  test('每日晨報：各日當地 07:00', () {
    final List<ReminderTiming> r = computeDefaultReminderTimings(
      days: <DayDate>[
        (dayIndex: 1, date: DateTime(2026, 6, 13)),
        (dayIndex: 2, date: DateTime(2026, 6, 14)),
      ],
    );
    final List<ReminderTiming> daily = r
        .where((ReminderTiming t) => t.refType == ReminderRefType.dayStart)
        .toList();
    expect(daily, hasLength(2));
    expect(daily[0].fireAt, DateTime(2026, 6, 13, 7));
    expect(daily[1].fireAt, DateTime(2026, 6, 14, 7));
    expect(daily[0].dayIndex, 1);
  });

  test('回程班機：起飛前 3 小時', () {
    final List<ReminderTiming> r = computeDefaultReminderTimings(
      returnFlightDepart: DateTime(2026, 6, 18, 15, 30),
      returnFlightId: 'f-return',
    );
    final ReminderTiming flight =
        r.firstWhere((ReminderTiming t) => t.refType == ReminderRefType.flight);
    expect(flight.fireAt, DateTime(2026, 6, 18, 12, 30));
    expect(flight.refId, 'f-return');
  });

  test('缺資料時不產生對應提醒', () {
    expect(computeDefaultReminderTimings(), isEmpty);
  });
}
