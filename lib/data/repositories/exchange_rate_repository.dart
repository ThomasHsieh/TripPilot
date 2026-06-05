import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../database/app_database.dart';

/// 匯率快取讀寫（規格 §3.8 / §8a）。同一 base/quote 對僅保留一筆（upsert）。
class ExchangeRateRepository {
  ExchangeRateRepository(this._db);

  final AppDatabase _db;

  static String pairId(String base, String quote) => '${base}_$quote';

  /// 寫入或覆寫一筆匯率（upsert）。
  Future<void> upsert({
    required String base,
    required RateSource source,
    required double rate,
    String quote = AppConstants.quoteCurrency,
    DateTime? fetchedAt,
  }) async {
    final ExchangeRatesCompanion row = ExchangeRatesCompanion.insert(
      id: pairId(base, quote),
      baseCurrency: base,
      quoteCurrency: quote,
      rate: rate,
      source: source,
      fetchedAt: fetchedAt ?? DateTime.now(),
    );
    await _db.into(_db.exchangeRates).insertOnConflictUpdate(row);
  }

  Future<ExchangeRateRow?> getRate(
    String base, {
    String quote = AppConstants.quoteCurrency,
  }) {
    return (_db.select(_db.exchangeRates)
          ..where((r) => r.id.equals(pairId(base, quote))))
        .getSingleOrNull();
  }

  Future<List<ExchangeRateRow>> getAllRates() {
    return (_db.select(_db.exchangeRates)
          ..orderBy(<OrderClauseGenerator<$ExchangeRatesTable>>[
            (r) => OrderingTerm.asc(r.baseCurrency),
          ]))
        .get();
  }

  Stream<List<ExchangeRateRow>> watchRates() {
    return (_db.select(_db.exchangeRates)
          ..orderBy(<OrderClauseGenerator<$ExchangeRatesTable>>[
            (r) => OrderingTerm.asc(r.baseCurrency),
          ]))
        .watch();
  }

  Future<void> deleteRate(String id) async {
    await (_db.delete(_db.exchangeRates)..where((r) => r.id.equals(id))).go();
  }

  /// 是否過期（> 6 小時）且為線上來源，需顯示橘色警示。手動值不過期。
  static bool isStale(ExchangeRateRow row) {
    if (row.source != RateSource.api) return false;
    final Duration age = DateTime.now().difference(row.fetchedAt);
    return age.inHours >= AppConstants.rateStaleHours;
  }
}

final exchangeRateRepositoryProvider =
    Provider<ExchangeRateRepository>((Ref ref) {
  return ExchangeRateRepository(ref.watch(appDatabaseProvider));
});
