import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/parsed_trip.dart';
import '../../services/claude_api_service.dart';
import '../../services/pdf_text_service.dart';
import 'trip_json_mapper.dart';

/// 匯入流程狀態（M2 選檔/抽文字 → M3 同意/Claude 解析 → 預覽）。
sealed class ImportState {
  const ImportState();
}

class ImportIdle extends ImportState {
  const ImportIdle();
}

class ImportExtracting extends ImportState {
  const ImportExtracting(this.fileName);
  final String fileName;
}

class ImportExtracted extends ImportState {
  const ImportExtracted({
    required this.rawText,
    required this.pageCount,
    required this.fileName,
    this.sourcePath,
  });
  final String rawText;
  final int pageCount;
  final String fileName;
  final String? sourcePath;
}

class ImportParsing extends ImportState {
  const ImportParsing();
}

class ImportParsed extends ImportState {
  const ImportParsed({required this.trip, required this.warnings});
  final ParsedTrip trip;
  final List<TripWarning> warnings;
}

enum ImportErrorKind {
  imageOnly,
  readError,
  noApiKey,
  network,
  parseError,
  generic;

  /// 解析階段錯誤（重試＝重新呼叫 Claude）；否則為抽取階段（重試＝重新選檔）。
  bool get isParseStage =>
      this == noApiKey || this == network || this == parseError;
}

class ImportFailure extends ImportState {
  const ImportFailure(this.kind);
  final ImportErrorKind kind;
}

class ImportController extends Notifier<ImportState> {
  ImportExtracted? _extracted;

  @override
  ImportState build() => const ImportIdle();

  PdfTextService get _pdf => ref.read(pdfTextServiceProvider);
  ClaudeApiService get _claude => ref.read(claudeApiServiceProvider);

  /// 開啟系統選檔，挑選 PDF 後抽取文字。使用者取消則維持原狀態。
  Future<void> pickAndExtract() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['pdf'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final PlatformFile file = picked.files.single;
    await _extract(fileName: file.name, bytes: file.bytes, path: file.path);
  }

  Future<void> _extract({
    required String fileName,
    Uint8List? bytes,
    String? path,
  }) async {
    state = ImportExtracting(fileName);
    try {
      final PdfExtractResult result = bytes != null
          ? await _pdf.extractFromBytes(bytes)
          : await _pdf.extractFromFile(path!);
      _extracted = ImportExtracted(
        rawText: result.rawText,
        pageCount: result.pageCount,
        fileName: fileName,
        sourcePath: path,
      );
      state = _extracted!;
    } on PdfImageOnlyException {
      state = const ImportFailure(ImportErrorKind.imageOnly);
    } on PdfReadException {
      state = const ImportFailure(ImportErrorKind.readError);
    } on Object catch (e) {
      debugPrint('Import extract failed: $e');
      state = const ImportFailure(ImportErrorKind.generic);
    }
  }

  /// 以 Claude 解析目前已抽取的 rawText（呼叫前 UI 應已取得隱私同意 §7.3）。
  Future<void> parseCurrent() async {
    final ImportExtracted? extracted = _extracted;
    if (extracted == null) return;

    state = const ImportParsing();
    try {
      final Map<String, dynamic> json =
          await _claude.structureItinerary(extracted.rawText);
      final ParsedTrip trip = mapClaudeJson(
        json,
        sourcePdfPath: extracted.sourcePath,
        rawJson: jsonEncode(json),
      );
      state = ImportParsed(trip: trip, warnings: validateParsedTrip(trip));
    } on ClaudeApiException catch (e) {
      final ImportErrorKind kind = switch (e.kind) {
        ClaudeErrorKind.noApiKey => ImportErrorKind.noApiKey,
        ClaudeErrorKind.network => ImportErrorKind.network,
        _ => ImportErrorKind.parseError,
      };
      state = ImportFailure(kind);
    } on Object catch (e) {
      debugPrint('Claude parse failed: $e');
      state = const ImportFailure(ImportErrorKind.parseError);
    }
  }

  /// 解析失敗後返回已抽取畫面（供重試或改手動）。
  void backToExtracted() {
    if (_extracted != null) state = _extracted!;
  }

  void reset() {
    _extracted = null;
    state = const ImportIdle();
  }
}

final importControllerProvider =
    NotifierProvider<ImportController, ImportState>(ImportController.new);
