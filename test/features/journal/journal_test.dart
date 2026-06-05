import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_pilot/core/enums.dart';
import 'package:trip_pilot/data/database/app_database.dart';
import 'package:trip_pilot/data/models/parsed_trip.dart';
import 'package:trip_pilot/data/repositories/journal_repository.dart';
import 'package:trip_pilot/data/repositories/trip_repository.dart';
import 'package:trip_pilot/features/journal/journal_providers.dart';

/// M7a：札記/相片/支出記錄與依幣別加總。
void main() {
  late AppDatabase db;
  late TripRepository trips;
  late JournalRepository journal;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    trips = TripRepository(db);
    journal = JournalRepository(db);
  });
  tearDown(() async => db.close());

  Future<String> seed() => trips.insertParsedTrip(const ParsedTrip());

  test('支出依幣別加總 + 台幣換算合計', () async {
    final String tripId = await seed();
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

    final List<JournalEntryRow> entries =
        await db.select(db.journalEntries).get();
    final byCur = sumExpensesByCurrency(entries);
    expect(byCur['JPY'], 18500);
    expect(byCur['TWD'], 420);

    final conv = convertedTwdTotal(entries);
    expect(conv.allConverted, isTrue);
    expect(conv.twd, closeTo(4397.5, 0.001));
  });

  test('未換算的外幣支出 → allConverted 為 false', () async {
    final String tripId = await seed();
    await journal.addExpense(
      tripId,
      amount: 1000,
      currency: 'JPY',
      category: ExpenseCategory.other,
    ); // 無 amountTwd
    final entries = await db.select(db.journalEntries).get();
    expect(convertedTwdTotal(entries).allConverted, isFalse);
  });

  test('札記含相片路徑可存取讀回', () async {
    final String tripId = await seed();
    await journal.addNote(
      tripId,
      text: '今天很開心',
      photoPaths: <String>['/tmp/a.jpg', '/tmp/b.jpg'],
      dayIndex: 2,
    );
    final entries = await db.select(db.journalEntries).get();
    final note = entries.single;
    expect(note.entryType, EntryType.photo); // 有相片 → photo 類型
    expect(note.entryText, '今天很開心');
    expect(note.photoPaths, hasLength(2));
    expect(note.dayIndex, 2);
  });
}
