import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/id.dart';
import '../database/app_database.dart';
import '../models/parsed_trip.dart';

/// 行程資料的讀寫。寫入採整圖交易（Trip + Days + Spots + Flights + Info）。
class TripRepository {
  TripRepository(this._db);

  final AppDatabase _db;

  /// 將解析後的行程整圖寫入資料庫，回傳新建 Trip 的 id。
  /// 全部在單一交易內完成，任一步失敗則回滾。
  Future<String> insertParsedTrip(ParsedTrip parsed) async {
    final String tripId = Ids.newId();

    await _db.transaction(() async {
      await _db.into(_db.trips).insert(
            TripsCompanion.insert(
              id: tripId,
              tourCode: Value<String?>(parsed.tourCode),
              title: Value<String?>(parsed.title),
              startDate: Value<DateTime?>(parsed.startDate),
              endDate: Value<DateTime?>(parsed.endDate),
              leaderName: Value<String?>(parsed.leaderName),
              leaderPhoneDomestic: Value<String?>(parsed.leaderPhoneDomestic),
              leaderPhoneOverseas: Value<String?>(parsed.leaderPhoneOverseas),
              airportServiceLine: Value<String?>(parsed.airportServiceLine),
              meetupTime: Value<DateTime?>(parsed.meetupTime),
              meetupLocation: Value<String?>(parsed.meetupLocation),
              luggageTag: Value<String?>(parsed.luggageTag),
              sourcePdfPath: Value<String?>(parsed.sourcePdfPath),
              rawJson: Value<String?>(parsed.rawJson),
            ),
          );

      for (final ParsedDay day in parsed.days) {
        final String dayId = Ids.newId();
        await _db.into(_db.dayPlans).insert(
              DayPlansCompanion.insert(
                id: dayId,
                tripId: tripId,
                dayIndex: day.dayIndex,
                date: Value<DateTime?>(day.date),
                routeSummary: Value<String?>(day.routeSummary),
                hotelName: Value<String?>(day.hotelName),
                hotelNameEn: Value<String?>(day.hotelNameEn),
                hotelPhone: Value<String?>(day.hotelPhone),
                mealBreakfast: Value<String?>(day.mealBreakfast),
                mealLunch: Value<String?>(day.mealLunch),
                mealDinner: Value<String?>(day.mealDinner),
                notes: Value<String?>(day.notes),
              ),
            );

        for (final ParsedSpot spot in day.spots) {
          await _db.into(_db.spots).insert(
                SpotsCompanion.insert(
                  id: Ids.newId(),
                  dayId: dayId,
                  orderIndex: spot.orderIndex,
                  name: spot.name,
                  visitType: spot.visitType,
                  description: Value<String?>(spot.description),
                  refundNote: Value<String?>(spot.refundNote),
                  imagePath: Value<String?>(spot.imagePath),
                ),
              );
        }
      }

      for (final ParsedFlight flight in parsed.flights) {
        await _db.into(_db.flights).insert(
              FlightsCompanion.insert(
                id: Ids.newId(),
                tripId: tripId,
                dayIndex: Value<int?>(flight.dayIndex),
                flightNo: Value<String?>(flight.flightNo),
                carrier: Value<String?>(flight.carrier),
                departTime: Value<DateTime?>(flight.departTime),
                arriveTime: Value<DateTime?>(flight.arriveTime),
                fromAirport: Value<String?>(flight.fromAirport),
                toAirport: Value<String?>(flight.toAirport),
              ),
            );
      }

      for (final ParsedInfoSection info in parsed.infoSections) {
        await _db.into(_db.infoSections).insert(
              InfoSectionsCompanion.insert(
                id: Ids.newId(),
                tripId: tripId,
                category: info.category,
                title: info.title,
                body: info.body,
                orderIndex: info.orderIndex,
              ),
            );
      }
    });

    return tripId;
  }

  // ── 讀取 ────────────────────────────────────────────────────

  Stream<List<TripRow>> watchTrips() {
    return (_db.select(_db.trips)
          ..orderBy(<OrderClauseGenerator<$TripsTable>>[
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  Future<List<TripRow>> getTrips() => _db.select(_db.trips).get();

  Future<TripRow?> getTrip(String id) {
    return (_db.select(_db.trips)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Stream<TripRow?> watchTrip(String id) {
    return (_db.select(_db.trips)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<List<DayPlanRow>> getDays(String tripId) {
    return (_db.select(_db.dayPlans)
          ..where((d) => d.tripId.equals(tripId))
          ..orderBy(<OrderClauseGenerator<$DayPlansTable>>[
            (d) => OrderingTerm.asc(d.dayIndex),
          ]))
        .get();
  }

  Stream<List<DayPlanRow>> watchDays(String tripId) {
    return (_db.select(_db.dayPlans)
          ..where((d) => d.tripId.equals(tripId))
          ..orderBy(<OrderClauseGenerator<$DayPlansTable>>[
            (d) => OrderingTerm.asc(d.dayIndex),
          ]))
        .watch();
  }

  Future<DayPlanRow?> getDayByIndex(String tripId, int dayIndex) {
    return (_db.select(_db.dayPlans)
          ..where((d) => d.tripId.equals(tripId) & d.dayIndex.equals(dayIndex)))
        .getSingleOrNull();
  }

  Future<List<SpotRow>> getSpotsForDay(String dayId) {
    return (_db.select(_db.spots)
          ..where((s) => s.dayId.equals(dayId))
          ..orderBy(<OrderClauseGenerator<$SpotsTable>>[
            (s) => OrderingTerm.asc(s.orderIndex),
          ]))
        .get();
  }

  Future<SpotRow?> getSpot(String spotId) {
    return (_db.select(_db.spots)..where((s) => s.id.equals(spotId)))
        .getSingleOrNull();
  }

  Future<List<FlightRow>> getFlights(String tripId) {
    return (_db.select(_db.flights)..where((f) => f.tripId.equals(tripId)))
        .get();
  }

  Future<List<InfoSectionRow>> getInfoSections(String tripId) {
    return (_db.select(_db.infoSections)
          ..where((i) => i.tripId.equals(tripId))
          ..orderBy(<OrderClauseGenerator<$InfoSectionsTable>>[
            (i) => OrderingTerm.asc(i.orderIndex),
          ]))
        .get();
  }

  Future<void> deleteTrip(String id) async {
    // 明確逐表刪除子節點（不倚賴 DB 外鍵 cascade），於單一交易內完成。
    await _db.transaction(() async {
      final List<DayPlanRow> days = await getDays(id);
      for (final DayPlanRow d in days) {
        await (_db.delete(_db.spots)..where((s) => s.dayId.equals(d.id))).go();
      }
      await (_db.delete(_db.dayPlans)..where((d) => d.tripId.equals(id))).go();
      await (_db.delete(_db.flights)..where((f) => f.tripId.equals(id))).go();
      await (_db.delete(_db.infoSections)..where((i) => i.tripId.equals(id)))
          .go();
      await (_db.delete(_db.reminders)..where((r) => r.tripId.equals(id))).go();
      await (_db.delete(_db.journalEntries)..where((j) => j.tripId.equals(id)))
          .go();
      await (_db.delete(_db.trips)..where((t) => t.id.equals(id))).go();
    });
  }
}

final tripRepositoryProvider = Provider<TripRepository>((Ref ref) {
  return TripRepository(ref.watch(appDatabaseProvider));
});
