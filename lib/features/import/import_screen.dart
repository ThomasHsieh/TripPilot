import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../l10n/generated/app_localizations.dart';
import 'consent_dialog.dart';
import 'import_controller.dart';
import 'import_preview_controller.dart';

/// 選 PDF → 抽取文字（M2）→ 隱私同意 → Claude 解析 → 進入預覽（M3）。
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  Future<void> _onParse(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool consented = await ensurePdfUploadConsent(context, ref);
    if (!consented) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.createManually)),
        );
      }
      return;
    }
    await ref.read(importControllerProvider.notifier).parseCurrent();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ImportController controller =
        ref.read(importControllerProvider.notifier);

    // 解析完成 → 灌入預覽控制器並導向預覽頁。
    ref.listen<ImportState>(importControllerProvider, (_, ImportState next) {
      if (next is ImportParsed) {
        ref
            .read(previewControllerProvider.notifier)
            .seed(next.trip, next.warnings);
        context.go(AppRoutes.importPreview);
      }
    });

    final ImportState state = ref.watch(importControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importTitle)),
      body: switch (state) {
        ImportIdle() => _IdleView(onPick: controller.pickAndExtract),
        ImportExtracting(:final String fileName) =>
          _BusyView(label: l10n.importExtracting, detail: fileName),
        ImportParsing() => _BusyView(label: l10n.importParsing),
        ImportExtracted() => _ExtractedView(
            state: state,
            onReselect: controller.pickAndExtract,
            onParse: () => _onParse(context, ref),
          ),
        // ImportParsed 已由 ref.listen 導向預覽，這裡短暫顯示 busy。
        ImportParsed() => _BusyView(label: l10n.importParsing),
        ImportFailure(:final ImportErrorKind kind) => _FailureView(
            kind: kind,
            onRetry: kind.isParseStage
                ? () => _onParse(context, ref)
                : controller.pickAndExtract,
          ),
      },
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.onPick});
  final Future<void> Function() onPick;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.file_open_outlined),
              label: Text(l10n.importPickFile),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusyView extends StatelessWidget {
  const _BusyView({required this.label, this.detail});
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(label),
          if (detail != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(detail!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _ExtractedView extends StatelessWidget {
  const _ExtractedView({
    required this.state,
    required this.onReselect,
    required this.onParse,
  });
  final ImportExtracted state;
  final Future<void> Function() onReselect;
  final Future<void> Function() onParse;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.importRawTextTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${state.fileName} · ${l10n.importExtractedSummary(state.pageCount, state.rawText.length)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                state.rawText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReselect,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.importReselect),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onParse,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(l10n.importParseButton),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FailureView extends ConsumerWidget {
  const _FailureView({required this.kind, required this.onRetry});
  final ImportErrorKind kind;
  final Future<void> Function() onRetry;

  String _message(AppLocalizations l10n) => switch (kind) {
        ImportErrorKind.imageOnly => l10n.errorPdfImageOnly,
        ImportErrorKind.readError => l10n.errorPdfRead,
        ImportErrorKind.noApiKey => l10n.errorNoApiKey,
        ImportErrorKind.network => l10n.errorNoNetwork,
        ImportErrorKind.parseError => l10n.errorParseFailed,
        ImportErrorKind.generic => l10n.errorGeneric,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _message(l10n),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            if (kind == ImportErrorKind.noApiKey)
              OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.settings),
                icon: const Icon(Icons.settings_outlined),
                label: Text(l10n.importGoSettings),
              )
            else
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.commonRetry),
              ),
          ],
        ),
      ),
    );
  }
}
