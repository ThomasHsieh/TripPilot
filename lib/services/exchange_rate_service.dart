import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';

class ExchangeRateException implements Exception {
  const ExchangeRateException([this.detail]);
  final String? detail;
  @override
  String toString() => 'ExchangeRateException($detail)';
}

/// 線上匯率拉取（規格 §8a.1）。主用 Frankfurter，失敗降級 open.er-api。
/// 注意：Frankfurter 為 ECB 來源、不含 TWD，故 base→TWD 實際多由 er-api 提供。
class ExchangeRateService {
  ExchangeRateService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// 取得 1 [base] = ? [quote] 的匯率。兩來源皆失敗則丟 [ExchangeRateException]。
  Future<double> fetchRate(
    String base, {
    String quote = AppConstants.quoteCurrency,
  }) async {
    // open.er-api 涵蓋 TWD，作為主來源；Frankfurter（ECB，不含 TWD）為備援。
    final double? erApi = await _tryErApi(base, quote);
    if (erApi != null) return erApi;
    final double? frankfurter = await _tryFrankfurter(base, quote);
    if (frankfurter != null) return frankfurter;
    throw const ExchangeRateException('all providers failed');
  }

  Future<double?> _tryFrankfurter(String base, String quote) async {
    try {
      final Uri uri = Uri.parse(
        '${AppConstants.frankfurterBase}?base=$base&symbols=$quote',
      );
      final http.Response r = await _client.get(uri);
      if (r.statusCode != 200) return null;
      final Object? json = jsonDecode(r.body);
      if (json is Map<String, dynamic>) {
        final Object? rates = json['rates'];
        if (rates is Map<String, dynamic>) {
          final Object? v = rates[quote];
          if (v is num) return v.toDouble();
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  Future<double?> _tryErApi(String base, String quote) async {
    try {
      final Uri uri = Uri.parse('${AppConstants.erApiBase}/$base');
      final http.Response r = await _client.get(uri);
      if (r.statusCode != 200) return null;
      final Object? json = jsonDecode(r.body);
      if (json is Map<String, dynamic>) {
        final Object? rates = json['rates'];
        if (rates is Map<String, dynamic>) {
          final Object? v = rates[quote];
          if (v is num) return v.toDouble();
        }
      }
    } on Object {
      return null;
    }
    return null;
  }
}

final exchangeRateServiceProvider =
    Provider<ExchangeRateService>((Ref ref) => ExchangeRateService());
