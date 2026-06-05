import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/secure_store.dart';

/// Claude API 錯誤分類，供 UI 對應降級流程（§8）。
enum ClaudeErrorKind { noApiKey, network, http, emptyResponse, parse }

class ClaudeApiException implements Exception {
  const ClaudeApiException(this.kind, [this.detail]);
  final ClaudeErrorKind kind;
  final String? detail;
  @override
  String toString() => 'ClaudeApiException($kind, $detail)';
}

/// 呼叫 Anthropic Messages API，把 PDF rawText 轉成 §4.3 的結構化 JSON。
/// 唯一需網路的環節。**絕不**硬編 key（由 SecureStore 取得）。
class ClaudeApiService {
  ClaudeApiService(this._secureStore, {http.Client? client})
      : _client = client ?? http.Client();

  final SecureStore _secureStore;
  final http.Client _client;

  /// 回傳解析後的 JSON Map（已去除 markdown 圍欄）。失敗丟 [ClaudeApiException]。
  Future<Map<String, dynamic>> structureItinerary(String rawText) async {
    final String? apiKey = await _secureStore.getClaudeApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const ClaudeApiException(ClaudeErrorKind.noApiKey);
    }
    final String model =
        await _secureStore.getClaudeModel() ?? AppConstants.defaultClaudeModel;

    final Map<String, Object?> body = <String, Object?>{
      'model': model,
      'max_tokens': AppConstants.claudeMaxTokens,
      'system': _systemPrompt,
      'messages': <Map<String, Object?>>[
        <String, Object?>{
          'role': 'user',
          'content': '以下是旅遊行程 PDF 抽出的純文字，請依規則輸出 JSON：\n\n$rawText',
        },
      ],
    };

    http.Response resp;
    try {
      resp = await _client.post(
        Uri.parse(AppConstants.claudeApiBase),
        headers: <String, String>{
          'content-type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': AppConstants.claudeApiVersion,
        },
        body: jsonEncode(body),
      );
    } on Object catch (e) {
      throw ClaudeApiException(ClaudeErrorKind.network, e.toString());
    }

    if (resp.statusCode != 200) {
      throw ClaudeApiException(
        ClaudeErrorKind.http,
        'HTTP ${resp.statusCode}: ${resp.body}',
      );
    }

    final String text = _extractText(resp.body);
    return _parseLenientJson(text);
  }

  /// 從 Anthropic 回應抽出第一個 text block。
  String _extractText(String responseBody) {
    try {
      final Object? decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final Object? content = decoded['content'];
        if (content is List) {
          for (final Object? block in content) {
            if (block is Map<String, dynamic> && block['type'] == 'text') {
              final Object? t = block['text'];
              if (t is String && t.trim().isNotEmpty) return t;
            }
          }
        }
      }
    } on Object catch (e) {
      throw ClaudeApiException(ClaudeErrorKind.parse, e.toString());
    }
    throw const ClaudeApiException(ClaudeErrorKind.emptyResponse);
  }

  /// 容錯解析：先 strip 可能的 ```json 圍欄與前後雜訊，再 jsonDecode。
  Map<String, dynamic> _parseLenientJson(String raw) {
    final String stripped = stripJsonFences(raw);
    try {
      final Object? decoded = jsonDecode(stripped);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const ClaudeApiException(
          ClaudeErrorKind.parse, 'not a JSON object');
    } on FormatException catch (e) {
      throw ClaudeApiException(ClaudeErrorKind.parse, e.message);
    }
  }

  /// 去除 ```json … ``` 圍欄，並擷取第一個 `{` 到最後一個 `}`。
  static String stripJsonFences(String input) {
    String s = input.trim();
    // 移除 ```json / ``` 圍欄
    s = s.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '');
    s = s.replaceAll(RegExp(r'\s*```$'), '');
    // 擷取最外層大括號範圍，丟棄前後說明文字
    final int start = s.indexOf('{');
    final int end = s.lastIndexOf('}');
    if (start >= 0 && end > start) {
      s = s.substring(start, end + 1);
    }
    return s.trim();
  }

  static const String _systemPrompt = '''
你是旅遊行程結構化引擎。輸入是團體旅遊行程 PDF 抽出的繁體中文純文字（半結構化、含表格與條列）。
請輸出**單一 JSON 物件**，嚴格遵守以下 schema，且：
- 只輸出 JSON，不要任何前後綴文字、不要 markdown 圍欄（不要 ```）。
- 找不到的欄位填 null，**不要捏造**。
- 日期格式 YYYY-MM-DD；含時間者 YYYY-MM-DDTHH:mm（24 小時制）。
- visit_type 僅能是 "enter"(入內參觀)/"photo"(下車拍照)/"drive_by"(行車經過)。
- info_sections.category 僅能是 notice/tipping/baggage/hotel/safety/customs/health/guide。
- spots.order_index 與 days.day_index 由 1 起算且連續。

JSON schema：
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
    {"day_index": 1, "flight_no": "string", "carrier": "string",
     "depart_time": "YYYY-MM-DDTHH:mm", "arrive_time": "YYYY-MM-DDTHH:mm",
     "from_airport": "string", "to_airport": "string"}
  ],
  "days": [
    {"day_index": 1, "date": "YYYY-MM-DD", "route_summary": "string",
     "hotel_name": "string|null", "hotel_name_en": "string|null", "hotel_phone": "string|null",
     "meal_breakfast": "string|null", "meal_lunch": "string|null", "meal_dinner": "string|null",
     "notes": "string|null",
     "spots": [
       {"order_index": 1, "name": "string", "visit_type": "enter|photo|drive_by",
        "description": "string|null", "refund_note": "string|null"}
     ]}
  ],
  "info_sections": [
    {"category": "notice|tipping|baggage|hotel|safety|customs|health|guide",
     "title": "string", "body": "string", "order_index": 1}
  ]
}
''';
}

final claudeApiServiceProvider = Provider<ClaudeApiService>((Ref ref) {
  return ClaudeApiService(ref.watch(secureStoreProvider));
});
