/// App 全域常數。離線優先；網路相關只在 Claude API 與匯率拉取使用。
library;

class AppConstants {
  AppConstants._();

  /// 內建行程內容版本。每次更新 assets/sample 的行程內容就 +1，
  /// App 啟動時若偵測到版本不同會自動重載內建行程（bootstrap）。
  static const int sampleContentVersion = 2;

  /// 預設 Claude 模型（可由使用者於設定改）。見規格 §4.2。
  static const String defaultClaudeModel = 'claude-opus-4-8';

  /// 可選模型清單（設定頁下拉）。
  static const List<String> claudeModels = <String>[
    'claude-opus-4-8',
    'claude-sonnet-4-6',
    'claude-haiku-4-5-20251001',
  ];

  /// Claude Messages API 端點與版本。
  static const String claudeApiBase = 'https://api.anthropic.com/v1/messages';
  static const String claudeApiVersion = '2023-06-01';
  static const int claudeMaxTokens = 8192;

  /// 匯率 API（免費、免 key）。open.er-api 涵蓋 TWD 為主；Frankfurter（ECB）為輔，不含 TWD。
  static const String frankfurterBase = 'https://api.frankfurter.dev/v1/latest';
  static const String erApiBase = 'https://open.er-api.com/v6/latest';

  /// 匯率快取過期門檻（小時）。超過且 source=api 顯示橘色警示。
  static const int rateStaleHours = 6;

  /// 目的地時區（本範例行程為日本）。提醒以此時區排程。
  static const String destinationTimeZone = 'Asia/Tokyo';

  /// 結算/換算的目標幣別。
  static const String quoteCurrency = 'TWD';

  /// 常用幣別（下拉置頂）。
  static const List<String> commonCurrencies = <String>[
    'JPY',
    'TWD',
    'USD',
    'EUR',
  ];

  /// 預設提醒：集合前提前量（小時）。注意事項建議起飛前 2.5 小時集合。
  static const int meetupReminderHoursBefore = 2;

  /// 護照效期提醒：出發前天數。
  static const int passportReminderDaysBefore = 30;

  /// 回程班機提醒：起飛前小時。
  static const int returnFlightReminderHoursBefore = 3;

  /// 每日晨報時間（當地）。
  static const int dailyBriefingHour = 7;

  /// 匯出相片縮圖最大寬度（px）。
  static const double exportPhotoMaxWidth = 400;
}
