import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_pilot/core/enums.dart';
import 'package:trip_pilot/data/database/app_database.dart';
import 'package:trip_pilot/data/models/parsed_trip.dart';
import 'package:trip_pilot/data/repositories/exchange_rate_repository.dart';
import 'package:trip_pilot/data/repositories/journal_repository.dart';
import 'package:trip_pilot/data/repositories/trip_repository.dart';
import 'package:trip_pilot/features/exchange_rate/exchange_rate_controller.dart';
import 'package:trip_pilot/services/exchange_rate_service.dart';

http.Response _json(Map<String, Object?> body) =>
    http.Response(jsonEncode(body), 200);

void main() {
  group('ExchangeRateService', () {
    test('Frankfurter 無 TWD → 降級 er-api', () async {
      final MockClient client = MockClient((http.Request req) async {
        if (req.url.host.contains('frankfurter')) {
          return _json(<String, Object?>{'rates': <String, Object?>{}});
        }
        return _json(<String, Object?>{
          'rates': <String, Object?>{'TWD': 0.215},
        });
      });
      final ExchangeRateService svc = ExchangeRateService(client: client);
      expect(await svc.fetchRate('JPY'), closeTo(0.215, 1e-9));
    });

    test('Frankfurter 有值 → 直接採用', () async {
      final MockClient client = MockClient((http.Request req) async {
        if (req.url.host.contains('frankfurter')) {
          return _json(<String, Object?>{
            'rates': <String, Object?>{'TWD': 0.21},
          });
        }
        return http.Response('should not reach', 500);
      });
      final ExchangeRateService svc = ExchangeRateService(client: client);
      expect(await svc.fetchRate('JPY'), closeTo(0.21, 1e-9));
    });

    test('兩來源皆失敗 → 丟例外', () async {
      final MockClient client =
          MockClient((http.Request req) async => http.Response('err', 500));
      final ExchangeRateService svc = ExchangeRateService(client: client);
      expect(
        () => svc.fetchRate('JPY'),
        throwsA(isA<ExchangeRateException>()),
      );
    });
  });

  group('ExchangeRateController 重算（§8a.4）', () {
    late AppDatabase db;
    late ExchangeRateController controller;
    late JournalRepository journal;
    late TripRepository trips;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      trips = TripRepository(db);
      journal = JournalRepository(db);
      controller = ExchangeRateController(
        service: ExchangeRateService(
          client: MockClient((_) async => http.Response('', 500)),
        ),
        rateRepo: ExchangeRateRepository(db),
        tripRepo: trips,
        journalRepo: journal,
      );
    });
    tearDown(() async => db.close());

    test('手動設定匯率後重算未換算支出', () async {
      final String tripId = await trips.insertParsedTrip(const ParsedTrip());
      await journal.addExpense(
        tripId,
        amount: 1000,
        currency: 'JPY',
        category: ExpenseCategory.food,
      ); // amountTwd 初始為 null

      await controller.setManual('JPY', 0.2);

      final List<JournalEntryRow> entries =
          await db.select(db.journalEntries).get();
      expect(entries.single.amountTwd, closeTo(200, 1e-9));
      expect(entries.single.exchangeRateUsed, 0.2);
    });
  });
}
