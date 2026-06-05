import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/parsed_trip.dart';
import '../../data/repositories/trip_repository.dart';
import 'trip_json_mapper.dart';

/// 預覽編輯狀態：可逐欄修正的 [ParsedTrip] 工作副本 + 合理性警告。
@immutable
class PreviewState {
  const PreviewState({
    required this.trip,
    required this.warnings,
    this.saving = false,
  });

  final ParsedTrip trip;
  final List<TripWarning> warnings;
  final bool saving;

  PreviewState copyWith({
    ParsedTrip? trip,
    List<TripWarning>? warnings,
    bool? saving,
  }) {
    return PreviewState(
      trip: trip ?? this.trip,
      warnings: warnings ?? this.warnings,
      saving: saving ?? this.saving,
    );
  }
}

class PreviewController extends Notifier<PreviewState?> {
  @override
  PreviewState? build() => null;

  /// 由 ImportParsed 結果初始化（進入預覽頁時呼叫一次）。
  void seed(ParsedTrip trip, List<TripWarning> warnings) {
    state = PreviewState(trip: trip, warnings: warnings);
  }

  /// 套用 header / 整體欄位修改並重新驗證。
  void updateTrip(ParsedTrip trip) {
    final PreviewState? s = state;
    if (s == null) return;
    state = s.copyWith(trip: trip, warnings: validateParsedTrip(trip));
  }

  /// 替換某一天並重新驗證。
  void updateDay(int dayIndexZeroBased, ParsedDay day) {
    final PreviewState? s = state;
    if (s == null) return;
    final List<ParsedDay> days = <ParsedDay>[...s.trip.days];
    if (dayIndexZeroBased < 0 || dayIndexZeroBased >= days.length) return;
    days[dayIndexZeroBased] = day;
    final ParsedTrip updated = s.trip.copyWith(days: days);
    state = s.copyWith(trip: updated, warnings: validateParsedTrip(updated));
  }

  /// 寫入 Drift，回傳新 Trip id；失敗回 null。
  Future<String?> save() async {
    final PreviewState? s = state;
    if (s == null) return null;
    state = s.copyWith(saving: true);
    try {
      final String tripId =
          await ref.read(tripRepositoryProvider).insertParsedTrip(s.trip);
      return tripId;
    } on Object catch (e) {
      debugPrint('Save parsed trip failed: $e');
      state = s.copyWith(saving: false);
      return null;
    }
  }

  void clear() => state = null;
}

final previewControllerProvider =
    NotifierProvider<PreviewController, PreviewState?>(PreviewController.new);
