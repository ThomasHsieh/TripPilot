# Changelog

本專案的版本與變更紀錄。日期格式 YYYY.MM.DD。

## [2026.06.19] — 公開化維護

- 專案改為公開（MIT License）。
- 移除領隊真實個資，替換為假資料。
- 移除旅行社行程 PDF（`.gitignore`）。
- CLAUDE.md 整理精簡。

## [2026.06.05] — 初始發行（init release）

首個可用版本：一份內建的訂製團體旅遊行程（東北六日 `NSC061306BR6`），開啟 App 即進入行程首頁，離線可用。

### 功能（Features）

- **啟動即用**：Bootstrap 於首次啟動自動載入內建行程並建立預設提醒，直接進入行程首頁；內建內容版本機制可在內容更新時自動重載。
- **行程瀏覽**：行程首頁（領隊一鍵撥號、機場專線、今日卡片／出發倒數＋首班機）、行程表（每日列表）、單日詳情（**航班卡片**、飯店撥號/地圖、三餐、時間軸景點含縮圖與退費條款）、景點詳情（**大圖可全螢幕**＋完整介紹）。
- **須知與搜尋**：須知分類頁籤＋全文檢索；全行程 FTS5（trigram）搜尋，中文 < 3 字自動降級 LIKE。
- **提醒**：集合前 2 小時、護照前 30 天、每日晨報 07:00、回程前 3 小時；逐筆/全域開關、通知權限引導橫幅。
- **旅遊記錄**：札記（文字＋相片）、支出（多幣別加總＋台幣換算）、相片牆；可編輯/刪除、相片全螢幕檢視。
- **匯率換算**：線上拉取（open.er-api 為主、frankfurter.dev 為輔）／手動輸入／快取過期提示；支出即時換算、設定後批次重算。
- **匯出**：CSV（支出明細，UTF-8 BOM）與 PDF 報告，透過 `share_plus` 系統分享，保留歷史匯出。
- **設定**：深淺色、語系（繁中／English／系統），以 SharedPreferences 持久化。
- **景點圖片**：自 PDF 抽取 12 張景點實圖，依版面順序對應景點並內建為 assets。

### 與初版規劃（v1.1）的差異

- **移除「匯入 PDF」功能**，改為內建訂製行程、開啟即進首頁（不再有行程清單／匯入頁）。
- **不使用 Anthropic Claude API**（相關程式保留為未啟用的 dead code，未來可恢復「匯入／貼上 JSON」）。
- 匯率主來源改為 **open.er-api**（v1.1 指定的 `api.frankfurter.app` 已停用且 ECB 不含台幣）。
- 設定移除 API key／模型，改為外觀／語系／匯率；狀態管理改為手寫 Riverpod provider（移除 codegen）。
- PDF 文字抽取加入 **NFKC 正規化**（修正康熙部首相容碼點）。

### 資料模型

- Drift schema v2：新增 `Spot.image_path`；`JournalEntry` 補 `expense_category`。
- FTS5 trigram 全文索引（spots/days/info）。
- 刪除行程以 repository 端逐表交易完成（Drift 未產生 SQL 外鍵）。

### 品質

- `flutter analyze`：No issues found。
- `flutter test`：42 項全綠（資料層、PDF/NFKC、映射、提醒時間、搜尋、札記、匯率、匯出、設定、bootstrap widget）。
- 實機驗證：Android（T951K / Android 15）、iOS 模擬器（iPhone 13 Pro Max / iOS 26.5）、macOS desktop 可建置。

### 已知限制 / 待補

- PDF 匯出需內嵌 Noto Sans TC 字型方能顯示中文，否則自動降級僅出 CSV。
- 無障礙稽核（Semantics／對比／字級）尚未完整。
- 目前為單一內建行程；「匯入／貼上 JSON」UI 未開放。
