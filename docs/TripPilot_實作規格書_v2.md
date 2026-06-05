# 團體旅遊行程 App 實作規格書（v2・依實際成品）

> 專案代號：**TripPilot**
> 目標：將一份訂製的團體旅遊行程內建於 App，提供查詢、瀏覽、提醒、旅遊中記錄（札記／相片／支出）、匯率換算與匯出的跨平台 App（Android + iOS，亦可跑 macOS desktop）。
> 文件版本：**v2.0**｜撰寫日期：2026/06/05
> 本文件依**實際完成的成品**撰寫，反映自 v1.1 規格起的所有調整。標註「**v1→v2 變更**」者為與初版規格不同之處。

---

## 0. 版本差異總覽（v1.1 → v2.0）

| 主題       | v1.1 規格                             | v2.0 實際成品                                                               |
| ---------- | ------------------------------------- | --------------------------------------------------------------------------- |
| 行程來源   | 使用者匯入 PDF → AI 結構化解析        | **移除匯入 PDF 功能**；App 內建一份訂製行程（NSC061306BR6），開啟即用       |
| 落地頁     | 行程清單（TripList）                  | **開啟直接進入行程首頁**（bootstrap 自動 seed 內建行程）                    |
| AI 解析    | Claude API 線上解析（唯一需網路環節） | 不使用（程式碼保留為 dead code）。行程內容以內建 JSON 提供                  |
| 景點圖片   | 無                                    | 由 PDF 抽取 12 張景點實圖內建，於單日時間軸縮圖、景點詳情大圖、可全螢幕檢視 |
| 中文正規化 | 未提及                                | PDF 抽取套用 **NFKC 正規化**（修正康熙部首相容碼點）                        |
| 匯率主來源 | Frankfurter 為主、er-api 降級         | **open.er-api 為主**（含 TWD）、frankfurter.dev 為輔（ECB 不含 TWD）        |
| 設定       | API key／模型／語系                   | **外觀（深淺色）／語系／匯率管理**，且持久化；移除 API key                  |
| 狀態管理   | Riverpod + riverpod_generator         | Riverpod **手寫 provider**（移除 codegen，避免 analyzer 版本衝突）          |

---

## 1. 產品概述

### 1.1 解決的問題

團體旅遊（如可樂旅遊）的行程表 PDF 資訊密集、版型半結構化，旅客在旅途中查資料不便。本 App 把一份訂製行程轉為結構化、可查詢、可提醒、可記錄的行程助手，**開啟即用**、離線可用。

### 1.2 核心使用流程

```
開啟 App → （首次自動載入內建行程）→ 行程首頁
                                          ↓
        今日卡片 / 行程表（每日）/ 單日詳情（時間軸＋航班＋飯店）/ 景點詳情（圖＋介紹）
                                          ↓
        旅遊中：札記 / 相片 / 支出（多幣別加總＋台幣換算）/ 須知全文檢索 / 提醒 / 匯出
```

### 1.3 設計原則

- **單一行程焦點**：App 預設直接打開行程首頁；旅途期間自動展開「今日」。
- **零學習成本**：卡片式呈現；重要欄位（集合時間、飯店電話、領隊電話）一鍵可達（撥號／地圖）。
- **離線為預設**：除「即時匯率拉取」外，所有功能不依賴網路。
- **資料主權**：所有資料留在裝置私有沙盒；無帳號、無雲端同步、無第三方分析。

---

## 2. 技術選型（實際）

| 層級         | 選型                                                  | 版本/備註                                                   |
| ------------ | ----------------------------------------------------- | ----------------------------------------------------------- |
| 框架         | Flutter / Dart                                        | **Flutter 3.44.1 / Dart 3.12.1**（sound null safety）       |
| 狀態管理     | Riverpod 2.x                                          | **手寫 provider，不使用 riverpod_generator**                |
| 本地資料庫   | Drift（SQLite，含 FTS5）                              | `drift ^2.31`、`drift_flutter ^0.2`、`sqlite3_flutter_libs` |
| PDF 文字抽取 | syncfusion_flutter_pdf `^33` + **unorm_dart**（NFKC） | 仍保留（dead code，匯入已移除）                             |
| 通知         | flutter_local_notifications `^17` + timezone          | 目的地時區（Asia/Tokyo）                                    |
| 路由         | go_router `^14`                                       | 宣告式                                                      |
| 國際化       | flutter_localizations + intl                          | zh-Hant 為主、en 次之                                       |
| 相片/檔案    | image_picker、path_provider、path                     | file_picker 仍為相依（匯入移除後未使用）                    |
| 匯出         | pdf、printing、share_plus `^12`                       | CSV 完整；PDF 需中文字型（見 §8）                           |
| 匯率         | http + 自訂 ExchangeRateService                       | open.er-api 為主、frankfurter.dev 為輔                      |
| 偏好持久化   | **shared_preferences `^2.3`**                         | 主題／語系／內建內容版本                                    |
| 安全儲存     | flutter_secure_storage                                | 保留（API key 已不使用；PDF 上傳同意旗標保留）              |
| 工具         | uuid、collection                                      |                                                             |

### 2.1 行程資料來源決策（v1→v2 變更）

- v1 採「裝置端抽純文字 → 上傳文字給 Claude API → 回傳 JSON」混合架構。
- **v2 移除匯入**：行程改為**內建 JSON**（`assets/sample/nsc061306br6.json`），由 App 啟動時 seed 進 Drift。
- 原 PDF 抽取（`pdf_text_service`，含 NFKC）與 Claude 解析（`claude_api_service`、`trip_json_mapper`）程式**保留於 repo**，未來若要恢復「匯入／貼上 JSON」可重用，但目前無 UI 入口。
- 景點圖片於**建置前**以 PyMuPDF 從 PDF 抽出、依版面順序對應景點，內建為 assets（非 App 執行期抽圖）。

---

## 3. 資料模型（Drift Schema v2）

> 主鍵皆為 TEXT(uuid)；列舉欄位以 `wireName` 字串存放，經 TypeConverter 還原為 Dart enum。
> **註：Drift 未對 `.references()` 產生 SQL 外鍵約束**（已知行為），故刪除以 repository 端逐表交易刪除（見 §8）。

### 3.1 Trip（行程主檔）

| 欄位                                          | 型別     | 說明                             |
| --------------------------------------------- | -------- | -------------------------------- |
| id                                            | TEXT PK  |                                  |
| tour_code                                     | TEXT     | 團號，例 `NSC061306BR6`          |
| title                                         | TEXT     | 行程名稱                         |
| start_date / end_date                         | DATETIME | 出發/回程日                      |
| leader_name                                   | TEXT     | 領隊/導遊                        |
| leader_phone_domestic / leader_phone_overseas | TEXT     | 國內/國外電話                    |
| airport_service_line                          | TEXT     | 機場服務專線                     |
| meetup_time                                   | DATETIME | 集合時間                         |
| meetup_location                               | TEXT     | 集合地點                         |
| luggage_tag                                   | TEXT     | 行李牌                           |
| source_pdf_path                               | TEXT     | 原始 PDF 路徑（內建行程為 null） |
| raw_json                                      | TEXT     | 載入時的原始 JSON（除錯/重建）   |
| created_at                                    | DATETIME | 預設現在                         |

### 3.2 DayPlan（每日安排）

id PK、trip_id、day_index(INT)、date、route_summary、hotel_name、hotel_name_en、hotel_phone、meal_breakfast、meal_lunch、meal_dinner、notes。

### 3.3 Flight（航班）

id PK、trip_id、day_index、flight_no、carrier、depart_time、arrive_time、from_airport、to_airport。

### 3.4 Spot（景點，DayPlan 之下）

| 欄位           | 型別               | 說明                                                           |
| -------------- | ------------------ | -------------------------------------------------------------- |
| id             | TEXT PK            |                                                                |
| day_id         | TEXT FK→DayPlan.id |                                                                |
| order_index    | INT                | 當日排序                                                       |
| name           | TEXT               |                                                                |
| visit_type     | TEXT enum          | `enter`/`photo`/`drive_by`                                     |
| description    | TEXT               | 景點介紹（完整原文）                                           |
| refund_note    | TEXT               | 退費條款                                                       |
| **image_path** | TEXT               | **（v2 新增，schema v2）** 景點圖：`assets/...` 或沙盒檔案路徑 |

### 3.5 InfoSection（須知，全文知識庫）

id PK、trip_id、category(enum: `notice`/`tipping`/`baggage`/`hotel`/`safety`/`customs`/`health`/`guide`)、title、body、order_index。

### 3.6 Reminder（提醒）

id PK、trip_id、ref_type(enum: `meetup`/`flight`/`day_start`/`custom`)、ref_id、fire_at、title、body、enabled(BOOL)、os_notification_id(INT)。

### 3.7 JournalEntry（旅遊中記錄）

| 欄位                                     | 型別               | 說明                                                  |
| ---------------------------------------- | ------------------ | ----------------------------------------------------- |
| id                                       | TEXT PK            |                                                       |
| trip_id                                  | TEXT FK            |                                                       |
| day_index                                | INT nullable       | 綁定到某天                                            |
| entry_type                               | TEXT enum          | `note`/`photo`/`expense`                              |
| text                                     | TEXT               | 文字（Drift getter 名為 `entryText`，DB 欄名 `text`） |
| photo_paths                              | TEXT(json array)   | 相片本地路徑陣列                                      |
| amount / amount_twd / exchange_rate_used | REAL nullable      | 原幣金額 / 換算台幣 / 使用匯率                        |
| currency                                 | TEXT nullable      | 幣別                                                  |
| **expense_category**                     | TEXT enum nullable | **（補規格遺漏）** 餐飲/交通/購物/門票/住宿/其他      |
| created_at                               | DATETIME           |                                                       |
| location_label                           | TEXT nullable      |                                                       |

### 3.8 ExchangeRate（匯率快取）

id PK（`base_quote`，例 `JPY_TWD`）、base_currency、quote_currency、rate、source(enum: `api`/`manual`)、fetched_at。同一對 upsert 單筆。

### 3.9 FTS5 全文索引（trigram tokenizer）

- `spots_fts`(name, description)、`days_fts`(route_summary, hotel_name)、`info_fts`(title, body)。
- 以同步觸發器維護；中文 < 3 字查詢由 repository 降級為 LIKE。

---

## 4. 內建行程載入（Bootstrap）　＊取代 v1 §4「AI 結構化解析」

### 4.1 流程

```
App 啟動（main）→ 初始化 timezone / 日期符號 / SharedPreferences
   → BootstrapScreen（路由 '/'）
       1. 讀取 DB 既有行程與「內建內容版本」（SharedPreferences）
       2. 若 DB 無行程，或內容版本 != AppConstants.sampleContentVersion：
            刪除既有行程 → loadSampleTrip()（讀 assets JSON → mapClaudeJson → 寫入 Drift）
            → 建立預設提醒（§6.2）→ 記錄內容版本
          否則：取既有行程
       3. context.go('/trip/:id')（行程首頁）
```

### 4.2 內建行程 JSON 契約（§4.3 同 v1 schema，另加 `spots[].image`）

`assets/sample/nsc061306br6.json`，欄位對應 §3 各 table；`spots[].image` 指向 `assets/sample/spots/<slug>.jpeg`。

### 4.3 內容版本機制

- `AppConstants.sampleContentVersion`（整數）。更新內建行程內容時 +1。
- 啟動時若 SharedPreferences 記錄的版本不同，自動「清除舊行程 → 重載新內容」（會清除該行程已存在的札記/支出，demo 階段可接受）。

### 4.4 保留之匯入程式（未啟用）

`claude_api_service.dart`（含 system prompt、```json 圍欄容錯、JSON 映射）、`trip_json_mapper.dart`（含 §4.4 合理性檢查：天數連續、航班落在區間、集合早於首班機）、`importTripFromJsonString()`（「貼上 JSON」入口的核心）皆保留，無 UI 入口。

---

## 5. 畫面與導覽（UI Spec，實際）

### 5.1 路由表（go_router）

| 路徑                       | 畫面                | 說明                         |
| -------------------------- | ------------------- | ---------------------------- |
| `/`                        | **BootstrapScreen** | 自動 seed 內建行程後導向首頁 |
| `/settings`                | SettingsScreen      | 外觀／語系／匯率入口         |
| `/settings/exchange-rates` | ExchangeRateScreen  | 匯率查詢與手動管理           |
| `/trip/:id`                | TripHomeScreen      | 行程首頁（落地頁）           |
| `/trip/:id/days`           | AllDaysScreen       | 行程表（每日列表）           |
| `/trip/:id/day/:dayIndex`  | DayDetailScreen     | 單日詳情                     |
| `/trip/:id/spot/:spotId`   | SpotDetailScreen    | 景點詳情                     |
| `/trip/:id/info`           | InfoHubScreen       | 須知（分類頁籤＋檢索）       |
| `/trip/:id/reminders`      | RemindersScreen     | 提醒管理                     |
| `/trip/:id/journal`        | JournalScreen       | 札記/支出/相片               |
| `/trip/:id/journal/export` | JournalExportScreen | 匯出                         |
| `/trip/:id/search`         | SearchScreen        | 全行程全文檢索               |

> **v1→v2 變更**：移除 `/`(TripList)、`/import`、`/import/preview`；`/` 改為 Bootstrap。
> **導覽行為**：底部分頁（今日／**行程表**／札記／須知／搜尋）以 `context.go` 切換；詳情類（單日、景點、提醒、匯出）以 `context.push`，返回鍵正確回上一頁。

### 5.2 TripHomeScreen（核心）

- 頂部固定卡片：領隊姓名 + 一鍵撥號（國內/國外）+ 機場服務專線（ActionChip）。
- AppBar 動作：**提醒**（鈴鐺）、**設定**（齒輪）。
- 旅途期間（今日落在 start~end）：自動展開「今日」卡片（route_summary、飯店撥號+地圖、三餐、特別提醒、進單日詳情）。
- 行程未開始/已結束：倒數 + 集合資訊卡（集合時間/地點/行李牌/首班機）。
- 底部導覽列：今日 / 行程表 / 札記 / 須知 / 搜尋。

### 5.3 DayDetailScreen（單日詳情）

- **航班卡片**（該天的 Flight）：航班編號、航空公司、出發/抵達機場與時間。
- 飯店區塊：名稱、電話（撥號）、地圖（系統地圖以飯店名+英文名查詢）。
- 餐食三欄。
- **時間軸 Spot 列表**：visit_type 圖示（入內 📍/拍照 📷/經過 🚌）、**景點縮圖**、退費條款醒目標籤；點擊進景點詳情。

### 5.4 SpotDetailScreen（景點詳情）

- **景點大圖**（可點擊全螢幕縮放檢視）、名稱、visit_type、完整介紹、退費條款、一鍵地圖。

### 5.5 InfoHubScreen（須知）　＊v1→v2 變更

- 依 category 分頁籤；頂部搜尋框即時篩選（title/body 子字串）。
- 內文採**非摺疊、完整可捲動卡片**（標題＋全文 SelectableText），不再重複顯示分類。

### 5.6 SearchScreen（全行程檢索）

- 對 Spot.name/description、DayPlan、InfoSection.body 做 FTS5（trigram），< 3 字降級 LIKE。
- 結果分類顯示：景點 / 每日 / 須知；點擊導向對應詳情。

### 5.7 JournalScreen（札記/支出/相片）

- 三分頁：札記（文字+相片）、支出、相片牆。
- 每筆記錄可**編輯/刪除**（⋮ 選單；支出點擊亦可編輯）。
- 相片可點縮圖**全螢幕檢視**（縮放、左右滑）。
- 新增 dialog：札記（文字+多張相片，相片複製進沙盒）、支出（金額/幣別/類別/備註/日期，輸入即時顯示台幣換算預覽）。
- 記錄預設綁定到「今日」（依行程區間計算）。
- 右上「匯出」進 JournalExportScreen。

### 5.8 支出頁加總與匯率（§5.8）

- 底部固定加總列：依幣別分組原始加總（如 `JPY 18,500`、`TWD 420`）。
- 若有匯率：顯示「≈ 台幣合計 X」（未全部換算時加 `*` 標示）。
- **「更新匯率」連結左對齊置於加總列下方**，右側保留空間避開右下「新增支出」FAB（兩者不重疊）。

### 5.9 JournalExportScreen（匯出）

- 範圍（Radio）：全部 / 僅支出 / 僅札記與相片 / 依日期範圍。
- 格式（Checkbox）：PDF 報告、CSV（支出明細，UTF-8 BOM）。
- 流程：產生檔案 → `share_plus` 系統分享 → App Documents 留副本 → 「歷史匯出」清單可再分享。
- **CSV 完整可用**；**PDF 需內嵌中文字型**才不亂碼，否則自動降級僅出 CSV（§8）。

### 5.10 SettingsScreen　＊v1→v2 變更

- **外觀**：跟隨系統 / 淺色 / 深色（SegmentedButton，即時套用且持久化）。
- **語系**：跟隨系統 / 繁體中文 / English（即時切換且持久化）。
- **一般**：匯率管理入口。

---

## 6. 提醒系統

### 6.1 技術

flutter_local_notifications + timezone；提醒以目的地時區（Asia/Tokyo）排程。Android 13+ 需 POST_NOTIFICATIONS 與精確鬧鐘權限；iOS 執行期請求通知權限。非行動平台靜默降級。

### 6.2 載入後自動建立的預設提醒（純函式計算時間，可測）

| 提醒                  | 觸發時間                              |
| --------------------- | ------------------------------------- |
| 集合提醒（meetup）    | 集合時間前 2 小時（例 07:25 → 05:25） |
| 護照效期（custom）    | 出發前 30 天 09:00                    |
| 每日晨報（day_start） | 每天當地 07:00                        |
| 回程班機（flight）    | 回程起飛前 3 小時                     |

### 6.3 管理頁（RemindersScreen）

- 逐筆開關、全域「啟用所有提醒」。
- **通知權限被拒引導橫幅**（§8）：紅色橫幅 +「啟用通知」按鈕重新請求。

---

## 7. 權限、隱私與安全

### 7.1 權限清單

| 平台    | 權限                                                                 | 用途      |
| ------- | -------------------------------------------------------------------- | --------- |
| Android | INTERNET                                                             | 匯率拉取  |
| Android | POST_NOTIFICATIONS、SCHEDULE/USE_EXACT_ALARM、RECEIVE_BOOT_COMPLETED | 提醒      |
| Android | READ_MEDIA_IMAGES、CAMERA                                            | 札記相片  |
| Android | `<queries>` tel/geo/https                                            | 撥號/地圖 |
| iOS     | 通知                                                                 | 提醒      |
| iOS     | NSPhotoLibraryUsageDescription、NSCameraUsageDescription             | 札記相片  |
| iOS     | LSApplicationQueriesSchemes tel/maps/comgooglemaps                   | 撥號/地圖 |

### 7.2 資料儲存

全部資料（SQLite、相片、匯出檔）存於 App 私有沙盒。無帳號、無雲端同步、無第三方分析 SDK。

### 7.3 網路與隱私（v1→v2 變更）

- v1 的「PDF 抽出文字上傳 Claude API」**已移除**；**唯一需網路的環節是即時匯率拉取**（open.er-api / frankfurter.dev，免 key、僅送幣別代碼）。
- PDF 上傳同意旗標（SecureStore）程式保留但未使用。

---

## 8. 錯誤處理與降級

| 情境                              | 行為                                                                                                                            |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| 無網路 / 匯率 API 失敗            | 提示「無法取得最新匯率」，可手動輸入或沿用上次快取，不阻斷支出輸入                                                              |
| 匯率快取過期（>6h 且 source=api） | 匯率管理頁橘色警示，不自動重拉                                                                                                  |
| 撥號/地圖無對應 app               | 退化為複製到剪貼簿 + Snackbar                                                                                                   |
| 通知權限被拒                      | 提醒頁顯示引導橫幅，可重新請求；App 其餘功能正常                                                                                |
| 匯出 PDF 缺中文字型               | 丟 `ExportFontMissingException` → 自動只出 CSV，並提示放入 Noto Sans TC                                                         |
| 相片路徑失效                      | 顯示灰色佔位圖；PDF 匯出以「遺失」佔位圖替代                                                                                    |
| 刪除行程                          | repository 端逐表交易刪除（spots→days→flights→info→reminders→journal→trip），**不倚賴 DB 外鍵 cascade**（Drift 未產生外鍵約束） |
| 啟動 seed 失敗                    | Bootstrap 顯示錯誤與「重試」                                                                                                    |

---

## 8a. 匯率服務規格（ExchangeRateService）　＊v1→v2 變更

### 8a.1 線上拉取

- **主來源 open.er-api**：`https://open.er-api.com/v6/latest/<base>` → `rates[TWD]`（涵蓋 TWD）。
- **備援 Frankfurter（新網域）**：`https://api.frankfurter.dev/v1/latest?base=<base>&symbols=<quote>`（ECB 來源，**不含 TWD**，僅供非 TWD 幣別）。
- 兩者皆失敗 → 丟 `ExchangeRateException`。成功寫入 ExchangeRate，`source=api`。
- ＊原因：v1 指定的 `api.frankfurter.app` 已停用（301）且 ECB 無台幣，故改以 er-api 為主。

### 8a.2 手動輸入

匯率管理頁新增/編輯（預設帶入 JPY）；`source=manual`，無過期機制。

### 8a.3 快取策略

啟動不自動更新；使用者主動「線上取得 / 同步所有匯率」才拉取；同一對 upsert 單筆。

### 8a.4 換算時機與重算

- 儲存支出時若有匯率，立即計算 `amount_twd` 與 `exchange_rate_used`。
- 設定/更新匯率後，`ExchangeRateController.recomputeAllExpenses()` 重算所有行程所有支出。

---

## 8b. PDF 文字與圖片處理（實作補充）

### 8b.1 NFKC 正規化（PdfTextService）

部分 PDF 將中文字編為**康熙部首相容碼點**（如 ⼗ U+2F17、⽥、⾃）。抽取後以 `unorm_dart` 做 NFKC，還原為標準漢字，確保搜尋/顯示一致。

### 8b.2 景點圖片抽取（建置前工具）

以 PyMuPDF（fitz）從 `docs/NSC061306BR6.pdf` 抽出右欄景點圖，依各頁由上而下的閱讀順序對應景點名，輸出至 `assets/sample/spots/`，並於內建 JSON 的 `spots[].image` 引用。共 12 張（部分景點 PDF 無圖則無）。

---

## 9. 測試（實際 42 項，全綠）

### 9.1 單元/整合測試（`flutter test`）

- 資料層：整圖寫入讀回、刪除（逐表交易）、FTS（3 字 trigram / 2 字 LIKE）、支出多幣別加總與台幣換算、匯率 upsert/過期。
- PDF 抽取：以範例 PDF 驗證關鍵欄位（NSC061306BR6、BR122、BR121、十和田莊、領隊電話、奧入瀨、平泉中尊寺、鋰電池、退稅）；NFKC 還原（無康熙部首殘留）。
- Claude 映射（保留功能）：JSON→ParsedTrip、合理性檢查、寫入 Drift；mock HTTP 的 ClaudeApiService（圍欄移除/錯誤分類）。
- 提醒：預設提醒時間計算（集合 05:25、護照 -30 天、晨報 07:00、回程 -3h）。
- 搜尋：鋰電池/退稅/平泉中尊寺命中。
- 札記：加總、相片路徑、entry_type 判定。
- 匯率：er-api 降級、兩源皆敗丟例外、手動設定後重算。
- 匯出：CSV BOM/欄位順序/amount_twd/引號跳脫。
- 設定：主題/語系切換與持久化、啟動讀回。
- Widget：開啟 App 直接進入行程首頁（provider override，避開 testWidgets 下的 drift fake-async）。

### 9.2 已知測試注意事項

- `testWidgets` 下不可使用真實 drift（fake-async 會卡死）→ 以 provider override 餵固定資料。
- 載入中的 `CircularProgressIndicator` 會讓 `pumpAndSettle` 永不 settle → 改用固定次數 `pump`。

---

## 10. 專案結構（實際）

```
lib/
├── main.dart                      # 初始化 tz/日期符號/SharedPreferences + ProviderScope
├── app/                           # router、routes、theme
├── core/                          # constants、enums、id、secure_store、tz、launchers
├── data/
│   ├── database/                  # tables、converters、app_database（FTS5、migration v2）
│   ├── models/                    # parsed_trip
│   └── repositories/              # trip、journal、exchange_rate、reminder、search
├── features/
│   ├── bootstrap/                 # 啟動 seed + 導向首頁
│   ├── trip_home/                 # TripHome、AllDays、trip_providers、widgets/trip_scaffold
│   ├── day_detail/                # DayDetail、SpotDetail、spot_image
│   ├── info_hub/                  # InfoHub、info_labels
│   ├── reminders/                 # 管理頁、default_reminders、reminder_scheduler
│   ├── journal/                   # 三分頁、add_note/expense sheet、photo_viewer、providers
│   ├── journal_export/            # 匯出選項頁
│   ├── exchange_rate/             # 匯率管理頁、controller
│   ├── search/                    # 全文檢索頁
│   ├── settings/                  # 設定頁、settings_controller（持久化）
│   └── import/                    # （保留未用）sample_loader、claude/json mapper、preview…
├── services/                      # pdf_text、claude_api、notification、exchange_rate、export、photo_store
└── l10n/                          # app_zh.arb / app_en.arb（+ generated/）
assets/sample/                     # nsc061306br6.json、spots/*.jpeg
test/                              # 對應 §9
platform_config/                   # Android/iOS 權限片段（已套用至 native runner）
docs/                              # PDF、規格書 v1.1 / v2.0
```

---

## 11. 相依套件（pubspec 實際）

```
flutter_riverpod, go_router,
drift ^2.31, drift_flutter ^0.2, sqlite3_flutter_libs,
syncfusion_flutter_pdf ^33, unorm_dart,
http, flutter_secure_storage,
flutter_local_notifications ^17, timezone,
image_picker, file_picker, path_provider, path,
intl(any，由 flutter_localizations 釘 0.20.x),
url_launcher, share_plus ^12, pdf, printing,
uuid, collection, shared_preferences ^2.3
dev: build_runner, drift_dev ^2.31, flutter_lints, flutter_test
（已移除：riverpod_generator / riverpod_lint / custom_lint）
```

---

## 12. 里程碑（全部完成）

| M   | 里程碑                                                               | 狀態                                                   |
| --- | -------------------------------------------------------------------- | ------------------------------------------------------ |
| M0  | 專案骨架（目錄、主題、路由、i18n）                                   | ✅                                                     |
| M1  | 資料層（Drift schema、repositories、FTS5）                           | ✅                                                     |
| M2  | PDF 文字抽取（pdf_text_service + NFKC）                              | ✅                                                     |
| M3  | 結構化映射（claude_api_service + mapper + 合理性檢查）＊現為保留功能 | ✅                                                     |
| M4  | 行程瀏覽（TripHome/DayDetail/SpotDetail、撥號/地圖）                 | ✅                                                     |
| M5  | 須知與搜尋（InfoHub + FTS5）                                         | ✅                                                     |
| M6  | 提醒（notification_service + 預設提醒 + 管理頁）                     | ✅                                                     |
| M7a | 旅遊記錄（札記/相片/支出、多幣別加總）                               | ✅                                                     |
| M7b | 匯率換算（service + 換算 UI + 重算）                                 | ✅                                                     |
| M7c | 匯出（CSV 完整 / PDF 字型守衛 + share_plus）                         | ✅                                                     |
| M8  | 打磨（深淺色+語系持久化、通知權限引導、空狀態、i18n）                | ✅                                                     |
| —   | 規格調整                                                             | 移除匯入、內建行程、開啟即首頁、景點圖片、完整內文還原 |

---

## 13. 平台/工具鏈備註（實機驗證）

- **開發機**：macOS（arm64）。Flutter 安裝於 `~/development/flutter`（未進全域 PATH）。
- **Android**：以 `~/Library/Android/sdk`（command-line tools）建置；`compileSdk = 36`（含 `subprojects` 強制，因外掛要求）；core library desugaring（flutter_local_notifications）。已在實機 **T951K（Android 15）** 驗證。
- **iOS**：`flutter create` 生成 ios runner；CocoaPods 1.16；已在 **iPhone 13 Pro Max 模擬器（iOS 26.5）** 建置執行（bundle id `com.anaglobe.tripPilot`）。
- **macOS desktop**：亦已生成並可建置（entitlements 加 network.client + files.user-selected.read-only）。
- **codegen**：`dart run build_runner build`（Drift）、`flutter gen-l10n`（i18n）。`*.g.dart` 不提交。

---

## 14. 後續可擴充（不在目前範圍）

- 恢復「匯入 PDF / 貼上 JSON」UI（程式核心已保留）。
- PDF 匯出內嵌 Noto Sans TC subset（目前無字型則降級 CSV）。
- 無障礙稽核（Semantics、對比、字級）。
- 多行程管理（目前單一內建行程）。
- 設定中切換 AI 模型 / API key（匯入恢復時）。
- iCloud / Google Drive 備份。

---

_規格 v2.0 結束。本文件以實際成品為準；與 v1.1 不一致處以本版為準。_
