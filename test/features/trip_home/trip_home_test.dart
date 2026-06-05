import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_pilot/data/database/app_database.dart';
import 'package:trip_pilot/features/trip_home/trip_home_screen.dart';
import 'package:trip_pilot/features/trip_home/trip_providers.dart';
import 'package:trip_pilot/l10n/generated/app_localizations.dart';

/// 以固定資料覆寫 provider（不碰 drift），驗證 TripHome 渲染。

TripRow _trip() {
  final DateTime today = DateTime.now();
  return TripRow(
    id: 't1',
    tourCode: 'NSC061306BR6',
    title: '東北六日',
    startDate: today.subtract(const Duration(days: 1)),
    endDate: today.add(const Duration(days: 4)),
    leaderName: '康晋文',
    leaderPhoneDomestic: '0922339061',
    createdAt: today,
  );
}

List<DayPlanRow> _days() {
  final DateTime today = DateTime.now();
  return <DayPlanRow>[
    const DayPlanRow(
        id: 'd1', tripId: 't1', dayIndex: 1, routeSummary: '桃園 / 青森'),
    DayPlanRow(
      id: 'd2',
      tripId: 't1',
      dayIndex: 2,
      date: today,
      routeSummary: '秋田漫遊',
      hotelName: '田澤湖 LAKE RESORT',
      hotelPhone: '0187-46-2016',
      mealBreakfast: '飯店早餐',
    ),
  ];
}

void main() {
  testWidgets('TripHome 顯示領隊與今日卡片', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          tripProvider.overrideWith(
            (Ref ref, String id) => Stream<TripRow?>.value(_trip()),
          ),
          tripDaysProvider.overrideWith(
            (Ref ref, String id) => Stream<List<DayPlanRow>>.value(_days()),
          ),
          tripFlightsProvider.overrideWith(
            (Ref ref, String id) async => const <FlightRow>[],
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripHomeScreen(tripId: 't1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('康晋文'), findsOneWidget);
    expect(find.textContaining('0922339061'), findsOneWidget);
    expect(find.text('秋田漫遊'), findsOneWidget);
  });

  test('activeDayIndex：旅途中回正確天數、區間外回 null', () {
    final TripRow trip = _trip();
    expect(activeDayIndex(trip), 2); // 今天 = 第 2 天
    final DateTime before = trip.startDate!.subtract(const Duration(days: 7));
    expect(activeDayIndex(trip, now: before), isNull);
  });
}
