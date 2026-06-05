import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_pilot/data/database/app_database.dart';
import 'package:trip_pilot/data/repositories/trip_repository.dart';
import 'package:trip_pilot/features/import/sample_loader.dart';

void main() {
  test('範例 JSON 載入後景點帶有 imagePath', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = TripRepository(db);
    final raw = await File('assets/sample/nsc061306br6.json').readAsString();
    final tripId = await importTripFromJsonString(repo, raw);

    final days = await repo.getDays(tripId);
    int withImg = 0;
    for (final d in days) {
      final spots = await repo.getSpotsForDay(d.id);
      for (final s in spots) {
        if (s.imagePath != null) {
          withImg++;
          // ignore: avoid_print
          print('${s.name} -> ${s.imagePath}');
        }
      }
    }
    expect(withImg, 12);
  });
}
