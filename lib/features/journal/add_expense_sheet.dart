import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/exchange_rate_repository.dart';
import '../../data/repositories/journal_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import 'expense_labels.dart';

/// 新增 / 編輯支出 bottom sheet（§5.8）。輸入金額即時顯示台幣換算預覽。
Future<void> showAddExpenseSheet(
  BuildContext context,
  WidgetRef ref,
  String tripId, {
  int? defaultDayIndex,
  JournalEntryRow? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _AddExpenseForm(
        tripId: tripId,
        defaultDayIndex: defaultDayIndex,
        existing: existing,
      ),
    ),
  );
}

class _AddExpenseForm extends ConsumerStatefulWidget {
  const _AddExpenseForm({
    required this.tripId,
    this.defaultDayIndex,
    this.existing,
  });
  final String tripId;
  final int? defaultDayIndex;
  final JournalEntryRow? existing;

  @override
  ConsumerState<_AddExpenseForm> createState() => _AddExpenseFormState();
}

class _AddExpenseFormState extends ConsumerState<_AddExpenseForm> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.existing?.amount?.toString() ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.existing?.entryText ?? '',
  );
  late String _currency = widget.existing?.currency ?? 'JPY';
  late ExpenseCategory _category =
      widget.existing?.expenseCategory ?? ExpenseCategory.food;
  late DateTime _date = widget.existing?.createdAt ?? DateTime.now();
  double? _rate; // 目前幣別→TWD 匯率（若有）
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRate();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadRate() async {
    if (_currency == 'TWD') {
      setState(() => _rate = 1);
      return;
    }
    final rate =
        await ref.read(exchangeRateRepositoryProvider).getRate(_currency);
    if (mounted) setState(() => _rate = rate?.rate);
  }

  double? get _twdPreview {
    final double? amt = double.tryParse(_amount.text);
    if (amt == null || _rate == null) return null;
    return amt * _rate!;
  }

  Future<void> _save() async {
    final double? amt = double.tryParse(_amount.text);
    if (amt == null || amt <= 0) return;
    setState(() => _saving = true);
    final double? twd = _rate == null ? null : amt * _rate!;
    final String? note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final JournalRepository repo = ref.read(journalRepositoryProvider);
    final JournalEntryRow? existing = widget.existing;
    if (existing != null) {
      await repo.updateEntry(
        existing.copyWith(
          amount: Value<double?>(amt),
          currency: Value<String?>(_currency),
          expenseCategory: Value<ExpenseCategory?>(_category),
          entryText: Value<String?>(note),
          amountTwd: Value<double?>(twd),
          exchangeRateUsed: Value<double?>(_rate),
          createdAt: _date,
        ),
      );
    } else {
      await repo.addExpense(
        widget.tripId,
        amount: amt,
        currency: _currency,
        category: _category,
        dayIndex: widget.defaultDayIndex,
        note: note,
        amountTwd: twd,
        rateUsed: _rate,
        date: _date,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double? preview = _twdPreview;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.addExpense, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(labelText: l10n.expenseAmount),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: InputDecoration(labelText: l10n.expenseCurrency),
                  items: <DropdownMenuItem<String>>[
                    for (final String c in AppConstants.commonCurrencies)
                      DropdownMenuItem<String>(value: c, child: Text(c)),
                  ],
                  onChanged: (String? v) {
                    if (v == null) return;
                    setState(() => _currency = v);
                    _loadRate();
                  },
                ),
              ),
            ],
          ),
          if (preview != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.expenseTotalConverted(preview.toStringAsFixed(0)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ExpenseCategory>(
            initialValue: _category,
            decoration: InputDecoration(labelText: l10n.expenseCategory),
            items: <DropdownMenuItem<ExpenseCategory>>[
              for (final ExpenseCategory c in ExpenseCategory.values)
                DropdownMenuItem<ExpenseCategory>(
                  value: c,
                  child: Text(expenseCategoryLabel(l10n, c)),
                ),
            ],
            onChanged: (ExpenseCategory? v) =>
                setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: l10n.expenseNote),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text('${l10n.expenseDate}: '
                    '${_date.year}/${_date.month}/${_date.day}'),
              ),
              TextButton(
                onPressed: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: Text(l10n.commonEdit),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}
