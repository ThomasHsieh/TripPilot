import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_pilot/core/secure_store.dart';
import 'package:trip_pilot/services/claude_api_service.dart';

/// 以覆寫 read 方法的方式提供假 key/model，避免觸發平台 secure storage。
class _FakeStore extends SecureStore {
  _FakeStore({this.key = 'sk-test'});
  final String? key;
  @override
  Future<String?> getClaudeApiKey() async => key;
  @override
  Future<String?> getClaudeModel() async => null;
}

http.Response _anthropic(String text) => http.Response(
      jsonEncode(<String, Object?>{
        'content': <Object?>[
          <String, Object?>{'type': 'text', 'text': text},
        ],
      }),
      200,
      headers: <String, String>{'content-type': 'application/json'},
    );

void main() {
  group('stripJsonFences', () {
    test('移除 ```json 圍欄', () {
      const String input = '```json\n{"a":1}\n```';
      expect(ClaudeApiService.stripJsonFences(input), '{"a":1}');
    });
    test('擷取前後雜訊中的 JSON', () {
      const String input = '這是結果：\n{"a":1}\n以上。';
      expect(ClaudeApiService.stripJsonFences(input), '{"a":1}');
    });
  });

  test('正常回應 → 解析 JSON（含圍欄）', () async {
    final MockClient client = MockClient((http.Request req) async {
      expect(req.headers['x-api-key'], 'sk-test');
      expect(req.headers['anthropic-version'], isNotEmpty);
      return _anthropic('```json\n{"tour_code":"NSC061306BR6"}\n```');
    });
    final ClaudeApiService svc = ClaudeApiService(_FakeStore(), client: client);

    final Map<String, dynamic> json = await svc.structureItinerary('raw text');
    expect(json['tour_code'], 'NSC061306BR6');
  });

  test('無 API key → noApiKey', () async {
    final ClaudeApiService svc = ClaudeApiService(
      _FakeStore(key: null),
      client: MockClient((_) async => _anthropic('{}')),
    );
    expect(
      () => svc.structureItinerary('x'),
      throwsA(
        isA<ClaudeApiException>().having(
          (ClaudeApiException e) => e.kind,
          'kind',
          ClaudeErrorKind.noApiKey,
        ),
      ),
    );
  });

  test('HTTP 401 → http 錯誤', () async {
    final ClaudeApiService svc = ClaudeApiService(
      _FakeStore(),
      client: MockClient((_) async => http.Response('unauthorized', 401)),
    );
    expect(
      () => svc.structureItinerary('x'),
      throwsA(
        isA<ClaudeApiException>().having(
          (ClaudeApiException e) => e.kind,
          'kind',
          ClaudeErrorKind.http,
        ),
      ),
    );
  });

  test('回應非 JSON → parse 錯誤', () async {
    final ClaudeApiService svc = ClaudeApiService(
      _FakeStore(),
      client: MockClient((_) async => _anthropic('抱歉我無法處理')),
    );
    expect(
      () => svc.structureItinerary('x'),
      throwsA(
        isA<ClaudeApiException>().having(
          (ClaudeApiException e) => e.kind,
          'kind',
          ClaudeErrorKind.parse,
        ),
      ),
    );
  });
}
