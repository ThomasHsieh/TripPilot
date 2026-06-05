import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'constants.dart';

/// 時區初始化與輔助。提醒以「目的地時區」與「本地時區」雙軌處理（規格 §6.1）。
class TzHelper {
  TzHelper._();

  static bool _initialized = false;

  /// 於 App 啟動時呼叫一次（main）。
  static void init() {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _initialized = true;
  }

  /// 目的地時區的 location（預設 Asia/Tokyo）。
  static tz.Location get destination =>
      tz.getLocation(AppConstants.destinationTimeZone);

  /// 將「目的地當地時間（牆上時間）」轉為 TZDateTime，供排程使用。
  static tz.TZDateTime destinationWallClock(
    int year,
    int month,
    int day, [
    int hour = 0,
    int minute = 0,
  ]) {
    return tz.TZDateTime(destination, year, month, day, hour, minute);
  }

  /// 將既有 DateTime（視為目的地牆上時間）轉為目的地 TZDateTime。
  static tz.TZDateTime fromDestinationLocal(DateTime dt) {
    return tz.TZDateTime(
      destination,
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
    );
  }
}
