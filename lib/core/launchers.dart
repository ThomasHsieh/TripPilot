import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/generated/app_localizations.dart';

/// 撥號 / 地圖外開的共用輔助。無對應 app 時降級為複製到剪貼簿（§8）。
class Launchers {
  Launchers._();

  /// 一鍵撥號。電話僅保留數字與 +。
  static Future<void> dial(BuildContext context, String rawPhone) async {
    final String phone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri uri = Uri(scheme: 'tel', path: phone);
    await _launchOrCopy(context, uri, rawPhone);
  }

  /// 以名稱（含英文名）開啟系統地圖搜尋。
  static Future<void> openMap(BuildContext context, String query) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    await _launchOrCopy(context, uri, query);
  }

  static Future<void> _launchOrCopy(
    BuildContext context,
    Uri uri,
    String fallbackText,
  ) async {
    try {
      final bool ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (ok) return;
    } on Object {
      // 落入下方複製降級
    }
    if (!context.mounted) return;
    await Clipboard.setData(ClipboardData(text: fallbackText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).copiedToClipboard)),
    );
  }
}
