import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/enums.dart';
import '../data/database/app_database.dart';

/// PDF 需要中文字型但 assets 內找不到時丟出（§8 → 降級 CSV）。
class ExportFontMissingException implements Exception {
  const ExportFontMissingException();
}

/// 匯出產生結果。
class ExportResult {
  const ExportResult({
    required this.paths,
    required this.pdfFontMissing,
  });
  final List<String> paths;
  final bool pdfFontMissing;
}

/// 旅遊記錄匯出（§5.9）：CSV（支出明細）與 PDF（報告），透過 share_plus 分享。
class ExportService {
  const ExportService();

  static const String _fontAsset = 'assets/fonts/NotoSansTC-Regular.ttf';

  // ── CSV ───────────────────────────────────────────────────

  /// 支出明細 CSV，UTF-8 BOM（Excel 可直接開啟）。欄位順序見 §5.9。
  String buildExpenseCsv(List<JournalEntryRow> expenses) {
    final DateFormat df = DateFormat('yyyy-MM-dd');
    final StringBuffer sb = StringBuffer('﻿');
    sb.writeln(
      'date,day_index,category,currency,amount,amount_twd,'
      'exchange_rate_used,note',
    );
    for (final JournalEntryRow e in expenses) {
      if (e.entryType != EntryType.expense) continue;
      sb.writeln(<String>[
        df.format(e.createdAt),
        e.dayIndex?.toString() ?? '',
        e.expenseCategory?.wireName ?? '',
        e.currency ?? '',
        e.amount?.toString() ?? '',
        e.amountTwd?.toStringAsFixed(2) ?? '',
        e.exchangeRateUsed?.toString() ?? '',
        _csv(e.entryText ?? ''),
      ].join(','));
    }
    return sb.toString();
  }

  String _csv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  // ── PDF ───────────────────────────────────────────────────

  Future<pw.Font> _loadFont() async {
    try {
      final ByteData data = await rootBundle.load(_fontAsset);
      return pw.Font.ttf(data);
    } on Object {
      throw const ExportFontMissingException();
    }
  }

  /// 產生 PDF 報告位元組。封面 + 每日支出/札記/相片 + 尾頁總計（§5.9）。
  Future<Uint8List> buildReportPdf({
    required TripRow trip,
    required List<DayPlanRow> days,
    required List<JournalEntryRow> entries,
  }) async {
    final pw.Font font = await _loadFont();
    final pw.ThemeData theme = pw.ThemeData.withFont(base: font, bold: font);
    final pw.Document doc = pw.Document();
    final DateFormat df = DateFormat('yyyy/MM/dd');
    final NumberFormat nf = NumberFormat('#,##0.##');

    final Map<int, DayPlanRow> dayByIndex = <int, DayPlanRow>{
      for (final DayPlanRow d in days) d.dayIndex: d,
    };
    final List<int> dayKeys = <int>{
      for (final JournalEntryRow e in entries)
        if (e.dayIndex != null) e.dayIndex!,
    }.toList()
      ..sort();

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        build: (pw.Context ctx) => <pw.Widget>[
          // 封面
          pw.Header(level: 0, text: trip.title ?? trip.tourCode ?? 'Trip'),
          pw.Text(trip.tourCode ?? ''),
          if (trip.startDate != null && trip.endDate != null)
            pw.Text('${df.format(trip.startDate!)} ~ '
                '${df.format(trip.endDate!)}'),
          if (trip.leaderName != null) pw.Text('領隊：${trip.leaderName}'),
          pw.SizedBox(height: 12),

          // 每日
          for (final int dk in dayKeys)
            _daySection(dayByIndex[dk], dk, entries, nf, df),
          // 未綁定日期的記錄
          _daySection(null, null, entries, nf, df),

          // 尾頁總計
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: '支出總計'),
          _totalsTable(entries, nf),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _daySection(
    DayPlanRow? day,
    int? dayIndex,
    List<JournalEntryRow> all,
    NumberFormat nf,
    DateFormat df,
  ) {
    final List<JournalEntryRow> items =
        all.where((JournalEntryRow e) => e.dayIndex == dayIndex).toList();
    if (items.isEmpty) return pw.SizedBox();

    final String title = dayIndex == null
        ? '未分類'
        : 'Day $dayIndex'
            '${day?.date != null ? ' | ${df.format(day!.date!)}' : ''}'
            '${day?.routeSummary != null ? ' | ${day!.routeSummary}' : ''}';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.SizedBox(height: 8),
        pw.Header(level: 2, text: title),
        for (final JournalEntryRow e in items)
          if (e.entryType == EntryType.expense)
            pw.Bullet(
              text: '${e.currency ?? ''} ${nf.format(e.amount ?? 0)}'
                  '${e.amountTwd != null ? ' (≈ ${nf.format(e.amountTwd!)} TWD)' : ''}'
                  '${e.entryText != null && e.entryText!.isNotEmpty ? ' — ${e.entryText}' : ''}',
            )
          else
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                if (e.entryText != null && e.entryText!.isNotEmpty)
                  pw.Bullet(text: e.entryText!),
                _photoRow(e.photoPaths),
              ],
            ),
      ],
    );
  }

  pw.Widget _photoRow(List<String> paths) {
    if (paths.isEmpty) return pw.SizedBox();
    final List<pw.Widget> imgs = <pw.Widget>[];
    for (final String path in paths) {
      final File f = File(path);
      if (f.existsSync()) {
        imgs.add(
          pw.Container(
            width: 120,
            height: 120,
            margin: const pw.EdgeInsets.only(right: 6, top: 4),
            child: pw.Image(
              pw.MemoryImage(f.readAsBytesSync()),
              fit: pw.BoxFit.cover,
            ),
          ),
        );
      } else {
        imgs.add(
          pw.Container(
            width: 120,
            height: 120,
            margin: const pw.EdgeInsets.only(right: 6, top: 4),
            color: PdfColors.grey300,
            alignment: pw.Alignment.center,
            child: pw.Text('遺失', style: const pw.TextStyle(fontSize: 10)),
          ),
        );
      }
    }
    return pw.Wrap(children: imgs);
  }

  pw.Widget _totalsTable(List<JournalEntryRow> entries, NumberFormat nf) {
    final Map<String, double> byCur = <String, double>{};
    double twd = 0;
    for (final JournalEntryRow e in entries) {
      if (e.entryType != EntryType.expense) continue;
      final String cur = e.currency ?? 'JPY';
      byCur.update(cur, (double v) => v + (e.amount ?? 0),
          ifAbsent: () => e.amount ?? 0);
      if (cur == 'TWD') {
        twd += e.amount ?? 0;
      } else if (e.amountTwd != null) {
        twd += e.amountTwd!;
      }
    }
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      children: <pw.TableRow>[
        for (final MapEntry<String, double> e in byCur.entries)
          pw.TableRow(
            children: <pw.Widget>[
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(e.key),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(nf.format(e.value)),
              ),
            ],
          ),
        pw.TableRow(
          children: <pw.Widget>[
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('≈ TWD 合計'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(nf.format(twd)),
            ),
          ],
        ),
      ],
    );
  }

  // ── 產生 + 分享 ────────────────────────────────────────────

  List<JournalEntryRow> _applyScope(
    List<JournalEntryRow> entries,
    ExportScope scope,
    ({DateTime start, DateTime end})? range,
  ) {
    Iterable<JournalEntryRow> r = entries;
    switch (scope) {
      case ExportScope.expenseOnly:
        r = r.where((JournalEntryRow e) => e.entryType == EntryType.expense);
      case ExportScope.notesOnly:
        r = r.where((JournalEntryRow e) => e.entryType != EntryType.expense);
      case ExportScope.dateRange:
        if (range != null) {
          r = r.where((JournalEntryRow e) =>
              !e.createdAt.isBefore(range.start) &&
              !e.createdAt.isAfter(
                range.end.add(const Duration(days: 1)),
              ));
        }
      case ExportScope.all:
        break;
    }
    return r.toList();
  }

  Future<ExportResult> generate({
    required TripRow trip,
    required List<DayPlanRow> days,
    required List<JournalEntryRow> entries,
    required ExportScope scope,
    required Set<ExportFormat> formats,
    ({DateTime start, DateTime end})? range,
  }) async {
    final List<JournalEntryRow> filtered = _applyScope(entries, scope, range);
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory outDir = Directory(p.join(docs.path, 'exports'));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    final String stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final String base = trip.tourCode ?? 'trip';

    final List<String> paths = <String>[];
    bool pdfFontMissing = false;

    if (formats.contains(ExportFormat.csv)) {
      final String csv = buildExpenseCsv(filtered);
      final String path = p.join(outDir.path, '${base}_$stamp.csv');
      await File(path).writeAsString(csv);
      paths.add(path);
    }

    if (formats.contains(ExportFormat.pdf)) {
      try {
        final Uint8List bytes = await buildReportPdf(
          trip: trip,
          days: days,
          entries: filtered,
        );
        final String path = p.join(outDir.path, '${base}_$stamp.pdf');
        await File(path).writeAsBytes(bytes);
        paths.add(path);
      } on ExportFontMissingException {
        pdfFontMissing = true;
      }
    }

    return ExportResult(paths: paths, pdfFontMissing: pdfFontMissing);
  }

  Future<void> share(List<String> paths) async {
    if (paths.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(
        files: paths.map((String path) => XFile(path)).toList(),
      ),
    );
  }

  Future<List<String>> listHistory() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory outDir = Directory(p.join(docs.path, 'exports'));
    if (!outDir.existsSync()) return <String>[];
    return outDir.listSync().whereType<File>().map((File f) => f.path).toList()
      ..sort((String a, String b) => b.compareTo(a));
  }
}

final exportServiceProvider =
    Provider<ExportService>((Ref ref) => const ExportService());
