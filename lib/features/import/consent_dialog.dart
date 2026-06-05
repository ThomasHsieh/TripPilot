import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/secure_store.dart';
import '../../l10n/generated/app_localizations.dart';

/// 確保已取得「PDF 抽出文字上傳 Claude API」的同意（§7.3）。
/// 若先前已記住同意 → 直接回 true；否則跳對話框，可選擇記住。
/// 回傳 true 表示同意可繼續解析；false 表示拒絕（改走手動建立）。
Future<bool> ensurePdfUploadConsent(
  BuildContext context,
  WidgetRef ref,
) async {
  final SecureStore store = ref.read(secureStoreProvider);
  if (await store.getPdfUploadConsent()) return true;
  if (!context.mounted) return false;

  final bool? agreed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => const _ConsentDialog(),
  );
  if (agreed != true) return false;
  return true;
}

class _ConsentDialog extends StatefulWidget {
  const _ConsentDialog();

  @override
  State<_ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<_ConsentDialog> {
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) {
        return AlertDialog(
          title: Text(l10n.privacyConsentTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.privacyConsentBody),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _remember,
                onChanged: (bool? v) => setState(() => _remember = v ?? false),
                title: Text(l10n.privacyConsentRemember),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.privacyDecline),
            ),
            FilledButton(
              onPressed: () async {
                if (_remember) {
                  await ref.read(secureStoreProvider).setPdfUploadConsent(true);
                }
                if (context.mounted) Navigator.of(context).pop(true);
              },
              child: Text(l10n.privacyAgree),
            ),
          ],
        );
      },
    );
  }
}
