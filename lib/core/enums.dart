/// 跨層共用列舉。對應規格 §3 各 table 的 enum 欄位。
///
/// 所有 enum 以 `wireName` 與資料庫/JSON 的字串值互轉，避免直接依賴
/// Dart enum 的 index（migration 安全）。
library;

/// Spot.visit_type
enum VisitType {
  enter('enter'),
  photo('photo'),
  driveBy('drive_by');

  const VisitType(this.wireName);
  final String wireName;

  static VisitType fromWire(String? value) {
    return VisitType.values.firstWhere(
      (VisitType v) => v.wireName == value,
      orElse: () => VisitType.enter,
    );
  }
}

/// InfoSection.category
enum InfoCategory {
  notice('notice'),
  tipping('tipping'),
  baggage('baggage'),
  hotel('hotel'),
  safety('safety'),
  customs('customs'),
  health('health'),
  guide('guide');

  const InfoCategory(this.wireName);
  final String wireName;

  static InfoCategory fromWire(String? value) {
    return InfoCategory.values.firstWhere(
      (InfoCategory c) => c.wireName == value,
      orElse: () => InfoCategory.notice,
    );
  }
}

/// Reminder.ref_type
enum ReminderRefType {
  meetup('meetup'),
  flight('flight'),
  dayStart('day_start'),
  custom('custom');

  const ReminderRefType(this.wireName);
  final String wireName;

  static ReminderRefType fromWire(String? value) {
    return ReminderRefType.values.firstWhere(
      (ReminderRefType t) => t.wireName == value,
      orElse: () => ReminderRefType.custom,
    );
  }
}

/// JournalEntry.entry_type
enum EntryType {
  note('note'),
  photo('photo'),
  expense('expense');

  const EntryType(this.wireName);
  final String wireName;

  static EntryType fromWire(String? value) {
    return EntryType.values.firstWhere(
      (EntryType t) => t.wireName == value,
      orElse: () => EntryType.note,
    );
  }
}

/// ExchangeRate.source
enum RateSource {
  api('api'),
  manual('manual');

  const RateSource(this.wireName);
  final String wireName;

  static RateSource fromWire(String? value) {
    return RateSource.values.firstWhere(
      (RateSource s) => s.wireName == value,
      orElse: () => RateSource.manual,
    );
  }
}

/// 支出類別（JournalEntry 為 expense 時，以 location_label 之外的欄位無法承載，
/// 故支出類別存於 JournalEntry.text 之外的專屬欄位 expenseCategory）。
enum ExpenseCategory {
  food('food'),
  transport('transport'),
  shopping('shopping'),
  ticket('ticket'),
  lodging('lodging'),
  other('other');

  const ExpenseCategory(this.wireName);
  final String wireName;

  static ExpenseCategory fromWire(String? value) {
    return ExpenseCategory.values.firstWhere(
      (ExpenseCategory c) => c.wireName == value,
      orElse: () => ExpenseCategory.other,
    );
  }
}

/// 匯出範圍
enum ExportScope { all, expenseOnly, notesOnly, dateRange }

/// 匯出格式
enum ExportFormat { pdf, csv }
