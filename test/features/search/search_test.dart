import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_pilot/core/enums.dart';
import 'package:trip_pilot/data/database/app_database.dart';
import 'package:trip_pilot/data/models/parsed_trip.dart';
import 'package:trip_pilot/data/repositories/search_repository.dart';
import 'package:trip_pilot/data/repositories/trip_repository.dart';

/// M5：全文檢索覆蓋 §9.3 驗收關鍵字（鋰電池 / 退稅 / 平泉中尊寺）。
void main() {
  late AppDatabase db;
  late TripRepository trips;
  late SearchRepository search;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    trips = TripRepository(db);
    search = SearchRepository(db);
  });
  tearDown(() async => db.close());

  Future<String> seed() => trips.insertParsedTrip(
        const ParsedTrip(
          tourCode: 'NSC061306BR6',
          days: <ParsedDay>[
            ParsedDay(
              dayIndex: 4,
              routeSummary: '岩手縣',
              spots: <ParsedSpot>[
                ParsedSpot(
                  orderIndex: 1,
                  name: '平泉中尊寺',
                  description: '世界遺產，藤原氏華麗殿堂。',
                ),
              ],
            ),
          ],
          infoSections: <ParsedInfoSection>[
            ParsedInfoSection(
              category: InfoCategory.baggage,
              title: '航班行李',
              body: '行動電源及鋰電池須隨身攜帶，不可放入托運行李。',
              orderIndex: 1,
            ),
            ParsedInfoSection(
              category: InfoCategory.customs,
              title: '退稅規定',
              body: '購物達一定金額可辦理退稅，請出示護照。',
              orderIndex: 2,
            ),
          ],
        ),
      );

  test('搜尋景點：平泉中尊寺（FTS）', () async {
    final String tripId = await seed();
    final SearchResults r = await search.search(tripId, '平泉中尊寺');
    expect(r.spots.map((s) => s.name), contains('平泉中尊寺'));
  });

  test('搜尋須知：鋰電池（FTS, 3 字）', () async {
    final String tripId = await seed();
    final SearchResults r = await search.search(tripId, '鋰電池');
    expect(r.info.map((i) => i.title), contains('航班行李'));
  });

  test('搜尋須知：退稅（LIKE, 2 字）', () async {
    final String tripId = await seed();
    final SearchResults r = await search.search(tripId, '退稅');
    expect(r.info.map((i) => i.title), contains('退稅規定'));
  });

  test('無命中回空結果', () async {
    final String tripId = await seed();
    final SearchResults r = await search.search(tripId, '不存在的關鍵字XYZ');
    expect(r.isEmpty, isTrue);
  });
}
