> ⚠️ **本檔（v1.1）已被 [`TripPilot_實作規格書_v2.md`](TripPilot_實作規格書_v2.md)（v2.0，依實際成品）取代。**
> 兩者不一致處一律以 v2.0 為準；v1.1 僅供對照初始規劃。
> 主要差異：移除「匯入 PDF」改為內建訂製行程、開啟即進首頁、不使用 Claude API、景點圖片、匯率以 open.er-api 為主等。

---

# 團體旅遊行程 App 實作規格書

> 專案代號：**TripPilot**
> 目標：將團體旅遊行程 PDF 匯入後，可供查詢、瀏覽、提醒及旅遊中記錄的跨平台 App（Android + iOS）
> 文件版本：v1.1｜撰寫日期：2026/06/04｜更新：2026/06/04（新增匯出與匯率功能）
> 本文件供 Claude Code 直接作為實作依據。所有「實作規則（Implementation Rules）」段落為硬性約束。

---

## 0. 給 Claude Code 的前置說明（Agent Context）

實作此專案時請遵守以下原則：

1. **逐模組交付**：依第 12 節的里程碑順序實作，每個里程碑可獨立編譯、可獨立測試，不要一次產出全部程式碼。
2. **型別優先**：所有資料模型先定義 Dart class / Drift table，再寫 UI。資料層不可有 `dynamic` 漏網。
3. **離線為預設**：除「PDF 結構化」與「即時匯率拉取」外，App 任何功能不得依賴網路。沒有網路時 App 必須完整可用（匯率降級為手動輸入，匯出功能不需網路）。
4. **commit 格式**：`Module // SubModule: Description.`（例：`Importer // PdfText: Extract raw text via Syncfusion.`）
5. 專案根目錄需有 `CLAUDE.md` 與 `AGENTS.md` 提供 agent 上下文（內容見第 13 節）。
6. 中文（繁體）為第一語系，UI 字串一律走 i18n，不可硬編中文於 widget 內。

---

## 1. 產品概述

### 1.1 解決的問題

團體旅遊（如可樂旅遊）的行程表 PDF 資訊密集、版型半結構化，旅客在旅途中查資料不便：要查當天飯店電話、集合時間、餐食、退費條款都得翻 PDF。本 App 把 PDF 一鍵轉成結構化、可查詢、可提醒、可記錄的行程助手。

### 1.2 核心使用流程

```
匯入 PDF → AI 結構化解析 → 確認/微調 → 行程卡片瀏覽
                                              ↓
                          旅遊中：每日視圖 + 提醒 + 札記/相片/支出記錄
```

### 1.3 設計原則

- **單一行程焦點**：旅途中 App 預設直接打開「今天」。
- **零學習成本**：資訊以卡片呈現，重要欄位（集合時間、飯店電話、領隊電話）永遠一鍵可達。
- **資料主權**：所有資料留在裝置；PDF 解析時僅上傳必要文字，且須明確告知使用者。

---

## 2. 技術選型（已定案）

| 層級         | 選型                                                   | 理由                                             |
| ------------ | ------------------------------------------------------ | ------------------------------------------------ |
| 框架         | **Flutter 3.x（Dart 3, sound null safety）**           | 單一碼庫雙平台；型別嚴謹；套件生態成熟           |
| 狀態管理     | **Riverpod 2.x**                                       | 編譯期安全、可測試、無 BuildContext 依賴         |
| 本地資料庫   | **Drift（SQLite）**                                    | 型別安全 ORM、支援 migration、適合關聯式行程資料 |
| PDF 文字抽取 | **Syncfusion Flutter PDF**（`syncfusion_flutter_pdf`） | 中文抽取穩定、可取頁文字與基本座標               |
| AI 結構化    | **Anthropic Claude API（雲端）**                       | 將半結構化中文版型轉 JSON；唯一需網路的環節      |
| 本地通知     | **flutter_local_notifications** + **timezone**         | 跨平台排程通知，支援時區                         |
| 路由         | **go_router**                                          | 宣告式路由                                       |
| 國際化       | **flutter_localizations + intl（.arb）**               | zh-Hant 為主，預留 en                            |
| 相片/檔案    | **image_picker, path_provider**                        | 旅遊札記相片                                     |
| 匯出         | **pdf（dart）、share_plus**                            | 旅遊記錄匯出為 PDF / CSV，透過系統分享表單傳送   |
| 匯率         | **http（已有）+ 自訂 ExchangeRateService**             | 線上拉取免費 API；離線降級為手動輸入             |

### 2.1 PDF 解析架構決策（重要）

- 採 **混合架構**：裝置端抽純文字 → 上傳文字（非整份 PDF 圖檔）給 Claude API → 回傳結構化 JSON。
- **為何不純裝置端**：此類中文表格版型（跨欄、跨頁、混排日文地名）的純 on-device NLP 品質不足，誤抽率高。
- **為何不上傳整份 PDF**：降低流量與隱私暴露，只送抽出的文字段落。
- **隱私約束**：上傳前必須跳出明確同意對話框（見 §7.3）。

---

## 3. 資料模型（Drift Schema）

> 以下為邏輯 schema。Claude Code 實作時轉為 Drift table 定義並產生 migration v1。

### 3.1 Trip（行程主檔）

| 欄位                  | 型別           | 說明                            |
| --------------------- | -------------- | ------------------------------- |
| id                    | TEXT (uuid) PK | 行程唯一碼                      |
| tour_code             | TEXT           | 團號，例 `NSC061306BR6`         |
| title                 | TEXT           | 行程名稱                        |
| start_date            | DATE           | 出發日                          |
| end_date              | DATE           | 回程日                          |
| leader_name           | TEXT           | 領隊/導遊姓名                   |
| leader_phone_domestic | TEXT           | 國內電話                        |
| leader_phone_overseas | TEXT           | 國外電話                        |
| airport_service_line  | TEXT           | 機場服務專線                    |
| meetup_time           | DATETIME       | 集合時間                        |
| meetup_location       | TEXT           | 集合地點                        |
| luggage_tag           | TEXT           | 行李牌顏色/識別                 |
| source_pdf_path       | TEXT           | 原始 PDF 本地路徑               |
| raw_json              | TEXT           | AI 解析原始 JSON（供重建/除錯） |
| created_at            | DATETIME       |                                 |

### 3.2 DayPlan（每日安排）

| 欄位           | 型別              | 說明                                  |
| -------------- | ----------------- | ------------------------------------- |
| id             | TEXT PK           |                                       |
| trip_id        | TEXT FK → Trip.id |                                       |
| day_index      | INT               | 第幾天（1-based）                     |
| date           | DATE              | 當日日期                              |
| route_summary  | TEXT              | 旅行區間，例「奧入瀨溪流 > 十和田湖」 |
| hotel_name     | TEXT              | 飯店名稱                              |
| hotel_name_en  | TEXT              | 飯店英文/羅馬名                       |
| hotel_phone    | TEXT              | 飯店電話                              |
| meal_breakfast | TEXT              | 早餐                                  |
| meal_lunch     | TEXT              | 午餐                                  |
| meal_dinner    | TEXT              | 晚餐                                  |
| notes          | TEXT              | 當日特別提醒                          |

### 3.3 Flight（航班）

| 欄位         | 型別     | 說明       |
| ------------ | -------- | ---------- |
| id           | TEXT PK  |            |
| trip_id      | TEXT FK  |            |
| day_index    | INT      | 對應天     |
| flight_no    | TEXT     | 例 `BR122` |
| carrier      | TEXT     | 航空公司   |
| depart_time  | DATETIME | 出發       |
| arrive_time  | DATETIME | 抵達       |
| from_airport | TEXT     |            |
| to_airport   | TEXT     |            |

### 3.4 Spot（景點 / 活動，DayPlan 之下的節點）

| 欄位        | 型別                 | 說明                                                     |
| ----------- | -------------------- | -------------------------------------------------------- |
| id          | TEXT PK              |                                                          |
| day_id      | TEXT FK → DayPlan.id |                                                          |
| order_index | INT                  | 當日排序                                                 |
| name        | TEXT                 | 景點名                                                   |
| visit_type  | TEXT enum            | `enter`(入內參觀)/`photo`(下車拍照)/`drive_by`(行車經過) |
| description | TEXT                 | 景點介紹                                                 |
| refund_note | TEXT                 | 退費條款，例「停駛退費500日幣/位」                       |

### 3.5 InfoSection（注意事項 / 行前提醒 / 須知，全文知識庫）

| 欄位        | 型別      | 說明                                                                     |
| ----------- | --------- | ------------------------------------------------------------------------ |
| id          | TEXT PK   |                                                                          |
| trip_id     | TEXT FK   |                                                                          |
| category    | TEXT enum | `notice`/`tipping`/`baggage`/`hotel`/`safety`/`customs`/`health`/`guide` |
| title       | TEXT      | 段落標題                                                                 |
| body        | TEXT      | 段落全文（供全文檢索）                                                   |
| order_index | INT       |                                                                          |

### 3.6 Reminder（提醒）

| 欄位               | 型別      | 說明                                   |
| ------------------ | --------- | -------------------------------------- |
| id                 | TEXT PK   |                                        |
| trip_id            | TEXT FK   |                                        |
| ref_type           | TEXT enum | `meetup`/`flight`/`day_start`/`custom` |
| ref_id             | TEXT      | 關聯來源 id（nullable）                |
| fire_at            | DATETIME  | 觸發時間                               |
| title              | TEXT      |                                        |
| body               | TEXT      |                                        |
| enabled            | BOOL      |                                        |
| os_notification_id | INT       | 對應 flutter_local_notifications 的 id |

### 3.7 JournalEntry（旅遊中記錄）

| 欄位               | 型別              | 說明                                         |
| ------------------ | ----------------- | -------------------------------------------- |
| id                 | TEXT PK           |                                              |
| trip_id            | TEXT FK           |                                              |
| day_index          | INT nullable      | 綁定到某天（可空）                           |
| entry_type         | TEXT enum         | `note`/`photo`/`expense`                     |
| text               | TEXT              | 文字內容                                     |
| photo_paths        | TEXT (json array) | 相片本地路徑陣列                             |
| amount             | REAL nullable     | 支出金額（原始幣別）                         |
| currency           | TEXT nullable     | 幣別，預設 JPY                               |
| amount_twd         | REAL nullable     | 換算後台幣金額（快取，可為 null 代表未換算） |
| exchange_rate_used | REAL nullable     | 換算時使用的匯率（留存供核帳）               |
| created_at         | DATETIME          |                                              |
| location_label     | TEXT nullable     | 手動標記地點                                 |

### 3.8 ExchangeRate（匯率快取）

| 欄位           | 型別      | 說明                                                 |
| -------------- | --------- | ---------------------------------------------------- |
| id             | TEXT PK   | `base_currency + '_' + quote_currency`，例 `JPY_TWD` |
| base_currency  | TEXT      | 來源幣別                                             |
| quote_currency | TEXT      | 目標幣別，預設 TWD                                   |
| rate           | REAL      | 匯率值（1 base = rate quote）                        |
| source         | TEXT enum | `api`（線上取得）/ `manual`（使用者手動輸入）        |
| fetched_at     | DATETIME  | 取得時間，超過 6 小時提示可更新                      |

---

## 4. AI 結構化解析規格（Importer 模組）

### 4.1 流程

```
1. 使用者選 PDF（file_picker）
2. Syncfusion 逐頁抽取純文字 → 合併為 rawText
3. 顯示隱私同意對話框（§7.3），同意後繼續
4. 呼叫 Claude API，system prompt 要求「只輸出 JSON，無前後綴、無 markdown 圍欄」
5. 解析回傳 JSON → 映射為 Trip/DayPlan/Flight/Spot/InfoSection
6. 進入「匯入預覽」頁，使用者可逐欄修正
7. 確認 → 寫入 Drift，自動建立預設 Reminder（§6.2）
```

### 4.2 Claude API 呼叫約束（Implementation Rules）

- 模型字串以設定檔常數管理，預設 `claude-opus-4-8`（可由使用者在設定改）。
- **絕不在程式碼或 repo 內硬編 API key**；key 由使用者於 App 設定頁輸入，存於平台安全儲存（`flutter_secure_storage`）。
- `max_tokens` 充足以容納整份行程（建議 8192）。
- system prompt 明確要求輸出符合 §4.3 的 JSON schema，且「找不到的欄位填 null，不要捏造」。
- 回傳需 try/catch + JSON 容錯：先 strip 可能的 ```json 圍欄再 parse；parse 失敗則進入「手動建立」降級流程，不可崩潰。

### 4.3 目標 JSON Schema（API 回傳契約）

```json
{
  "tour_code": "string|null",
  "title": "string|null",
  "start_date": "YYYY-MM-DD|null",
  "end_date": "YYYY-MM-DD|null",
  "leader_name": "string|null",
  "leader_phone_domestic": "string|null",
  "leader_phone_overseas": "string|null",
  "airport_service_line": "string|null",
  "meetup_time": "YYYY-MM-DDTHH:mm|null",
  "meetup_location": "string|null",
  "luggage_tag": "string|null",
  "flights": [
    {
      "day_index": 1,
      "flight_no": "BR122",
      "carrier": "長榮航空",
      "depart_time": "2026-06-13T09:55",
      "arrive_time": "2026-06-13T14:20",
      "from_airport": "台北(桃園)",
      "to_airport": "青森縣"
    }
  ],
  "days": [
    {
      "day_index": 1,
      "date": "YYYY-MM-DD",
      "route_summary": "string",
      "hotel_name": "string|null",
      "hotel_name_en": "string|null",
      "hotel_phone": "string|null",
      "meal_breakfast": "string|null",
      "meal_lunch": "string|null",
      "meal_dinner": "string|null",
      "notes": "string|null",
      "spots": [
        {
          "order_index": 1,
          "name": "奧入瀨溪流",
          "visit_type": "enter|photo|drive_by",
          "description": "string|null",
          "refund_note": "string|null"
        }
      ]
    }
  ],
  "info_sections": [
    {
      "category": "notice|tipping|baggage|hotel|safety|customs|health|guide",
      "title": "string",
      "body": "string",
      "order_index": 1
    }
  ]
}
```

### 4.4 解析品質防呆

- 解析後做合理性檢查：天數與日期連續性、航班日期落在行程區間內、集合時間早於首班機。
- 任一檢查失敗 → 在預覽頁以黃色標記提示，但仍允許使用者手動修正後存檔。

---

## 5. 畫面與導覽（UI Spec）

### 5.1 路由表（go_router）

| 路徑                       | 畫面                | 說明                          |
| -------------------------- | ------------------- | ----------------------------- |
| `/`                        | TripListScreen      | 行程清單（多個已匯入行程）    |
| `/import`                  | ImportScreen        | 選 PDF + 解析進度             |
| `/import/preview`          | ImportPreviewScreen | 解析結果預覽/修正             |
| `/trip/:id`                | TripHomeScreen      | 行程首頁（旅途中預設落地頁）  |
| `/trip/:id/day/:dayIndex`  | DayDetailScreen     | 單日詳情                      |
| `/trip/:id/spot/:spotId`   | SpotDetailScreen    | 景點詳情                      |
| `/trip/:id/info`           | InfoHubScreen       | 注意事項/須知知識庫（可搜尋） |
| `/trip/:id/reminders`      | RemindersScreen     | 提醒管理                      |
| `/trip/:id/journal`        | JournalScreen       | 旅遊札記/支出                 |
| `/trip/:id/journal/export` | JournalExportScreen | 匯出選項（格式、範圍）        |
| `/trip/:id/search`         | SearchScreen        | 全行程全文檢索                |
| `/settings`                | SettingsScreen      | API key、模型、語系           |
| `/settings/exchange-rates` | ExchangeRateScreen  | 匯率查詢與手動管理            |

### 5.2 TripHomeScreen（核心畫面）

- 頂部固定卡片：**領隊姓名 + 一鍵撥號**（國內/國外）、**機場服務專線**。
- 旅途期間（今日落在 start~end）：自動展開「今日」卡片，顯示當日 route_summary、飯店（含一鍵撥號 + 一鍵地圖）、三餐、特別提醒。
- 行程未開始：顯示倒數 + 集合資訊卡（集合時間/地點/行李牌/首班機）。
- 底部導覽列：今日 / 全程 / 札記 / 須知 / 搜尋。

### 5.3 DayDetailScreen

- 時間軸式呈現 Spot 列表，visit_type 以圖示區分（入內 📍 / 拍照 📷 / 經過 🚌）。
- 飯店區塊：名稱、電話（撥號）、地圖（開啟系統地圖 app，以飯店名+英文名查詢）。
- 餐食三欄。
- 退費條款（refund_note）以醒目標籤顯示。

### 5.4 InfoHubScreen

- 依 category 分頁籤（注意事項、小費、行李、住宿、安全、海關、防疫、導遊提醒）。
- 頂部搜尋框做全文檢索（對 InfoSection.body）。

### 5.5 JournalScreen

- 三類記錄 Tab：札記（文字+相片）、支出（金額+幣別+類別）、相片牆。
- 支出頁底部即時加總區塊（見 §5.8）。
- 記錄可綁定到某天（day_index），預設綁今天。
- 右上角「匯出」按鈕，進入 JournalExportScreen。

### 5.6 SearchScreen

- 對 Spot.name/description、DayPlan、InfoSection.body 做 SQLite 全文檢索（FTS5）。
- 結果分類顯示：景點 / 每日 / 須知。

### 5.7 設計風格（交給 frontend 實作時參考）

- 卡片式、留白充足、繁中字體優先（Noto Sans TC）。
- 旅途中重要動作（撥號、地圖、今日）必須大按鈕、單手可達。
- 深淺色主題皆支援。

### 5.8 支出頁匯率換算 UI

**加總區塊（支出 Tab 底部固定）**

- 依幣別分組顯示原始加總，例：`JPY 18,500`、`TWD 420`。
- 若 ExchangeRate 表內有對應匯率，額外顯示「≈ TWD 合計 X,XXX」換算總計。
- 匯率來源標示：「1 JPY = 0.215 TWD（2026/06/13 更新 · 線上）」，若為手動則標示「手動輸入」。
- 右側小按鈕「更新匯率」，有網路時觸發線上拉取，無網路時開啟手動輸入 dialog。

**新增支出 dialog**

- 欄位：金額（數字鍵盤）、幣別（下拉，預設 JPY；常用幣別 JPY/TWD/USD/EUR 置頂）、類別（餐飲/交通/購物/門票/住宿/其他）、備註（可空）、日期（預設今天）。
- 輸入金額後即時顯示換算台幣預覽（若有匯率）。

**ExchangeRateScreen（設定 → 匯率管理）**

- 清單顯示所有已存匯率對（base → TWD），含取得時間與來源。
- 每筆可手動編輯覆寫。
- 「同步所有匯率」一鍵線上更新。
- 新增任意幣別對（供非 JPY 行程使用）。

### 5.9 JournalExportScreen（匯出選項）

**匯出範圍（Radio 選擇）**

- 全部記錄
- 僅支出
- 僅札記與相片
- 依日期範圍（DatePicker 選擇 start ~ end）

**匯出格式（Checkbox，可複選）**

- `PDF 報告`：含行程摘要（團號/日期/領隊）+ 按日分段的支出與札記，支出附台幣換算欄，相片縮圖內嵌。
- `CSV（支出明細）`：含 date, day_index, category, currency, amount, amount_twd, exchange_rate_used, note 欄位，UTF-8 BOM（Excel 可直接開啟）。

**執行流程**

1. 使用者選好範圍+格式 → 點「產生」。
2. 在背景 Isolate 產生檔案（PDF 用 `pdf` 套件；CSV 純字串拼接）。
3. 完成後呼叫 `share_plus` 開啟系統分享表單（可傳 AirDrop、存檔、傳 LINE 等）。
4. 同時在 App Documents 目錄留一份副本，清單顯示於頁面底部「歷史匯出」。

**匯出 PDF 報告版面規格**

- 封面：行程名稱、團號、日期區間、領隊。
- 每日一節：`Day N | YYYY/MM/DD | 路線摘要`，下方列支出卡片 + 札記文字 + 相片縮圖（最寬 400px）。
- 尾頁：支出總計表（依幣別 + 類別交叉統計）、台幣換算總計。
- 字型：內嵌 Noto Sans TC subset（避免中文亂碼）。

---

## 6. 提醒系統（Reminder 模組）

### 6.1 技術

- `flutter_local_notifications` + `timezone`，以行程目的地時區（日本 = Asia/Tokyo）與本地時區雙軌處理。
- iOS 需請求通知權限；Android 13+ 需 `POST_NOTIFICATIONS` 權限與精確鬧鐘權限處理。

### 6.2 匯入後自動建立的預設提醒

| 提醒     | 觸發時間                                                     | 內容                                      |
| -------- | ------------------------------------------------------------ | ----------------------------------------- |
| 集合提醒 | 集合時間前 2 小時（依注意事項「起飛前 2.5 小時集合」可設定） | 「今日 07:25 於桃園二航廈 19 號櫃檯集合」 |
| 護照效期 | 出發前 30 天                                                 | 「確認護照效期六個月以上」                |
| 每日晨報 | 每天當地 07:00                                               | 「Day N：今日行程與飯店資訊」             |
| 回程班機 | 回程起飛前 3 小時                                            | 「BR121 15:30 起飛，請預留時間」          |

### 6.3 使用者可自訂

- 任一 Spot/Flight/DayPlan 可手動加提醒。
- 全域開關可一鍵關閉所有提醒。

---

## 7. 權限、隱私與安全

### 7.1 權限清單

| 平台    | 權限                                     | 用途     |
| ------- | ---------------------------------------- | -------- |
| iOS     | 通知                                     | 提醒     |
| iOS     | 相片/相機                                | 札記相片 |
| Android | POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM | 提醒     |
| Android | READ_MEDIA_IMAGES / CAMERA               | 札記相片 |
| 兩者    | 檔案存取                                 | 選取 PDF |

### 7.2 資料儲存

- 全部資料（SQLite、相片、原始 PDF）存於 App 私有沙盒。
- 無帳號、無雲端同步、無第三方分析 SDK。

### 7.3 PDF 上傳同意（Implementation Rule）

- 第一次解析前必跳對話框，明確說明：「為解析行程，本 App 將把 PDF 抽出的**文字內容**傳送至 Anthropic Claude API。PDF 原檔不會上傳。是否同意？」
- 使用者可選擇記住同意。拒絕則只能走手動建立行程。

---

## 8. 錯誤處理與降級

| 情境                           | 行為                                                                                                     |
| ------------------------------ | -------------------------------------------------------------------------------------------------------- |
| 無網路 / API 失敗              | 提示，提供「重試」或「改用手動建立」                                                                     |
| JSON parse 失敗                | 記錄 raw_json，進手動修正流程，不崩潰                                                                    |
| PDF 無法抽文字（純圖檔掃描件） | 提示「此 PDF 為圖片格式，請改用可選取文字的版本或手動建立」                                              |
| 通知權限被拒                   | App 仍可用，提醒功能標示停用並引導至系統設定                                                             |
| 撥號/地圖無對應 app            | 退化為複製到剪貼簿                                                                                       |
| 匯率 API 無法連線              | 顯示「無法取得最新匯率，請手動輸入或使用上次匯率（YYYY/MM/DD）」；使用上次快取值繼續運算，不阻斷支出輸入 |
| 匯率快取過期（> 6 小時）       | 支出加總旁顯示橘色警示「匯率已於 N 小時前更新，建議重新取得」，不阻斷功能                                |
| 匯出 PDF 產生失敗              | 提示錯誤訊息，保留 CSV 匯出作為降級選項                                                                  |
| 相片路徑失效（匯出時）         | 以灰色佔位圖替代，匯出繼續完成，尾頁附遺失相片清單                                                       |

---

## 8a. 匯率服務規格（ExchangeRateService）

### 8a.1 線上拉取

- 使用 **Frankfurter API**（`https://api.frankfurter.app/latest?from=JPY&to=TWD`）：免費、無需 API key、支援主流幣別。
- 若 Frankfurter 不可用，降級嘗試 **ExchangeRate-API 免費端點**（`https://open.er-api.com/v6/latest/JPY`）。
- 拉取成功後，寫入 ExchangeRate table，`source = 'api'`，更新 `fetched_at`。

### 8a.2 手動輸入

- 使用者在 ExchangeRateScreen 或支出頁「更新匯率」dialog 輸入數值。
- 寫入 ExchangeRate table，`source = 'manual'`，`fetched_at` 設為當下時間。
- 手動值沒有過期機制（不顯示橘色警示），除非使用者主動更新。

### 8a.3 快取策略（Implementation Rule）

- App 啟動時若 ExchangeRate 快取存在，直接使用，不自動背景更新（避免不必要的網路請求）。
- 使用者主動觸發（按「更新匯率」）才拉取。
- 快取超過 6 小時且 source 為 `api` → 顯示橘色警示；不自動重拉。
- 同一 base/quote 對只保留一筆（upsert），不累積歷史。

### 8a.4 JournalEntry 換算時機

- 儲存支出時，若當下有 ExchangeRate 快取，立即計算 `amount_twd` 與 `exchange_rate_used` 並一起存入。
- 若無快取（初次使用、未曾設定），`amount_twd` 存 null，等使用者設定匯率後可觸發「重新計算所有支出」批次更新。

---

### 9.1 單元測試

- Importer：以本專案附帶的範例 PDF（NSC061306BR6）為 fixture，驗證解析出 6 天、2 航班、團號正確、領隊電話正確。
- Reminder：驗證預設提醒時間計算（時區、提前量）。
- Journal：支出加總（多幣別分組）；換算台幣金額精度（小數點 2 位）。
- ExchangeRateService：線上 API mock 回傳 → 存入快取；過期邏輯（> 6 小時）判斷正確。
- Export：CSV 欄位順序與 BOM 正確；PDF 產生不崩潰（smoke test）。

### 9.2 Widget / 整合測試

- 匯入 → 預覽 → 存檔 → TripHome 顯示今日 的完整流程測試。
- 全文檢索命中率測試。

### 9.3 驗收標準（以範例 PDF）

- [ ] 匯入後正確顯示 6 天行程、團號 NSC061306BR6
- [ ] Day1 顯示 BR122 09:55→14:20、飯店「十和田莊 0176-75-2221」
- [ ] Day4 Spot 含「平泉中尊寺」、退費條款正確帶入
- [ ] 須知頁可搜尋到「鋰電池」「退稅」相關段落
- [ ] 集合提醒於 06/13 05:25（前 2 小時）排程成功
- [ ] 飯店電話一鍵撥號、一鍵地圖可開啟
- [ ] 新增 JPY 支出後，底部加總顯示原幣與台幣換算值
- [ ] 無網路時手動輸入匯率 → 換算正確 → 快取 source 標記為 `manual`
- [ ] 有網路時「更新匯率」成功拉取 JPY→TWD，快取更新時間戳
- [ ] 匯出 CSV：開啟後欄位完整、中文不亂碼、amount_twd 欄有值
- [ ] 匯出 PDF：含封面、每日支出、尾頁統計表，中文正常顯示
- [ ] 系統分享表單正常觸發（share_plus）

---

## 10. 專案結構（建議目錄）

```
lib/
├── main.dart
├── app/                  # App 入口、主題、路由
│   ├── router.dart
│   └── theme.dart
├── core/                 # 共用：常數、錯誤、工具
│   ├── secure_store.dart
│   └── tz.dart
├── data/
│   ├── database/         # Drift tables, daos, migration
│   ├── models/           # Dart data classes
│   └── repositories/
├── features/
│   ├── import/           # Importer + Claude API client + preview
│   ├── trip_home/
│   ├── day_detail/
│   ├── info_hub/
│   ├── reminders/
│   ├── journal/          # 札記/相片/支出
│   ├── journal_export/   # 匯出選項、PDF/CSV 產生
│   ├── exchange_rate/    # 匯率管理頁
│   ├── search/
│   └── settings/
├── services/
│   ├── pdf_text_service.dart
│   ├── claude_api_service.dart
│   ├── notification_service.dart
│   ├── exchange_rate_service.dart   # 線上拉取 + 快取讀寫
│   └── export_service.dart          # PDF / CSV 產生（跑於 Isolate）
└── l10n/                 # .arb 檔
test/
└── fixtures/NSC061306BR6.pdf
```

---

## 11. 相依套件（pubspec 預期）

```
flutter_riverpod, go_router, drift, drift_flutter, sqlite3_flutter_libs,
syncfusion_flutter_pdf, file_picker, http, flutter_secure_storage,
flutter_local_notifications, timezone, image_picker, path_provider,
intl, url_launcher, uuid,
pdf, share_plus
dev: build_runner, drift_dev, riverpod_generator, flutter_test
```

---

## 12. 實作里程碑（交付順序）

| M   | 里程碑       | 產出                                                                                    | 完成定義                                    |
| --- | ------------ | --------------------------------------------------------------------------------------- | ------------------------------------------- |
| M0  | 專案骨架     | Flutter 專案、目錄結構、CLAUDE.md/AGENTS.md、主題、路由空殼                             | `flutter run` 可啟動，導覽到各空頁          |
| M1  | 資料層       | Drift schema v1（含 ExchangeRate table）、models、repositories                          | 可建立/讀取假資料，migration 通過           |
| M2  | PDF 文字抽取 | pdf_text_service + 選檔 UI                                                              | 選範例 PDF 印出 rawText                     |
| M3  | AI 結構化    | claude_api_service + JSON 映射 + 預覽頁                                                 | 範例 PDF 解析出 §9.3 結果                   |
| M4  | 行程瀏覽     | TripHome / DayDetail / SpotDetail                                                       | 今日卡片、撥號、地圖可用                    |
| M5  | 須知與搜尋   | InfoHub + FTS5 全文檢索                                                                 | 關鍵字搜尋命中                              |
| M6  | 提醒         | notification_service + 預設提醒 + 管理頁                                                | 集合提醒實機排程成功                        |
| M7a | 旅遊記錄基礎 | Journal（札記/相片）、支出輸入                                                          | 記錄可存、依日加總正確                      |
| M7b | 匯率換算     | exchange_rate_service（線上拉取 + 手動輸入 + 快取）、支出頁換算顯示、ExchangeRateScreen | 線上/手動兩路徑皆通過驗收；過期警示正確顯示 |
| M7c | 匯出         | export_service（PDF + CSV）、JournalExportScreen、share_plus                            | CSV 欄位正確；PDF 中文不亂碼；分享表單觸發  |
| M8  | 打磨         | 錯誤處理、深淺色、i18n、無障礙                                                          | 通過 §9 完整驗收清單                        |

---

## 13. CLAUDE.md / AGENTS.md 應包含內容

放置於 repo 根目錄，供後續 agent session 快速進入狀態：

- 專案目標一句話 + 技術棧表（§2）
- 硬性規則：離線優先、不硬編 key、commit 格式、繁中 i18n
- 資料模型摘要（§3 的 table 名稱與關聯）
- AI 解析的 JSON 契約位置（§4.3）
- 目前里程碑進度（手動維護勾選）
- 範例 PDF 作為回歸測試 fixture 的路徑

---

## 14. 後續可擴充（不在 v1 範圍，僅備註）

- 多人共享行程（需引入帳號 → 與目前純本地原則衝突，列為 v2 評估）
- 離線地圖圖磚快取
- 多幣別交叉換算（目前僅支援 X → TWD；v1.1 可擴充任意幣別對）
- iCloud / Google Drive 備份（純本地資料的異機還原需求）

---

_規格結束。Claude Code 請從 M0 開始，逐里程碑實作並回報。_
