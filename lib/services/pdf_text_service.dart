import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// 裝置端 PDF 純文字抽取（規格 §2.1 / M2）。只在本地處理，不涉網路。
class PdfTextService {
  const PdfTextService();

  /// 逐頁抽取文字並合併為 rawText。
  /// 若 PDF 為純圖檔（抽不到文字）→ 丟 [PdfImageOnlyException]（§8 降級提示）。
  Future<PdfExtractResult> extractFromBytes(Uint8List bytes) async {
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
    } on Object catch (e) {
      throw PdfReadException(e.toString());
    }

    try {
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final int pageCount = document.pages.count;
      final StringBuffer buffer = StringBuffer();

      for (int i = 0; i < pageCount; i++) {
        final String pageText =
            extractor.extractText(startPageIndex: i, endPageIndex: i);
        if (pageText.trim().isNotEmpty) {
          buffer
            ..writeln(pageText.trim())
            ..writeln();
        }
      }

      // NFKC 正規化：部分 PDF 將中文字編為康熙部首相容字（⼗ U+2F17 等），
      // NFKC 會還原為標準漢字（十 U+5341），確保搜尋／AI 解析一致。
      final String raw = unorm.nfkc(buffer.toString()).trim();
      // 去除所有空白後仍為空 → 視為圖片型 PDF。
      if (raw.replaceAll(RegExp(r'\s'), '').isEmpty) {
        throw const PdfImageOnlyException();
      }
      return PdfExtractResult(rawText: raw, pageCount: pageCount);
    } finally {
      document.dispose();
    }
  }

  /// 以本地檔案路徑抽取（行動平台 file_picker 回傳 path 時使用）。
  Future<PdfExtractResult> extractFromFile(String path) async {
    final Uint8List bytes = await File(path).readAsBytes();
    return extractFromBytes(bytes);
  }
}

/// 抽取結果。
class PdfExtractResult {
  const PdfExtractResult({required this.rawText, required this.pageCount});
  final String rawText;
  final int pageCount;
}

/// PDF 無法讀取（損毀／加密）。
class PdfReadException implements Exception {
  const PdfReadException(this.detail);
  final String detail;
  @override
  String toString() => 'PdfReadException: $detail';
}

/// PDF 為純圖檔，抽不到可選取文字。
class PdfImageOnlyException implements Exception {
  const PdfImageOnlyException();
  @override
  String toString() => 'PdfImageOnlyException';
}

final pdfTextServiceProvider =
    Provider<PdfTextService>((Ref ref) => const PdfTextService());
