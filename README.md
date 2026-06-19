# TripPilot

把一份**內建的訂製團體旅遊行程**做成可查詢、可提醒、可記錄（札記／相片／支出）、可換匯、可匯出的**離線優先**跨平台行程助手。**開啟 App 即進入行程首頁。**

- 平台：Android / iOS（亦可 macOS desktop）
- 範例行程：東北仙境傳說六日（團號 `NSC061306BR6`）

> 規格（以實際成品為準）：[`docs/TripPilot_實作規格書_v2.md`](docs/TripPilot_實作規格書_v2.md)
> Agent 上下文：[`CLAUDE.md`](CLAUDE.md) ・ [`AGENTS.md`](AGENTS.md)
> 變更紀錄：[`CHANGELOG.md`](CHANGELOG.md)

---

## 功能

- **行程首頁**：領隊一鍵撥號、機場專線；旅途中自動展開「今日」卡片；未出發顯示倒數＋集合資訊＋首班機。
- **行程表 / 單日詳情**：每日列表；單日含**航班卡片**、飯店（撥號＋地圖）、三餐、**時間軸景點**（含縮圖、退費條款）。
- **景點詳情**：景點大圖（可全螢幕縮放）＋完整介紹。
- **須知**：分類頁籤＋全文檢索（FTS5 trigram，中文可搜）。
- **搜尋**：全行程景點／每日／須知檢索。
- **提醒**：集合（前 2 小時）、護照效期（前 30 天）、每日晨報（07:00）、回程班機（前 3 小時）；可逐筆/全域開關；通知權限引導。
- **旅遊記錄**：札記（文字＋相片）、支出（多幣別加總＋台幣換算）、相片牆；可編輯/刪除、相片全螢幕檢視。
- **匯率**：線上拉取（open.er-api 為主）／手動輸入／快取過期提示；支出即時換算與批次重算。
- **匯出**：CSV（支出明細，UTF-8 BOM）／PDF 報告，透過系統分享。
- **設定**：深淺色、語系（繁中／English／系統），皆持久化。

## 技術棧

Flutter 3.44 / Dart 3.12 ・Riverpod（手寫 provider）・Drift（SQLite + FTS5）・go_router ・flutter_local_notifications + timezone ・intl（zh-Hant 為主）・pdf + printing + share_plus ・shared_preferences。

## 快速開始

> 需 Flutter 3.44+ / Dart 3.12+。Android 需 Android SDK + JDK 17；iOS 需 Xcode + CocoaPods。

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 產生 Drift *.g.dart
flutter gen-l10n                                            # 產生 AppLocalizations
flutter analyze
flutter test                                              # 42/42

# 執行
flutter run -d <android-device-id>     # Android 實機/模擬器
flutter run -d <ios-sim-udid>          # iOS 模擬器
```

第一次 clone 後務必跑 `build_runner` 與 `gen-l10n`（產生檔不入庫）。

## 專案結構

```
lib/
├── app/          路由（go_router）、主題
├── core/         常數、列舉、ID、安全儲存、時區、撥號/地圖
├── data/         Drift（tables/converters/database）、models、repositories
├── features/     bootstrap / trip_home / day_detail / info_hub / reminders /
│                 journal / journal_export / exchange_rate / search / settings / import(保留未用)
├── services/     pdf_text / claude_api / notification / exchange_rate / export / photo_store
└── l10n/         app_zh.arb / app_en.arb
assets/sample/    內建行程 JSON + 景點圖（spots/*.jpeg）
test/             單元/整合/widget 測試（42 項）
docs/             規格書 v1.1 / v2.0、範例 PDF
```

## 內建行程內容

行程內容＝`assets/sample/nsc061306br6.json`（景點 `image` 指向 `assets/sample/spots/`）。
修改內容後請 **`AppConstants.sampleContentVersion` +1**，App 啟動會自動重載新內容。

## 隱私與授權

- 所有資料留在裝置私有沙盒；無帳號、無雲端同步、無第三方分析。唯一需網路的環節為即時匯率拉取。
- 本 repo 含第三方（旅行社）行程 PDF 與其抽取之景點圖片，僅供個人開發測試參考。

## 授權

MIT License — 詳見 [LICENSE](LICENSE)。
