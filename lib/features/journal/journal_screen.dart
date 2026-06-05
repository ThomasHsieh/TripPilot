import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../core/enums.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/journal_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../trip_home/trip_providers.dart';
import '../trip_home/widgets/trip_scaffold.dart';
import 'add_expense_sheet.dart';
import 'add_note_sheet.dart';
import 'expense_labels.dart';
import 'journal_providers.dart';
import 'photo_viewer.dart';

/// 旅遊札記 / 支出 / 相片牆（§5.5）。三類記錄分頁，支出頁底部即時加總。
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  int? get _defaultDay {
    final TripRow? trip = ref.read(tripProvider(widget.tripId)).valueOrNull;
    return trip == null ? null : activeDayIndex(trip);
  }

  Widget? _fab() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    switch (_tab.index) {
      case 1:
        return FloatingActionButton.extended(
          onPressed: () => showAddExpenseSheet(context, ref, widget.tripId,
              defaultDayIndex: _defaultDay),
          icon: const Icon(Icons.add),
          label: Text(l10n.addExpense),
        );
      default:
        return FloatingActionButton.extended(
          onPressed: () => showAddNoteSheet(context, ref, widget.tripId,
              defaultDayIndex: _defaultDay),
          icon: const Icon(Icons.add),
          label: Text(l10n.addNote),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<JournalEntryRow>> entries =
        ref.watch(journalEntriesProvider(widget.tripId));

    return TripScaffold(
      tripId: widget.tripId,
      currentTab: TripTab.journal,
      title: l10n.journalTitle,
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.ios_share_outlined),
          tooltip: l10n.exportTitle,
          onPressed: () => context.push(AppRoutes.journalExport(widget.tripId)),
        ),
      ],
      floatingActionButton: _fab(),
      body: Column(
        children: <Widget>[
          TabBar(
            controller: _tab,
            tabs: <Widget>[
              Tab(text: l10n.journalTabNotes),
              Tab(text: l10n.journalTabExpense),
              Tab(text: l10n.journalTabPhotos),
            ],
          ),
          Expanded(
            child: entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, _) => Center(child: Text('$e')),
              data: (List<JournalEntryRow> list) => TabBarView(
                controller: _tab,
                children: <Widget>[
                  _NotesTab(entries: list, tripId: widget.tripId),
                  _ExpenseTab(entries: list, tripId: widget.tripId),
                  _PhotosTab(entries: list),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 確認刪除後刪除一筆記錄。
Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      content: Text(l10n.commonDelete),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.commonDelete),
        ),
      ],
    ),
  );
  if (ok ?? false) {
    await ref.read(journalRepositoryProvider).deleteEntry(id);
  }
}

class _EntryMenu extends ConsumerWidget {
  const _EntryMenu({required this.onEdit, required this.entryId});
  final VoidCallback onEdit;
  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      onSelected: (String v) {
        if (v == 'edit') {
          onEdit();
        } else {
          _confirmDelete(context, ref, entryId);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'edit', child: Text(l10n.commonEdit)),
        PopupMenuItem<String>(value: 'delete', child: Text(l10n.commonDelete)),
      ],
    );
  }
}

class _NotesTab extends ConsumerWidget {
  const _NotesTab({required this.entries, required this.tripId});
  final List<JournalEntryRow> entries;
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<JournalEntryRow> notes = entries
        .where((JournalEntryRow e) => e.entryType != EntryType.expense)
        .toList();
    if (notes.isEmpty) return Center(child: Text(l10n.journalEmptyNotes));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notes.length,
      itemBuilder: (BuildContext context, int i) {
        final JournalEntryRow e = notes[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        DateFormat('MM/dd HH:mm').format(e.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    _EntryMenu(
                      entryId: e.id,
                      onEdit: () => showAddNoteSheet(
                        context,
                        ref,
                        tripId,
                        existing: e,
                      ),
                    ),
                  ],
                ),
                if (e.entryText != null && e.entryText!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(e.entryText!),
                  ),
                if (e.photoPaths.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (int pi = 0; pi < e.photoPaths.length; pi++)
                        _Thumb(
                          path: e.photoPaths[pi],
                          onTap: () =>
                              showPhotoViewer(context, e.photoPaths, pi),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExpenseTab extends ConsumerWidget {
  const _ExpenseTab({required this.entries, required this.tripId});
  final List<JournalEntryRow> entries;
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<JournalEntryRow> expenses = entries
        .where((JournalEntryRow e) => e.entryType == EntryType.expense)
        .toList();
    final Map<String, double> byCur = sumExpensesByCurrency(entries);
    final ({double twd, bool allConverted}) conv = convertedTwdTotal(entries);
    final NumberFormat nf = NumberFormat('#,##0');

    return Column(
      children: <Widget>[
        Expanded(
          child: expenses.isEmpty
              ? Center(child: Text(l10n.journalEmptyExpense))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: expenses.length,
                  itemBuilder: (BuildContext context, int i) {
                    final JournalEntryRow e = expenses[i];
                    return ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: Text(
                        '${e.currency ?? ''} ${nf.format(e.amount ?? 0)}',
                      ),
                      subtitle: Text(
                        <String>[
                          if (e.expenseCategory != null)
                            expenseCategoryLabel(l10n, e.expenseCategory!),
                          if (e.entryText != null && e.entryText!.isNotEmpty)
                            e.entryText!,
                        ].join(' · '),
                      ),
                      onTap: () => showAddExpenseSheet(
                        context,
                        ref,
                        tripId,
                        existing: e,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (e.amountTwd != null)
                            Text('≈ ${nf.format(e.amountTwd!)} TWD'),
                          _EntryMenu(
                            entryId: e.id,
                            onEdit: () => showAddExpenseSheet(
                              context,
                              ref,
                              tripId,
                              existing: e,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (byCur.isNotEmpty) _TotalsBar(byCurrency: byCur, conv: conv, nf: nf),
      ],
    );
  }
}

class _TotalsBar extends StatelessWidget {
  const _TotalsBar({
    required this.byCurrency,
    required this.conv,
    required this.nf,
  });
  final Map<String, double> byCurrency;
  final ({double twd, bool allConverted}) conv;
  final NumberFormat nf;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Material(
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          // 右側留白避開右下角的「新增支出」FAB。
          padding: const EdgeInsets.fromLTRB(16, 10, 88, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Wrap(
                spacing: 16,
                children: <Widget>[
                  for (final MapEntry<String, double> e in byCurrency.entries)
                    Text('${e.key} ${nf.format(e.value)}',
                        style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              if (conv.twd > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${l10n.expenseTotalConverted(nf.format(conv.twd))}'
                    '${conv.allConverted ? '' : ' *'}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push(AppRoutes.exchangeRates),
                  icon: const Icon(Icons.currency_exchange, size: 18),
                  label: Text(l10n.updateRate),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotosTab extends StatelessWidget {
  const _PhotosTab({required this.entries});
  final List<JournalEntryRow> entries;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<String> photos = <String>[
      for (final JournalEntryRow e in entries) ...e.photoPaths,
    ];
    if (photos.isEmpty) return Center(child: Text(l10n.journalEmptyPhotos));
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (BuildContext context, int i) => _Thumb(
        path: photos[i],
        fill: true,
        onTap: () => showPhotoViewer(context, photos, i),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.path, this.onTap, this.fill = false});
  final String path;
  final VoidCallback? onTap;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final Widget img = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(path),
        width: fill ? null : 80,
        height: fill ? null : 80,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: fill ? null : 80,
          height: fill ? null : 80,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
    return GestureDetector(onTap: onTap, child: img);
  }
}
