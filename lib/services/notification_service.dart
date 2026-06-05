import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

/// 本地通知服務（規格 §6）。以 flutter_local_notifications + timezone 排程，
/// 支援目的地時區與本地時區。非行動平台或初始化失敗時靜默降級。
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const String _channelId = 'trip_reminders';
  static const String _channelName = '行程提醒';

  bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<void> init() async {
    if (_initialized || !_supported) return;
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    try {
      await _plugin.initialize(settings);
      _initialized = true;
    } on Object catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  /// 請求通知權限（iOS / Android 13+）。回傳是否取得。
  Future<bool> requestPermissions() async {
    if (!_supported) return false;
    await init();
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android =
            _plugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final bool? granted = await android?.requestNotificationsPermission();
        return granted ?? false;
      }
      final IOSFlutterLocalNotificationsPlugin? ios =
          _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final bool? granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    } on Object catch (e) {
      debugPrint('requestPermissions failed: $e');
      return false;
    }
  }

  /// 目前是否已啟用通知（Android 可查；其他平台先視為已啟用）。
  Future<bool> areEnabled() async {
    if (!_supported) return false;
    await init();
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android =
            _plugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        return await android?.areNotificationsEnabled() ?? true;
      }
      return true;
    } on Object {
      return true;
    }
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  /// 排程一則於 [when]（已含時區）觸發的通知。
  Future<void> schedule({
    required int id,
    required String title,
    String? body,
    required tz.TZDateTime when,
  }) async {
    if (!_supported) return;
    await init();
    // 過去時間不排程。
    if (when.isBefore(tz.TZDateTime.now(when.location))) return;
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on Object catch (e) {
      debugPrint('schedule failed: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (!_supported) return;
    try {
      await _plugin.cancel(id);
    } on Object catch (_) {}
  }

  Future<void> cancelAll() async {
    if (!_supported) return;
    try {
      await _plugin.cancelAll();
    } on Object catch (_) {}
  }
}

final notificationServiceProvider =
    Provider<NotificationService>((Ref ref) => NotificationService());
