import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../data/repositories/trip_repository.dart';
import 'trip_json_mapper.dart';

/// 開發用：載入內建範例行程（NSC061306BR6）的 §4.3 JSON 資產，
/// 經與線上解析相同的 mapper 寫入 Drift。回傳新 Trip id。
///
/// 這也是「貼上 JSON 匯入」（訂閱友善路徑）的核心：來源換成使用者貼上的字串即可。
Future<String> loadSampleTrip(TripRepository repo) async {
  final String raw =
      await rootBundle.loadString('assets/sample/nsc061306br6.json');
  return importTripFromJsonString(repo, raw);
}

/// 由 JSON 字串匯入一筆行程（容錯 mapper；失敗會丟 FormatException）。
Future<String> importTripFromJsonString(
  TripRepository repo,
  String jsonString,
) async {
  final Object? decoded = jsonDecode(jsonString);
  if (decoded is! Map) {
    throw const FormatException('JSON 根節點必須是物件');
  }
  final Map<String, dynamic> map = decoded.map(
    (Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v),
  );
  final trip = mapClaudeJson(map, rawJson: jsonString);
  return repo.insertParsedTrip(trip);
}
