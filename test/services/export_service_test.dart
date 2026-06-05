import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_pilot/core/enums.dart';
import 'package:trip_pilot/data/database/app_database.dart';
import 'package:trip_pilot/data/models/parsed_trip.dart';
import 'package:trip_pilot/data/repositories/journal_repository.dart';
import 'package:trip_pilot/data/repositories/trip_repository.dart';
import 'package:trip_pilot/services/export_service.dart';

/// M7c：CSV 欄位順序、BOM、amount_twd 有值（§9.3）。
void main() {
  late AppDatabase db;
  late TripRepository trips;
  late JournalRepository journal;
  const ExportService svc = ExportService();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    trips = TripRepository(db);
    journal = JournalRepository(db);
  });
  tearDown(() async => db.close());

  test('CSV：BOM + 表頭 + amount_twd', () async {
    final String tripId = await trips.insertParsedTrip(const ParsedTrip());
    await journal.addExpense(
      tripId,
      amount: 18500,
      currency: 'JPY',
      category: ExpenseCategory.shopping,
      dayIndex: 1,
      note: '伴手禮',
      amountTwd: 3977.5,
      rateUsed: 0.215,
    );
    final List<JournalEntryRow> entries =
        await db.select(db.journalEntries).get();

    final String csv = svc.buildExpenseCsv(entries);

    expect(csv.codeUnitAt(0), 0xFEFF); // UTF-8 BOM
    final List<String> lines = csv.split('\n');
    expect(
      lines.first.replaceFirst('﻿', ''),
      'date,day_index,category,currency,amount,amount_twd,'
      'exchange_rate_used,note',
    );
    expect(lines[1], contains('shopping'));
    expect(lines[1], contains('JPY'));
    expect(lines[1], contains('3977.50')); // amount_twd 兩位小數
    expect(lines[1], contains('伴手禮'));
  });

  test('CSV：含逗號的備註會被引號包住', () async {
    final String tripId = await trips.insertParsedTrip(const ParsedTrip());
    await journal.addExpense(
      tripId,
      amount: 100,
      currency: 'TWD',
      category: ExpenseCategory.food,
      note: 'a,b',
    );
    final entries = await db.select(db.journalEntries).get();
    expect(svc.buildExpenseCsv(entries), contains('"a,b"'));
  });
}
