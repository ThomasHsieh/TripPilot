import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';

/// 全行程全文檢索結果，分三類（規格 §5.6）。
@immutable
class SearchResults {
  const SearchResults({
    this.spots = const <SpotRow>[],
    this.days = const <DayPlanRow>[],
    this.info = const <InfoSectionRow>[],
  });

  final List<SpotRow> spots;
  final List<DayPlanRow> days;
  final List<InfoSectionRow> info;

  bool get isEmpty => spots.isEmpty && days.isEmpty && info.isEmpty;
}

/// FTS5（trigram）全文檢索；查詢字 < 3 字元或 FTS 失敗時降級為 LIKE。
class SearchRepository {
  SearchRepository(this._db);

  final AppDatabase _db;

  /// trigram tokenizer 至少需 3 個字元；不足者改用 LIKE 子字串。
  static const int _ftsMinChars = 3;

  Future<SearchResults> search(String tripId, String rawQuery) async {
    final String query = rawQuery.trim();
    if (query.isEmpty) return const SearchResults();

    final bool useFts = query.runes.length >= _ftsMinChars;
    // 該行程的所有 dayId（用於把 spot 命中限縮在本行程）。
    final List<DayPlanRow> tripDays = await (_db.select(_db.dayPlans)
          ..where((d) => d.tripId.equals(tripId)))
        .get();
    final List<String> tripDayIds =
        tripDays.map((DayPlanRow d) => d.id).toList();

    final List<SpotRow> spots = await _searchSpots(query, useFts, tripDayIds);
    final List<DayPlanRow> days = await _searchDays(query, useFts, tripId);
    final List<InfoSectionRow> info = await _searchInfo(query, useFts, tripId);

    return SearchResults(spots: spots, days: days, info: info);
  }

  String _phrase(String q) => '"${q.replaceAll('"', '""')}"';
  String _like(String q) => '%$q%';

  Future<List<SpotRow>> _searchSpots(
    String query,
    bool useFts,
    List<String> tripDayIds,
  ) async {
    if (tripDayIds.isEmpty) return const <SpotRow>[];
    List<String>? matchedIds;
    if (useFts) {
      try {
        matchedIds = await _db.ftsMatch('spots_fts', _phrase(query));
      } on Object {
        matchedIds = null;
      }
    }

    final selectable = _db.select(_db.spots);
    if (matchedIds != null) {
      final List<String> ids = matchedIds;
      selectable.where((s) => s.id.isIn(ids) & s.dayId.isIn(tripDayIds));
    } else {
      final String pattern = _like(query);
      selectable.where(
        (s) =>
            s.dayId.isIn(tripDayIds) &
            (s.name.like(pattern) | s.description.like(pattern)),
      );
    }
    return selectable.get();
  }

  Future<List<DayPlanRow>> _searchDays(
    String query,
    bool useFts,
    String tripId,
  ) async {
    List<String>? matchedIds;
    if (useFts) {
      try {
        matchedIds = await _db.ftsMatch('days_fts', _phrase(query));
      } on Object {
        matchedIds = null;
      }
    }

    final selectable = _db.select(_db.dayPlans)
      ..where((d) => d.tripId.equals(tripId));
    if (matchedIds != null) {
      final List<String> ids = matchedIds;
      selectable.where((d) => d.id.isIn(ids));
    } else {
      final String pattern = _like(query);
      selectable.where(
        (d) => d.routeSummary.like(pattern) | d.hotelName.like(pattern),
      );
    }
    return selectable.get();
  }

  Future<List<InfoSectionRow>> _searchInfo(
    String query,
    bool useFts,
    String tripId,
  ) async {
    List<String>? matchedIds;
    if (useFts) {
      try {
        matchedIds = await _db.ftsMatch('info_fts', _phrase(query));
      } on Object {
        matchedIds = null;
      }
    }

    final selectable = _db.select(_db.infoSections)
      ..where((i) => i.tripId.equals(tripId));
    if (matchedIds != null) {
      final List<String> ids = matchedIds;
      selectable.where((i) => i.id.isIn(ids));
    } else {
      final String pattern = _like(query);
      selectable.where(
        (i) => i.title.like(pattern) | i.body.like(pattern),
      );
    }
    return selectable.get();
  }
}

final searchRepositoryProvider = Provider<SearchRepository>((Ref ref) {
  return SearchRepository(ref.watch(appDatabaseProvider));
});
