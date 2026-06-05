/// 路由路徑常數與建構輔助。對應規格 §5.1。
/// 集中於此避免散落硬編字串。
library;

class AppRoutes {
  AppRoutes._();

  static const String tripList = '/';
  static const String import = '/import';
  static const String importPreview = '/import/preview';
  static const String settings = '/settings';
  static const String exchangeRates = '/settings/exchange-rates';

  // 行程範圍（trip-scoped）
  static String tripHome(String id) => '/trip/$id';
  static String tripDays(String id) => '/trip/$id/days';
  static String dayDetail(String id, int dayIndex) => '/trip/$id/day/$dayIndex';
  static String spotDetail(String id, String spotId) =>
      '/trip/$id/spot/$spotId';
  static String info(String id) => '/trip/$id/info';
  static String reminders(String id) => '/trip/$id/reminders';
  static String journal(String id) => '/trip/$id/journal';
  static String journalExport(String id) => '/trip/$id/journal/export';
  static String search(String id) => '/trip/$id/search';

  // route name（go_router named route）
  static const String nTripList = 'tripList';
  static const String nImport = 'import';
  static const String nImportPreview = 'importPreview';
  static const String nSettings = 'settings';
  static const String nExchangeRates = 'exchangeRates';
  static const String nTripHome = 'tripHome';
  static const String nTripDays = 'tripDays';
  static const String nDayDetail = 'dayDetail';
  static const String nSpotDetail = 'spotDetail';
  static const String nInfo = 'info';
  static const String nReminders = 'reminders';
  static const String nJournal = 'journal';
  static const String nJournalExport = 'journalExport';
  static const String nSearch = 'search';
}

/// 行程底部導覽列的 5 個分頁（今日 / 全程 / 札記 / 須知 / 搜尋）。
enum TripTab { today, days, journal, info, search }
