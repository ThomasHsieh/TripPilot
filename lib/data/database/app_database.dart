import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import 'converters.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// TripPilot 本地資料庫（SQLite via Drift）。離線優先，全部資料留在 App 沙盒。
///
/// FTS5（trigram tokenizer）虛擬表用於全行程全文檢索（規格 §5.6）：
///   - `spots_fts`(name, description)
///   - `days_fts`(route_summary, hotel_name)
///   - `info_fts`(title, body)
/// trigram 對中文可做子字串比對；2 字以下查詢由 repository 改走 LIKE 降級。
@DriftDatabase(
  tables: <Type>[
    Trips,
    DayPlans,
    Flights,
    Spots,
    InfoSections,
    Reminders,
    JournalEntries,
    ExchangeRates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'trip_pilot'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createFtsObjects();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // v2：Spot 新增 image_path 欄位（景點圖片）。
          if (from < 2) {
            await m.addColumn(spots, spots.imagePath);
          }
        },
        beforeOpen: (OpeningDetails details) async {
          // 啟用外鍵約束（Drift 預設不開）。
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// 建立 FTS5 虛擬表與同步觸發器。以獨立內容表 + entity_id 對應 uuid 主鍵。
  Future<void> _createFtsObjects() async {
    // ── Spots ────────────────────────────────────────────────
    await customStatement(
      'CREATE VIRTUAL TABLE spots_fts USING fts5('
      "entity_id UNINDEXED, name, description, tokenize='trigram')",
    );
    await customStatement(
      'CREATE TRIGGER spots_ai AFTER INSERT ON spots BEGIN '
      'INSERT INTO spots_fts(entity_id, name, description) '
      "VALUES(new.id, new.name, COALESCE(new.description, '')); END",
    );
    await customStatement(
      'CREATE TRIGGER spots_ad AFTER DELETE ON spots BEGIN '
      'DELETE FROM spots_fts WHERE entity_id = old.id; END',
    );
    await customStatement(
      'CREATE TRIGGER spots_au AFTER UPDATE ON spots BEGIN '
      'DELETE FROM spots_fts WHERE entity_id = old.id; '
      'INSERT INTO spots_fts(entity_id, name, description) '
      "VALUES(new.id, new.name, COALESCE(new.description, '')); END",
    );

    // ── DayPlans ─────────────────────────────────────────────
    await customStatement(
      'CREATE VIRTUAL TABLE days_fts USING fts5('
      "entity_id UNINDEXED, route_summary, hotel_name, tokenize='trigram')",
    );
    await customStatement(
      'CREATE TRIGGER days_ai AFTER INSERT ON day_plans BEGIN '
      'INSERT INTO days_fts(entity_id, route_summary, hotel_name) '
      "VALUES(new.id, COALESCE(new.route_summary, ''), "
      "COALESCE(new.hotel_name, '')); END",
    );
    await customStatement(
      'CREATE TRIGGER days_ad AFTER DELETE ON day_plans BEGIN '
      'DELETE FROM days_fts WHERE entity_id = old.id; END',
    );
    await customStatement(
      'CREATE TRIGGER days_au AFTER UPDATE ON day_plans BEGIN '
      'DELETE FROM days_fts WHERE entity_id = old.id; '
      'INSERT INTO days_fts(entity_id, route_summary, hotel_name) '
      "VALUES(new.id, COALESCE(new.route_summary, ''), "
      "COALESCE(new.hotel_name, '')); END",
    );

    // ── InfoSections ─────────────────────────────────────────
    await customStatement(
      'CREATE VIRTUAL TABLE info_fts USING fts5('
      "entity_id UNINDEXED, title, body, tokenize='trigram')",
    );
    await customStatement(
      'CREATE TRIGGER info_ai AFTER INSERT ON info_sections BEGIN '
      'INSERT INTO info_fts(entity_id, title, body) '
      'VALUES(new.id, new.title, new.body); END',
    );
    await customStatement(
      'CREATE TRIGGER info_ad AFTER DELETE ON info_sections BEGIN '
      'DELETE FROM info_fts WHERE entity_id = old.id; END',
    );
    await customStatement(
      'CREATE TRIGGER info_au AFTER UPDATE ON info_sections BEGIN '
      'DELETE FROM info_fts WHERE entity_id = old.id; '
      'INSERT INTO info_fts(entity_id, title, body) '
      'VALUES(new.id, new.title, new.body); END',
    );
  }

  /// 以 FTS5 MATCH 取得命中的 entity_id 清單。
  Future<List<String>> ftsMatch(String ftsTable, String query) async {
    final List<QueryRow> rows = await customSelect(
      'SELECT entity_id FROM $ftsTable WHERE $ftsTable MATCH ?',
      variables: <Variable<Object>>[Variable<String>(query)],
    ).get();
    return rows.map((QueryRow r) => r.read<String>('entity_id')).toList();
  }
}

/// 全域單例資料庫 provider。
final appDatabaseProvider = Provider<AppDatabase>((Ref ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
