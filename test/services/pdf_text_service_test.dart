import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_pilot/services/pdf_text_service.dart';

/// M2 驗證：以範例 PDF（NSC061306BR6）確認 Syncfusion 抽取中文文字正確。
void main() {
  const PdfTextService service = PdfTextService();

  test('範例 PDF 抽出關鍵欄位文字', () async {
    final bytes = await File('docs/NSC061306BR6.pdf').readAsBytes();
    final PdfExtractResult result = await service.extractFromBytes(bytes);

    expect(result.pageCount, greaterThanOrEqualTo(6));
    expect(result.rawText, contains('NSC061306BR6')); // 團號
    expect(result.rawText, contains('BR122')); // Day1 去程航班
    expect(result.rawText, contains('BR121')); // Day6 回程航班
    expect(result.rawText, contains('十和田莊')); // Day1 飯店（NFKC 還原康熙部首）
    expect(result.rawText, contains('0922339061')); // 領隊國內電話
    expect(result.rawText, contains('奧入瀨')); // 景點
    expect(result.rawText, contains('平泉中尊寺')); // Day4 景點（§9.3）
    expect(result.rawText, contains('鋰電池')); // 須知關鍵字（§9.3 搜尋）
    expect(result.rawText, contains('退稅')); // 須知關鍵字（§9.3 搜尋）
  });

  test('NFKC 還原康熙部首相容字', () async {
    final bytes = await File('docs/NSC061306BR6.pdf').readAsBytes();
    final PdfExtractResult result = await service.extractFromBytes(bytes);
    // 抽取後不應再出現康熙部首區（U+2F00–U+2FDF）的字元。
    final bool hasKangxiRadical =
        result.rawText.runes.any((int r) => r >= 0x2F00 && r <= 0x2FDF);
    expect(hasKangxiRadical, isFalse);
  });
}
