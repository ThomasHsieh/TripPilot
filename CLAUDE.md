# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **一句話**：把一份**內建的訂製團體旅遊行程**做成可查詢、可提醒、可記錄（札記/相片/支出）、可換匯、可匯出的離線優先跨平台行程助手（Android + iOS，亦可 macOS desktop）。**開啟 App 即進入行程首頁**。

完整規格見 **`docs/TripPilot_實作規格書_v2.md`（v2.0，依實際成品，以此為準）**；初版 `docs/TripPilot_實作規格書.md`（v1.1）僅供對照。

---

## 開發指令

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift *.g.dart
flutter gen-l10n                                            # AppLocalizations
flutter analyze
flutter test                                                # 全部測試
flutter test test/services/exchange_rate_service_test.dart   # 單一測試檔
flutter run -d <device-id>                                  # 執行於指定裝置
```

`*.g.dart` 與 `l10n/generated/` 不入庫（見 `.gitignore`）；clone 後務必先跑 `build_runner` 與 `gen-l10n`。

### iOS 實機部署

debug build 不能脫離電腦獨立啟動（iOS 14+ signal 11），**要點圖示就開必須 release**：

```bash
flutter build ios --release
xcrun devicectl device install app --device <device-id> \
  build/ios/Release-iphoneos/Runner.app   # 產物在 Release-iphoneos/，非 iphoneos/
```

- `flutter install` 不會編譯，只裝現有產物；先 `flutter build ios --release` 才對。
- 簽署：Xcode 個人團隊（Automatically manage signing），約 7 天到期，失效重跑上面兩行。
- 首次安裝後在 iPhone **設定→一般→VPN與裝置管理** 信任開發者；刪除 App 會重置信任。

---

## 技術棧

| 層級       | 選型                                                                     |
| ---------- | ------------------------------------------------------------------------ |
| 框架       | **Flutter 3.44.1 / Dart 3.12.1**（sound null safety）                    |
| 狀態管理   | Riverpod 2.x（**手寫 provider，不用 riverpod_generator**）               |
| 本地資料庫 | Drift（SQLite + FTS5 trigram），`drift ^2.31`                            |
| 路由       | go_router                                                                |
| 國際化     | flutter_localizations + intl（zh-Hant 為主、en 次之）                    |
| 通知       | flutter_local_notifications ^17 + timezone（Asia/Tokyo）                 |
| 相片/檔案  | image_picker, path_provider, path                                        |
| 匯出       | pdf + printing + share_plus ^12                                          |
| 匯率       | http + ExchangeRateService（**open.er-api 為主**、frankfurter.dev 為輔） |
| 偏好持久化 | **shared_preferences**（主題/語系/內建內容版本）                         |
| PDF 抽取   | syncfusion_flutter_pdf ^33 + unorm_dart（NFKC）— 保留未用                |

## 硬性規則

1. **離線為預設**：除「即時匯率拉取」外，任何功能不得依賴網路。
2. **型別優先**：資料層不可有漏網 `dynamic`；先定義 model / Drift table 再寫 UI。
3. **繁中 i18n**：UI 字串一律走 `AppLocalizations`，不可硬編中文於 widget（PDF 匯出內文標籤例外）。
4. **commit 格式**：`Module // SubModule: Description.`（例 `Journal // Expense: Group totals by currency.`）
5. **不硬編機密**：若恢復 Claude/付費 API，key 走 `flutter_secure_storage`，永不進 repo。

---

## 架構

### App 流程（Bootstrap）

```
main（init tz/日期符號/SharedPreferences）→ '/' BootstrapScreen
  → 若 DB 無行程，或內建內容版本(AppConstants.sampleContentVersion)有變
       → 刪除舊行程 → loadSampleTrip()（讀 assets JSON → mapClaudeJson → Drift）
       → 建立預設提醒 → 記錄內容版本
     否則取既有行程
  → context.go('/trip/:id')
```

- 行程為內建 JSON（`assets/sample/nsc061306br6.json`），App 啟動時自動 seed；無行程清單頁。
- `claude_api_service` / `trip_json_mapper` 等程式保留為 dead code（未來恢復匯入可重用），無 UI 入口。

> 更新內建行程內容後，**記得 +1 `AppConstants.sampleContentVersion`**（`lib/core/constants.dart`），App 啟動才會自動重載（會清掉該行程的札記/支出）。

### 資料模型（Drift schema v2，`lib/data/database/`）

- `Trip` ─1:N→ `DayPlan` ─1:N→ `Spot`；`Trip` ─1:N→ `Flight`/`InfoSection`/`Reminder`/`JournalEntry`。
- `Spot.image_path`（schema v2）：景點圖，`assets/...` 或沙盒檔案路徑。
- `JournalEntry`：欄位 getter `entryText`（DB 欄名 `text`，避開 `Table.text()`）；含 `expense_category`。
- `ExchangeRate`：PK `base_quote`（如 `JPY_TWD`），upsert 單筆。
- FTS5（trigram）：`spots_fts`、`days_fts`、`info_fts`；< 3 字查詢降級 LIKE。
- **Drift 未對 `.references()` 產生 SQL 外鍵** → 刪除行程以 `TripRepository.deleteTrip` 逐表交易刪除，勿倚賴 DB cascade。

### 內建行程內容

- `assets/sample/nsc061306br6.json`：6 天、2 航班、15+ 景點（完整介紹）、8 段須知。
- `assets/sample/spots/*.jpeg`：12 張景點圖，JSON `spots[].image` 引用。
- PDF 文字層有康熙部首相容碼點（⼗ U+2F17 等）→ 抽取以 NFKC 還原。

---

## 測試注意

- **不可用真實 drift**（fake-async 卡死 10 分鐘）→ 用 `provider.overrideWith` 餵固定資料。
- 載入中 `CircularProgressIndicator` 會讓 `pumpAndSettle` 永不 settle → 改用固定次數 `pump`。
- `analysis_options.yaml` 已移除 `require_trailing_commas`（與 Dart 3.12 tall formatter 衝突，逗號交給 `dart format`）。
- 回歸 fixture：`docs/NSC061306BR6.pdf`（驗收點：6 天、團號 NSC061306BR6、BR122 0955→1420、十和田莊 0176-75-2221、平泉中尊寺退費、須知可搜「鋰電池/退稅」）。

## 相依/建置坑（Dart 3.12 環境）

- 移除 riverpod_generator/riverpod_lint/custom_lint（會把 analyzer 釘 6.x，導致 drift_dev 崩潰）。
- `app_database.dart`（含 part `*.g.dart`）需 import `core/enums.dart` 與 `converters.dart`。
- **Android `compileSdk = 36`**（外掛 flutter_plugin_android_lifecycle 要求）：app/build.gradle.kts 設 36，且 `android/build.gradle.kts` 以 `subprojects{ afterEvaluate{ 強制 compileSdkVersion(36) } }`（用 `state.executed` 守衛）；並開 core library desugaring（flutter_local_notifications）。

## 待補（選做）

- PDF 內嵌 Noto Sans TC（否則匯出降級 CSV）
- 無障礙稽核
- 恢復「貼上 JSON」匯入 UI
