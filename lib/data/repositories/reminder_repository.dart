import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/id.dart';
import '../database/app_database.dart';

/// 提醒讀寫（規格 §3.6 / §6）。實際 OS 排程由 notification_service 處理（M6）。
class ReminderRepository {
  ReminderRepository(this._db);

  final AppDatabase _db;

  Stream<List<ReminderRow>> watchReminders(String tripId) {
    return (_db.select(_db.reminders)
          ..where((r) => r.tripId.equals(tripId))
          ..orderBy(<OrderClauseGenerator<$RemindersTable>>[
            (r) => OrderingTerm.asc(r.fireAt),
          ]))
        .watch();
  }

  Future<List<ReminderRow>> getReminders(String tripId) {
    return (_db.select(_db.reminders)
          ..where((r) => r.tripId.equals(tripId))
          ..orderBy(<OrderClauseGenerator<$RemindersTable>>[
            (r) => OrderingTerm.asc(r.fireAt),
          ]))
        .get();
  }

  Future<String> addReminder(
    String tripId, {
    required ReminderRefType refType,
    required DateTime fireAt,
    required String title,
    String? body,
    String? refId,
    bool enabled = true,
    int? osNotificationId,
  }) async {
    final String id = Ids.newId();
    await _db.into(_db.reminders).insert(
          RemindersCompanion.insert(
            id: id,
            tripId: tripId,
            refType: refType,
            refId: Value<String?>(refId),
            fireAt: fireAt,
            title: title,
            body: Value<String?>(body),
            enabled: Value<bool>(enabled),
            osNotificationId: Value<int?>(osNotificationId),
          ),
        );
    return id;
  }

  Future<void> updateReminder(ReminderRow row) =>
      _db.update(_db.reminders).replace(row);

  Future<void> setEnabled(String id, bool enabled) async {
    await (_db.update(_db.reminders)..where((r) => r.id.equals(id))).write(
      RemindersCompanion(enabled: Value<bool>(enabled)),
    );
  }

  Future<void> deleteReminder(String id) async {
    await (_db.delete(_db.reminders)..where((r) => r.id.equals(id))).go();
  }
}

final reminderRepositoryProvider = Provider<ReminderRepository>((Ref ref) {
  return ReminderRepository(ref.watch(appDatabaseProvider));
});
