import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/exchange_rate_repository.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/trip_repository.dart';
import '../../services/exchange_rate_service.dart';

/// 匯率管理協調器（§8a）：線上拉取 / 手動輸入 → upsert 快取 → 重算支出台幣。
class ExchangeRateController {
  ExchangeRateController({
    required this.service,
    required this.rateRepo,
    required this.tripRepo,
    required this.journalRepo,
  });

  final ExchangeRateService service;
  final ExchangeRateRepository rateRepo;
  final TripRepository tripRepo;
  final JournalRepository journalRepo;

  /// 線上拉取單一幣別 → TWD 並寫入快取（source=api）。回傳是否成功。
  Future<bool> sync(String base) async {
    try {
      final double rate = await service.fetchRate(base);
      await rateRepo.upsert(
        base: base,
        source: RateSource.api,
        rate: rate,
      );
      await recomputeAllExpenses();
      return true;
    } on Object {
      return false;
    }
  }

  /// 同步所有已存幣別對。回傳成功筆數。
  Future<int> syncAll() async {
    final List<ExchangeRateRow> rates = await rateRepo.getAllRates();
    int ok = 0;
    for (final ExchangeRateRow r in rates) {
      if (await sync(r.baseCurrency)) ok++;
    }
    return ok;
  }

  /// 手動輸入（source=manual，無過期機制）。
  Future<void> setManual(String base, double rate) async {
    await rateRepo.upsert(base: base, source: RateSource.manual, rate: rate);
    await recomputeAllExpenses();
  }

  Future<void> deleteRate(String id) => rateRepo.deleteRate(id);

  /// 以目前快取重算所有行程、所有支出的台幣金額（§8a.4 批次更新）。
  Future<void> recomputeAllExpenses() async {
    final List<ExchangeRateRow> rates = await rateRepo.getAllRates();
    final Map<String, double> rateMap = <String, double>{
      for (final ExchangeRateRow r in rates) r.baseCurrency: r.rate,
    };
    final List<TripRow> trips = await tripRepo.getTrips();
    for (final TripRow t in trips) {
      await journalRepo.recomputeTwd(
        t.id,
        (String currency) => rateMap[currency],
        onlyMissing: false,
      );
    }
  }
}

final exchangeRateControllerProvider =
    Provider<ExchangeRateController>((Ref ref) {
  return ExchangeRateController(
    service: ref.watch(exchangeRateServiceProvider),
    rateRepo: ref.watch(exchangeRateRepositoryProvider),
    tripRepo: ref.watch(tripRepositoryProvider),
    journalRepo: ref.watch(journalRepositoryProvider),
  );
});
