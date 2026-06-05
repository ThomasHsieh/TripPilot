import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/enums.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/exchange_rate_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import 'exchange_rate_controller.dart';

final allExchangeRatesProvider =
    StreamProvider<List<ExchangeRateRow>>((Ref ref) {
  return ref.watch(exchangeRateRepositoryProvider).watchRates();
});

/// 匯率查詢與手動管理（§5.8 ExchangeRateScreen）。
class ExchangeRateScreen extends ConsumerWidget {
  const ExchangeRateScreen({super.key});

  Future<void> _syncAll(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int n = await ref.read(exchangeRateControllerProvider).syncAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exchangeRateSynced(n))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<ExchangeRateRow>> rates =
        ref.watch(allExchangeRatesProvider);
    final DateFormat df = DateFormat('yyyy/MM/dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.exchangeRateTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: l10n.exchangeRateSyncAll,
            onPressed: () => _syncAll(context, ref),
          ),
        ],
      ),
      body: rates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (List<ExchangeRateRow> list) {
          if (list.isEmpty) {
            return Center(child: Text(l10n.exchangeRateEmpty));
          }
          return ListView(
            children: <Widget>[
              for (final ExchangeRateRow r in list) _RateTile(row: r, df: df),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.exchangeRateAdd),
      ),
    );
  }
}

class _RateTile extends ConsumerWidget {
  const _RateTile({required this.row, required this.df});
  final ExchangeRateRow row;
  final DateFormat df;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool stale = ExchangeRateRepository.isStale(row);
    final String source = row.source == RateSource.api
        ? l10n.exchangeRateSourceApi
        : l10n.exchangeRateSourceManual;

    return Card(
      child: ListTile(
        title: Text(
          l10n.exchangeRateLine(row.baseCurrency, row.rate.toString()),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.exchangeRateUpdatedAt(df.format(row.fetchedAt), source)),
            if (stale)
              Text(
                l10n.rateStale(
                  DateTime.now().difference(row.fetchedAt).inHours,
                ),
                style: TextStyle(color: Colors.orange.shade800),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showRateDialog(context, ref, existing: row),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  ref.read(exchangeRateControllerProvider).deleteRate(row.id),
            ),
          ],
        ),
      ),
    );
  }
}

/// 新增 / 編輯匯率對。可線上取得或手動輸入（§8a.1/§8a.2）。
Future<void> showRateDialog(
  BuildContext context,
  WidgetRef ref, {
  ExchangeRateRow? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => _RateDialog(existing: existing),
  );
}

class _RateDialog extends ConsumerStatefulWidget {
  const _RateDialog({this.existing});
  final ExchangeRateRow? existing;

  @override
  ConsumerState<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends ConsumerState<_RateDialog> {
  late final TextEditingController _base = TextEditingController(
    text: widget.existing?.baseCurrency ?? 'JPY',
  );
  late final TextEditingController _rate = TextEditingController(
    text: widget.existing?.rate.toString() ?? '',
  );
  bool _busy = false;

  @override
  void dispose() {
    _base.dispose();
    _rate.dispose();
    super.dispose();
  }

  String get _baseCode => _base.text.trim().toUpperCase();

  Future<void> _fetchOnline() async {
    if (_baseCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).exchangeRateBaseLabel),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final bool ok =
        await ref.read(exchangeRateControllerProvider).sync(_baseCode);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).exchangeRateFetchFailed),
        ),
      );
    }
  }

  Future<void> _saveManual() async {
    final double? rate = double.tryParse(_rate.text.trim());
    if (_baseCode.isEmpty || rate == null || rate <= 0) return;
    setState(() => _busy = true);
    await ref.read(exchangeRateControllerProvider).setManual(_baseCode, rate);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isNew = widget.existing == null;
    return AlertDialog(
      title: Text(isNew ? l10n.exchangeRateAdd : l10n.commonEdit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _base,
            enabled: isNew,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: l10n.exchangeRateBaseLabel),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: l10n.exchangeRateRateLabel(
                _baseCode.isEmpty ? 'JPY' : _baseCode,
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: _busy ? null : _fetchOnline,
          child: Text(l10n.exchangeRateOnlineFetch),
        ),
        FilledButton(
          onPressed: _busy ? null : _saveManual,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
