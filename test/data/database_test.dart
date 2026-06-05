import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_pilot/core/enums.dart';
import 'package:trip_pilot/data/database/app_database.dart';
import 'package:trip_pilot/data/models/parsed_trip.dart';
import 'package:trip_pilot/data/repositories/exchange_rate_repository.dart';
import 'package:trip_pilot/data/repositories/journal_repository.dart';
import 'package:trip_pilot/data/repositories/search_repository.dart';
import 'package:trip_pilot/data/repositories/trip_repository.dart';

/// M1 資料層回歸測試。需先執行 `dart run build_runner build` 產生 *.g.dart。
/// 注意：FTS 測試需 host sqlite3 支援 FTS5 + trigram（SQLite >= 3.34）。
void main() {
  late AppDatabase db;
  late TripRepository trips;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    trips = TripRepository(db);
  });

  tearDown(() async => db.close());

  ParsedTrip sample() => ParsedTrip(
        tourCode: 'NSC061306BR6',
        title: '東北仙境傳說六日',
        startDate: DateTime(2026, 6, 13),
        endDate: DateTime(2026, 6, 18),
        leaderName: '康晉文',
        leaderPhoneDomestic: '0922339061',
        flights: <ParsedFlight>[
          ParsedFlight(
            dayIndex: 1,
            flightNo: 'BR122',
            carrier: '長榮航空',
            departTime: DateTime(2026, 6, 13, 9, 55),
            arriveTime: DateTime(2026, 6, 13, 14, 20),
            fromAirport: '台北(桃園)',
            toAirport: '青森縣',
          ),
        ],
        days: <ParsedDay>[
          ParsedDay(
            dayIndex: 1,
            date: DateTime(2026, 6, 13),
            routeSummary: '桃園 / 青森',
            hotelName: '十和田莊',
            hotelPhone: '0176-75-2221',
            spots: const <ParsedSpot>[
              ParsedSpot(orderIndex: 1, name: '奧入瀨溪流'),
            ],
          ),
          ParsedDay(
            dayIndex: 2,
            date: DateTime(2026, 6, 14),
            routeSummary: '秋田',
            hotelName: '田澤湖 LAKE RESORT',
          ),
        ],
        infoSections: const <ParsedInfoSection>[
          ParsedInfoSection(
            category: InfoCategory.customs,
            title: '退稅規定',
            body: '購物時請保留收據以辦理退稅手續，鋰電池須隨身攜帶。',
            orderIndex: 1,
          ),
        ],
      );

  test('整圖寫入與讀回', () async {
    final String tripId = await trips.insertParsedTrip(sample());

    final all = await trips.getTrips();
    expect(all, hasLength(1));
    expect(all.first.tourCode, 'NSC061306BR6');

    final days = await trips.getDays(tripId);
    expect(days, hasLength(2));
    expect(days.first.dayIndex, 1);
    expect(days.first.hotelPhone, '0176-75-2221');

    final spots = await trips.getSpotsForDay(days.first.id);
    expect(spots, hasLength(1));
    expect(spots.first.name, '奧入瀨溪流');
    expect(spots.first.visitType, VisitType.enter);

    final flights = await trips.getFlights(tripId);
    expect(flights.single.flightNo, 'BR122');

    final info = await trips.getInfoSections(tripId);
    expect(info.single.category, InfoCategory.customs);
  });

  test('刪除行程級聯', () async {
    final String tripId = await trips.insertParsedTrip(sample());
    await trips.deleteTrip(tripId);
    expect(await trips.getTrips(), isEmpty);
    expect(await trips.getDays(tripId), isEmpty);
  });

  test('搜尋：FTS（3 字）與 LIKE（2 字）兩路徑', () async {
    final String tripId = await trips.insertParsedTrip(sample());
    final SearchRepository search = SearchRepository(db);

    final r1 = await search.search(tripId, '奧入瀨'); // 3 字 → FTS
    expect(r1.spots.map((s) => s.name), contains('奧入瀨溪流'));

    final r2 = await search.search(tripId, '退稅'); // 2 字 → LIKE
    expect(r2.info.map((i) => i.title), contains('退稅規定'));
  });

  test('支出加總與台幣換算', () async {
    final String tripId = await trips.insertParsedTrip(sample());
    final JournalRepository journal = JournalRepository(db);

    await journal.addExpense(
      tripId,
      amount: 18500,
      currency: 'JPY',
      category: ExpenseCategory.shopping,
      amountTwd: 18500 * 0.215,
      rateUsed: 0.215,
    );
    await journal.addExpense(
      tripId,
      amount: 420,
      currency: 'TWD',
      category: ExpenseCategory.food,
    );

    final totals = await journal.totals(tripId);
    expect(totals.byCurrency['JPY'], 18500);
    expect(totals.byCurrency['TWD'], 420);
    expect(totals.allConverted, isTrue);
    // 18500 * 0.215 = 3977.5，加上 TWD 420 = 4397.5
    expect(totals.convertedTwd, closeTo(4397.5, 0.001));
  });

  test('匯率 upsert 與過期判斷', () async {
    final ExchangeRateRepository rates = ExchangeRateRepository(db);

    await rates.upsert(base: 'JPY', source: RateSource.api, rate: 0.215);
    final row = await rates.getRate('JPY');
    expect(row, isNotNull);
    expect(row!.rate, 0.215);
    expect(ExchangeRateRepository.isStale(row), isFalse);

    // 覆寫同一對只保留一筆。
    await rates.upsert(base: 'JPY', source: RateSource.manual, rate: 0.22);
    expect(await rates.getAllRates(), hasLength(1));

    // 7 小時前的線上匯率 → 過期。
    await rates.upsert(
      base: 'USD',
      source: RateSource.api,
      rate: 31.5,
      fetchedAt: DateTime.now().subtract(const Duration(hours: 7)),
    );
    final usd = await rates.getRate('USD');
    expect(ExchangeRateRepository.isStale(usd!), isTrue);
  });
}
