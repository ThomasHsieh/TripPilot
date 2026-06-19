import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_pilot/data/database/app_database.dart';
import 'package:trip_pilot/data/repositories/trip_repository.dart';
import 'package:trip_pilot/features/settings/settings_controller.dart';
import 'package:trip_pilot/features/trip_home/trip_providers.dart';
import 'package:trip_pilot/main.dart';

/// 假 TripRepository：回傳固定行程，避免 testWidgets 下跑真實 drift。
class _FakeTripRepo extends TripRepository {
  _FakeTripRepo(super.db, this._trips);
  final List<TripRow> _trips;
  @override
  Future<List<TripRow>> getTrips() async => _trips;
}

TripRow _trip() => TripRow(
      id: 't1',
      tourCode: 'NSC061306BR6',
      title: '東北六日',
      leaderName: '王小明',
      leaderPhoneDomestic: '0912345678',
      createdAt: DateTime.now(),
    );

void main() {
  testWidgets('開啟 App 直接進入行程首頁', (WidgetTester tester) async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final TripRow trip = _trip();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sharedPrefsProvider.overrideWithValue(prefs),
          tripRepositoryProvider
              .overrideWithValue(_FakeTripRepo(db, <TripRow>[trip])),
          tripProvider.overrideWith(
            (Ref ref, String id) => Stream<TripRow?>.value(trip),
          ),
          tripDaysProvider.overrideWith(
            (Ref ref, String id) => Stream<List<DayPlanRow>>.value(
              const <DayPlanRow>[],
            ),
          ),
          tripFlightsProvider.overrideWith(
            (Ref ref, String id) async => const <FlightRow>[],
          ),
        ],
        child: const TripPilotApp(),
      ),
    );
    // bootstrap → 導向行程首頁（不使用 pumpAndSettle，避免 spinner 卡住）。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('王小明'), findsOneWidget);
  });
}
