# TripPilot — Claude Code 專案上下文

> **一句話**：把一份**內建的訂製團體旅遊行程**做成可查詢、可提醒、可記錄（札記/相片/支出）、可換匯、可匯出的離線優先跨平台行程助手（Android + iOS，亦可 macOS desktop）。**開啟 App 即進入行程首頁**。

完整規格見 **`docs/TripPilot_實作規格書_v2.md`（v2.0，依實際成品，以此為準）**；初版 `docs/TripPilot_實作規格書.md`（v1.1）僅供對照。本檔為快速進入狀態的摘要。

---

## 與 v1.1 規格的關鍵差異

- **移除「匯入 PDF」功能**：行程改為內建 JSON（`assets/sample/nsc061306br6.json`），App 啟動時自動 seed。
- **開啟即進首頁**：路由 `/` 為 `BootstrapScreen`（seed 後 `context.go('/trip/:id')`）；無行程清單頁。
- **不使用 Claude API**：`claude_api_service` / `trip_json_mapper` 等程式保留為 dead code（未來恢復匯入可重用），無 UI 入口。
- **唯一需網路的環節 = 即時匯率拉取**（其餘全離線）。

## 技術棧（實際）

| 層級       | 選型                                                                     |
| ---------- | ------------------------------------------------------------------------ |
| 框架       | **Flutter 3.44.1 / Dart 3.12.1**（sound null safety）                    |
| 狀態管理   | Riverpod 2.x（**手寫 provider，不用 riverpod_generator**）               |
| 本地資料庫 | Drift（SQLite + FTS5 trigram），`drift ^2.31`                            |
| 路由       | go_router                                                                |
| 國際化     | flutter_localizations + intl（zh-Hant 為主、en 次之）                    |
| 通知       | flutter_local_notifications ^17 + timezone（Asia/Tokyo）                 |
| 相片/檔案  | image_picker, path_provider, path（file_picker 為相依但匯入移除後未用）  |
| 匯出       | pdf + printing + share_plus ^12                                          |
| 匯率       | http + ExchangeRateService（**open.er-api 為主**、frankfurter.dev 為輔） |
| 偏好持久化 | **shared_preferences**（主題/語系/內建內容版本）                         |
| PDF 抽取   | syncfusion_flutter_pdf ^33 + unorm_dart（NFKC）— 保留未用                |

## 硬性規則（Implementation Rules）

1. **離線為預設**：除「即時匯率拉取」外，任何功能不得依賴網路。
2. **型別優先**：資料層不可有漏網 `dynamic`；先定義 model / Drift table 再寫 UI。
3. **繁中 i18n**：UI 字串一律走 `AppLocalizations`，不可硬編中文於 widget（PDF 匯出內文標籤例外）。
4. **commit 格式**：`Module // SubModule: Description.`（例 `Journal // Expense: Group totals by currency.`）
5. **不硬編機密**：若恢復 Claude/付費 API，key 走 `flutter_secure_storage`，永不進 repo。

## App 流程（Bootstrap）

```
main（init tz/日期符號/SharedPreferences）→ '/' BootstrapScreen
  → 若 DB 無行程，或內建內容版本(AppConstants.sampleContentVersion)有變
       → 刪除舊行程 → loadSampleTrip()（讀 assets JSON → mapClaudeJson → Drift）
       → 建立預設提醒 → 記錄內容版本
     否則取既有行程
  → context.go('/trip/:id')
```

> 更新內建行程內容（改 `assets/sample/nsc061306br6.json`）後，**記得 +1 `AppConstants.sampleContentVersion`**，App 啟動才會自動重載（會清掉該行程的札記/支出）。

## 資料模型摘要（Drift schema v2，`lib/data/database/`）

- `Trip` ─1:N→ `DayPlan` ─1:N→ `Spot`；`Trip` ─1:N→ `Flight`/`InfoSection`/`Reminder`/`JournalEntry`。
- `Spot.image_path`（**v2 新增，schema v2**）：景點圖，`assets/...` 或沙盒檔案路徑。
- `JournalEntry`：欄位 getter `entryText`（DB 欄名 `text`，避開 `Table.text()`）；含 `expense_category`。
- `ExchangeRate`：PK `base_quote`（如 `JPY_TWD`），upsert 單筆。
- FTS5（trigram）：`spots_fts`、`days_fts`、`info_fts`；< 3 字查詢降級 LIKE。
- **Drift 未對 `.references()` 產生 SQL 外鍵** → 刪除行程以 `TripRepository.deleteTrip` 逐表交易刪除，勿倚賴 DB cascade。

## 內建行程內容（含景點圖）

- `assets/sample/nsc061306br6.json`：6 天、2 航班、15+ 景點（完整介紹）、8 段須知（注意事項/小費/行前必讀/航班行李/住宿/安全/退稅/出入境）。
- `assets/sample/spots/*.jpeg`：12 張景點圖，**建置前**以 PyMuPDF 從 PDF 依版面順序抽出對應；JSON `spots[].image` 引用。
- PDF 文字層有康熙部首相容碼點（⼗ U+2F17 等）→ 抽取以 NFKC 還原；領隊名為「康晋文」(晋 U+664B，變體字 NFKC 不統一，屬正常)。

## 回歸 fixture

- `docs/NSC061306BR6.pdf`（單一檔；PDF 測試直接讀此路徑）。
- 驗收點：6 天、團號 NSC061306BR6、BR122 0955→1420、十和田莊 0176-75-2221、平泉中尊寺退費、須知可搜「鋰電池/退稅」、景點圖正確對應。

## 測試注意（testWidgets）

- **不可用真實 drift**（fake-async 卡死 10 分鐘）→ 用 `provider.overrideWith` 餵固定資料。
- 載入中 `CircularProgressIndicator` 會讓 `pumpAndSettle` 永不 settle → 改用固定次數 `pump`。
- `analysis_options.yaml` 已移除 `require_trailing_commas`（與 Dart 3.12 tall formatter 衝突，逗號交給 `dart format`）。

---

## 里程碑（全部完成）

- [x] M0 骨架 ・[x] M1 資料層 ・[x] M2 PDF 抽取(NFKC) ・[x] M3 映射/合理性檢查(保留功能)
- [x] M4 行程瀏覽 ・[x] M5 須知與搜尋 ・[x] M6 提醒 ・[x] M7a 旅遊記錄
- [x] M7b 匯率換算 ・[x] M7c 匯出 ・[x] M8 打磨
- 規格調整：移除匯入、內建行程、開啟即首頁、景點圖片、須知/景點完整內文還原、深淺色+語系持久化、通知權限引導。

待補（選做）：PDF 內嵌 Noto Sans TC（否則匯出降級 CSV）、無障礙稽核、恢復「貼上 JSON」匯入 UI。

## 開發指令

Flutter 在 `~/development/flutter`（未進全域 PATH）；Android SDK 在 `~/Library/Android/sdk`、JDK17 在 `/opt/homebrew/opt/openjdk@17`。每個 shell 先：

```bash
export PATH="$HOME/development/flutter/bin:/opt/homebrew/bin:$PATH"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
```

然後：

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift *.g.dart
flutter gen-l10n                                            # AppLocalizations
flutter analyze                                            # 已驗證：No issues found
flutter test                                              # 已驗證：42/42 全綠
# 執行：
flutter run -d <android-id>            # 實機 T951K(Android 15) 已驗證
flutter run -d <ios-sim-udid>          # iPhone 13 Pro Max 模擬器(iOS 26.5) 已驗證
```

### iOS 實機部署（要點圖示就能獨立開）

模擬器外，裝到實機（Mandy iPhone = iPhone 13 Pro Max，device id `00008110-001A38C636F9801E`）有幾個非顯而易見的關卡，**務必裝 release**：

```bash
flutter build ios --release
xcrun devicectl device install app --device 00008110-001A38C636F9801E \
  build/ios/Release-iphoneos/Runner.app   # 注意是 Release-iphoneos，非 iphoneos
```

- **debug build 不能脫離電腦獨立啟動**（iOS 14+：`Cannot create a FlutterEngine instance in debug mode` → signal 11）；要點圖示就開必須 release。`flutter run`（debug）只在需要日誌/偵錯時用。
- **`flutter install` 不會編譯**，只裝現有產物；先前 build 過 debug 時 `flutter install --release` 仍會裝到 debug 版。先 `flutter build ios --release` 才對。
- `flutter build ios --release` 會報 `expected app at build/ios/iphoneos/Runner.app not found`——release 產物實際在 `build/ios/Release-iphoneos/`，故改用 `devicectl` 直接裝。
- 簽署：Xcode 個人團隊（`DEVELOPMENT_TEAM = 3B86TACCQ7`，已入庫 pbxproj，Automatically manage signing）。**約 7 天到期**，失效重跑上面兩行。
- 首次安裝/重裝後要在 iPhone **設定→一般→VPN與裝置管理** 信任開發者；**刪除 App 會重置信任**，盡量覆蓋安裝。
- iPhone **開發者模式須保持開啟**，關掉則開發版 App 無法啟動。

### 相依/建置坑（Dart 3.12 環境）

- 移除 riverpod_generator/riverpod_lint/custom_lint（會把 analyzer 釘 6.x，導致 drift_dev 崩潰）。
- `drift/drift_dev ^2.31`、`syncfusion_flutter_pdf ^33`、`share_plus ^12`、`intl: any`。
- `app_database.dart`（含 part `*.g.dart`）需 import `core/enums.dart` 與 `converters.dart`。
- **Android `compileSdk = 36`**（外掛 flutter_plugin_android_lifecycle 要求）：app/build.gradle.kts 設 36，且 `android/build.gradle.kts` 以 `subprojects{ afterEvaluate{ 強制 compileSdkVersion(36) } }`（用 `state.executed` 守衛）；並開 core library desugaring（flutter_local_notifications）。
- native runner（android/ios/macos）已生成並套用 `platform_config/` 權限。

> 詳細工具鏈/坑記錄見專案 memory（flutter-toolchain、flutter-test-gotchas、no-api-key-strategy、ios-device-install）。
