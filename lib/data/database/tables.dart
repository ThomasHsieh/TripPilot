import 'package:drift/drift.dart';

import 'converters.dart';

/// Drift 邏輯 schema（規格 §3）。所有主鍵為 TEXT(uuid)，
/// 列舉欄位以 wireName 字串存放並經 TypeConverter 還原為 Dart enum。
///
/// 註：JournalEntries 增加了 `expense_category` 欄位 —— 規格 §3.7 表格雖未列出，
///     但 §5.8 新增支出 dialog 與 §5.9 CSV 匯出皆要求「類別」欄位，屬必要延伸。

@DataClassName('TripRow')
class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get tourCode => text().named('tour_code').nullable()();
  TextColumn get title => text().nullable()();
  DateTimeColumn get startDate => dateTime().named('start_date').nullable()();
  DateTimeColumn get endDate => dateTime().named('end_date').nullable()();
  TextColumn get leaderName => text().named('leader_name').nullable()();
  TextColumn get leaderPhoneDomestic =>
      text().named('leader_phone_domestic').nullable()();
  TextColumn get leaderPhoneOverseas =>
      text().named('leader_phone_overseas').nullable()();
  TextColumn get airportServiceLine =>
      text().named('airport_service_line').nullable()();
  DateTimeColumn get meetupTime => dateTime().named('meetup_time').nullable()();
  TextColumn get meetupLocation => text().named('meetup_location').nullable()();
  TextColumn get luggageTag => text().named('luggage_tag').nullable()();
  TextColumn get sourcePdfPath => text().named('source_pdf_path').nullable()();
  TextColumn get rawJson => text().named('raw_json').nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('DayPlanRow')
class DayPlans extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()
      .named('trip_id')
      .references(Trips, #id, onDelete: KeyAction.cascade)();
  IntColumn get dayIndex => integer().named('day_index')();
  DateTimeColumn get date => dateTime().nullable()();
  TextColumn get routeSummary => text().named('route_summary').nullable()();
  TextColumn get hotelName => text().named('hotel_name').nullable()();
  TextColumn get hotelNameEn => text().named('hotel_name_en').nullable()();
  TextColumn get hotelPhone => text().named('hotel_phone').nullable()();
  TextColumn get mealBreakfast => text().named('meal_breakfast').nullable()();
  TextColumn get mealLunch => text().named('meal_lunch').nullable()();
  TextColumn get mealDinner => text().named('meal_dinner').nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('FlightRow')
class Flights extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()
      .named('trip_id')
      .references(Trips, #id, onDelete: KeyAction.cascade)();
  IntColumn get dayIndex => integer().named('day_index').nullable()();
  TextColumn get flightNo => text().named('flight_no').nullable()();
  TextColumn get carrier => text().nullable()();
  DateTimeColumn get departTime => dateTime().named('depart_time').nullable()();
  DateTimeColumn get arriveTime => dateTime().named('arrive_time').nullable()();
  TextColumn get fromAirport => text().named('from_airport').nullable()();
  TextColumn get toAirport => text().named('to_airport').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('SpotRow')
class Spots extends Table {
  TextColumn get id => text()();
  TextColumn get dayId => text()
      .named('day_id')
      .references(DayPlans, #id, onDelete: KeyAction.cascade)();
  IntColumn get orderIndex => integer().named('order_index')();
  TextColumn get name => text()();
  TextColumn get visitType =>
      text().named('visit_type').map(const VisitTypeConverter())();
  TextColumn get description => text().nullable()();
  TextColumn get refundNote => text().named('refund_note').nullable()();

  /// 景點圖片路徑（schema v2）：`assets/...`（內建範例）或 App 沙盒檔案路徑。
  TextColumn get imagePath => text().named('image_path').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('InfoSectionRow')
class InfoSections extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()
      .named('trip_id')
      .references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get category => text().map(const InfoCategoryConverter())();
  TextColumn get title => text()();
  TextColumn get body => text()();
  IntColumn get orderIndex => integer().named('order_index')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('ReminderRow')
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()
      .named('trip_id')
      .references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get refType =>
      text().named('ref_type').map(const ReminderRefTypeConverter())();
  TextColumn get refId => text().named('ref_id').nullable()();
  DateTimeColumn get fireAt => dateTime().named('fire_at')();
  TextColumn get title => text()();
  TextColumn get body => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant<bool>(true))();
  IntColumn get osNotificationId =>
      integer().named('os_notification_id').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('JournalEntryRow')
class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()
      .named('trip_id')
      .references(Trips, #id, onDelete: KeyAction.cascade)();
  IntColumn get dayIndex => integer().named('day_index').nullable()();
  TextColumn get entryType =>
      text().named('entry_type').map(const EntryTypeConverter())();
  // 'text' 是 Drift Table 的 builder 方法名，故 getter 改名 entryText，
  // 仍對應資料庫欄位 text（規格 §3.7）。
  TextColumn get entryText => text().named('text').nullable()();
  TextColumn get photoPaths => text()
      .named('photo_paths')
      .map(const StringListConverter())
      .withDefault(const Constant<String>('[]'))();
  RealColumn get amount => real().nullable()();
  TextColumn get currency => text().nullable()();
  RealColumn get amountTwd => real().named('amount_twd').nullable()();
  RealColumn get exchangeRateUsed =>
      real().named('exchange_rate_used').nullable()();
  TextColumn get expenseCategory => text()
      .named('expense_category')
      .map(const ExpenseCategoryConverter())
      .nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  TextColumn get locationLabel => text().named('location_label').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('ExchangeRateRow')
class ExchangeRates extends Table {
  /// PK = `base_currency + '_' + quote_currency`，例 `JPY_TWD`（單筆 upsert）。
  TextColumn get id => text()();
  TextColumn get baseCurrency => text().named('base_currency')();
  TextColumn get quoteCurrency => text().named('quote_currency')();
  RealColumn get rate => real()();
  TextColumn get source => text().map(const RateSourceConverter())();
  DateTimeColumn get fetchedAt => dateTime().named('fetched_at')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
