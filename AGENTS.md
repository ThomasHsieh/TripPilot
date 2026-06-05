# AGENTS.md

本檔提供任何 agent（Claude Code 等）進入本專案的工作守則，內容與 `CLAUDE.md` 互補。

## 工作原則

- **逐里程碑交付**：依規格 §12（M0→M8）順序，每步可獨立編譯、可獨立測試，不要一次產出全部程式碼。
- **離線優先**：除「PDF 結構化」「即時匯率拉取」外，功能不得依賴網路。
- **型別優先**：先定義 Dart model / Drift table，再寫 UI；資料層禁用漏網 `dynamic`。
- **i18n 強制**：UI 字串放 `lib/l10n/*.arb`，以 `AppLocalizations.of(context)` 取用。
- **不硬編機密**：API key 走 `flutter_secure_storage`，永不進 repo。

## Commit 格式

```
Module // SubModule: Description.
```

範例：

- `Importer // PdfText: Extract raw text via Syncfusion.`
- `Data // Schema: Add ExchangeRate table and migration v1.`
- `Journal // Expense: Group totals by currency with TWD conversion.`

## 產生檔

`drift` / `riverpod_generator` / `l10n` 需要 codegen：

```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

`*.g.dart` 不提交（見 `.gitignore`）；clone 後請先跑一次 codegen。

## 目錄導覽

見 `CLAUDE.md` 與規格 §10。重點：

- `lib/data/` 資料層（database / models / repositories）
- `lib/services/` 純邏輯服務（pdf / claude / notification / exchange_rate / export）
- `lib/features/<feature>/` 各功能畫面與 controller（Riverpod）
- `lib/app/` router + theme；`lib/core/` 共用工具與常數

## 驗收

每個里程碑完成後對照規格 §9.3 驗收清單；以 `docs/NSC061306BR6.pdf` 為回歸 fixture。
