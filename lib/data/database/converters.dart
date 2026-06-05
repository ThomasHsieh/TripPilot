import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/enums.dart';

/// Drift TypeConverter 集合：將資料庫的 TEXT 欄位與 Dart enum / 結構互轉。
/// 採用 enum 的 `wireName` 字串而非 index，避免 migration 時序風險。

class VisitTypeConverter extends TypeConverter<VisitType, String> {
  const VisitTypeConverter();
  @override
  VisitType fromSql(String fromDb) => VisitType.fromWire(fromDb);
  @override
  String toSql(VisitType value) => value.wireName;
}

class InfoCategoryConverter extends TypeConverter<InfoCategory, String> {
  const InfoCategoryConverter();
  @override
  InfoCategory fromSql(String fromDb) => InfoCategory.fromWire(fromDb);
  @override
  String toSql(InfoCategory value) => value.wireName;
}

class ReminderRefTypeConverter extends TypeConverter<ReminderRefType, String> {
  const ReminderRefTypeConverter();
  @override
  ReminderRefType fromSql(String fromDb) => ReminderRefType.fromWire(fromDb);
  @override
  String toSql(ReminderRefType value) => value.wireName;
}

class EntryTypeConverter extends TypeConverter<EntryType, String> {
  const EntryTypeConverter();
  @override
  EntryType fromSql(String fromDb) => EntryType.fromWire(fromDb);
  @override
  String toSql(EntryType value) => value.wireName;
}

class RateSourceConverter extends TypeConverter<RateSource, String> {
  const RateSourceConverter();
  @override
  RateSource fromSql(String fromDb) => RateSource.fromWire(fromDb);
  @override
  String toSql(RateSource value) => value.wireName;
}

class ExpenseCategoryConverter extends TypeConverter<ExpenseCategory, String> {
  const ExpenseCategoryConverter();
  @override
  ExpenseCategory fromSql(String fromDb) => ExpenseCategory.fromWire(fromDb);
  @override
  String toSql(ExpenseCategory value) => value.wireName;
}

/// 相片路徑陣列以 JSON array 字串存於單一 TEXT 欄位（規格 §3.7 photo_paths）。
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const <String>[];
    final Object? decoded = jsonDecode(fromDb);
    if (decoded is List) {
      return decoded.map((Object? e) => e.toString()).toList();
    }
    return const <String>[];
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}
