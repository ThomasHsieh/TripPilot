import '../../core/constants.dart';
import '../../core/enums.dart';

/// 一筆預設提醒的「時間與關聯」計算結果（與 i18n 文字解耦，便於測試）。
class ReminderTiming {
  const ReminderTiming({
    required this.refType,
    required this.fireAt,
    this.dayIndex,
    this.refId,
  });

  final ReminderRefType refType;

  /// 觸發的「牆上時間」。meetup/dayStart/flight 視為目的地時區；
  /// passport 視為裝置本地時區（排程時由 NotificationService 決定）。
  final DateTime fireAt;
  final int? dayIndex;
  final String? refId;
}

/// 單日輸入（day_index + 當日日期）。
typedef DayDate = ({int dayIndex, DateTime? date});

/// 依規格 §6.2 計算匯入後自動建立的預設提醒時間。
/// 純函式、無副作用，供單元測試驗證提前量與時間。
List<ReminderTiming> computeDefaultReminderTimings({
  DateTime? meetupTime,
  DateTime? startDate,
  List<DayDate> days = const <DayDate>[],
  DateTime? returnFlightDepart,
  String? returnFlightId,
}) {
  final List<ReminderTiming> out = <ReminderTiming>[];

  // 1. 集合提醒：集合時間前 2 小時
  if (meetupTime != null) {
    out.add(
      ReminderTiming(
        refType: ReminderRefType.meetup,
        fireAt: meetupTime.subtract(
          const Duration(hours: AppConstants.meetupReminderHoursBefore),
        ),
      ),
    );
  }

  // 2. 護照效期：出發前 30 天，當天 09:00
  if (startDate != null) {
    final DateTime d = startDate.subtract(
      const Duration(days: AppConstants.passportReminderDaysBefore),
    );
    out.add(
      ReminderTiming(
        refType: ReminderRefType.custom,
        fireAt: DateTime(d.year, d.month, d.day, 9),
      ),
    );
  }

  // 3. 每日晨報：每天當地 07:00
  for (final DayDate day in days) {
    if (day.date == null) continue;
    final DateTime dd = day.date!;
    out.add(
      ReminderTiming(
        refType: ReminderRefType.dayStart,
        dayIndex: day.dayIndex,
        fireAt: DateTime(
          dd.year,
          dd.month,
          dd.day,
          AppConstants.dailyBriefingHour,
        ),
      ),
    );
  }

  // 4. 回程班機：起飛前 3 小時
  if (returnFlightDepart != null) {
    out.add(
      ReminderTiming(
        refType: ReminderRefType.flight,
        refId: returnFlightId,
        fireAt: returnFlightDepart.subtract(
          const Duration(hours: AppConstants.returnFlightReminderHoursBefore),
        ),
      ),
    );
  }

  return out;
}
