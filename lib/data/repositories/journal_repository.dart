import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/id.dart';
import '../database/app_database.dart';

/// 依幣別分組的支出加總結果（規格 §5.8）。
@immutable
class ExpenseTotals {
  const ExpenseTotals({
    required this.byCurrency,
    required this.convertedTwd,
    required this.allConverted,
  });

  /// 各原始幣別的加總，例 `{JPY: 18500, TWD: 420}`。
  final Map<String, double> byCurrency;

  /// 已換算的台幣合計（僅計入有 amount_twd 的支出）。
  final double convertedTwd;

  /// 是否所有非 TWD 支出都已換算（false 代表合計僅為部分）。
  final bool allConverted;
}

/// 旅遊札記 / 相片 / 支出的讀寫與加總。
class JournalRepository {
  JournalRepository(this._db);

  final AppDatabase _db;

  Stream<List<JournalEntryRow>> watchEntries(String tripId, {EntryType? type}) {
    final query = _db.select(_db.journalEntries)
      ..where((e) => e.tripId.equals(tripId))
      ..orderBy(<OrderClauseGenerator<$JournalEntriesTable>>[
        (e) => OrderingTerm.desc(e.createdAt),
      ]);
    if (type != null) {
      query.where((e) => e.entryType.equalsValue(type));
    }
    return query.watch();
  }

  Future<String> insertEntry(JournalEntriesCompanion entry) async {
    final String id = entry.id.present ? entry.id.value : Ids.newId();
    await _db
        .into(_db.journalEntries)
        .insert(entry.copyWith(id: Value<String>(id)));
    return id;
  }

  Future<String> addNote(
    String tripId, {
    required String text,
    int? dayIndex,
    List<String> photoPaths = const <String>[],
    String? locationLabel,
  }) {
    return insertEntry(
      JournalEntriesCompanion.insert(
        id: Ids.newId(),
        tripId: tripId,
        entryType: photoPaths.isEmpty ? EntryType.note : EntryType.photo,
        dayIndex: Value<int?>(dayIndex),
        entryText: Value<String?>(text),
        photoPaths: Value<List<String>>(photoPaths),
        locationLabel: Value<String?>(locationLabel),
      ),
    );
  }

  Future<String> addExpense(
    String tripId, {
    required double amount,
    required String currency,
    required ExpenseCategory category,
    int? dayIndex,
    String? note,
    double? amountTwd,
    double? rateUsed,
    DateTime? date,
  }) {
    return insertEntry(
      JournalEntriesCompanion.insert(
        id: Ids.newId(),
        tripId: tripId,
        entryType: EntryType.expense,
        dayIndex: Value<int?>(dayIndex),
        entryText: Value<String?>(note),
        amount: Value<double?>(amount),
        currency: Value<String?>(currency),
        expenseCategory: Value<ExpenseCategory?>(category),
        amountTwd: Value<double?>(amountTwd),
        exchangeRateUsed: Value<double?>(rateUsed),
        createdAt: date == null
            ? const Value<DateTime>.absent()
            : Value<DateTime>(date),
      ),
    );
  }

  Future<void> updateEntry(JournalEntryRow row) =>
      _db.update(_db.journalEntries).replace(row);

  Future<void> deleteEntry(String id) async {
    await (_db.delete(_db.journalEntries)..where((e) => e.id.equals(id))).go();
  }

  Future<List<JournalEntryRow>> getExpenses(String tripId) {
    return (_db.select(_db.journalEntries)
          ..where(
            (e) =>
                e.tripId.equals(tripId) &
                e.entryType.equalsValue(EntryType.expense),
          ))
        .get();
  }

  /// 依幣別加總（原始幣別），並計算已換算台幣合計。精度交由顯示層處理。
  Future<ExpenseTotals> totals(String tripId) async {
    final List<JournalEntryRow> expenses = await getExpenses(tripId);
    final Map<String, double> byCurrency = <String, double>{};
    double convertedTwd = 0;
    bool allConverted = true;

    for (final JournalEntryRow e in expenses) {
      final double amount = e.amount ?? 0;
      final String currency = e.currency ?? 'JPY';
      byCurrency.update(
        currency,
        (double v) => v + amount,
        ifAbsent: () => amount,
      );

      if (currency == 'TWD') {
        convertedTwd += amount;
      } else if (e.amountTwd != null) {
        convertedTwd += e.amountTwd!;
      } else {
        allConverted = false;
      }
    }

    return ExpenseTotals(
      byCurrency: byCurrency,
      convertedTwd: convertedTwd,
      allConverted: allConverted,
    );
  }

  /// 重新計算所有未換算（或全部）支出的台幣金額。
  /// [rateFor] 回傳某幣別 → TWD 的匯率；回傳 null 表示無匯率（略過該筆）。
  /// 見規格 §8a.4。
  Future<int> recomputeTwd(
    String tripId,
    double? Function(String currency) rateFor, {
    bool onlyMissing = true,
  }) async {
    final List<JournalEntryRow> expenses = await getExpenses(tripId);
    int updated = 0;

    await _db.transaction(() async {
      for (final JournalEntryRow e in expenses) {
        if (onlyMissing && e.amountTwd != null) continue;
        final String currency = e.currency ?? 'JPY';
        if (currency == 'TWD') continue;
        final double? rate = rateFor(currency);
        if (rate == null || e.amount == null) continue;

        await (_db.update(_db.journalEntries)
              ..where((row) => row.id.equals(e.id)))
            .write(
          JournalEntriesCompanion(
            amountTwd: Value<double?>(e.amount! * rate),
            exchangeRateUsed: Value<double?>(rate),
          ),
        );
        updated++;
      }
    });

    return updated;
  }
}

final journalRepositoryProvider = Provider<JournalRepository>((Ref ref) {
  return JournalRepository(ref.watch(appDatabaseProvider));
});
