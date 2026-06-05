import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/enums.dart';
import '../../data/database/app_database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/export_service.dart';
import '../journal/journal_providers.dart';
import '../trip_home/trip_providers.dart';

/// 匯出選項（§5.9）：範圍、格式、產生、分享、歷史。
class JournalExportScreen extends ConsumerStatefulWidget {
  const JournalExportScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<JournalExportScreen> createState() =>
      _JournalExportScreenState();
}

class _JournalExportScreenState extends ConsumerState<JournalExportScreen> {
  ExportScope _scope = ExportScope.all;
  final Set<ExportFormat> _formats = <ExportFormat>{ExportFormat.csv};
  DateTimeRange? _range;
  bool _busy = false;
  List<String> _history = <String>[];

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  Future<void> _refreshHistory() async {
    final List<String> h = await ref.read(exportServiceProvider).listHistory();
    if (mounted) setState(() => _history = h);
  }

  Future<void> _generate() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_formats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportSelectFormat)),
      );
      return;
    }
    final TripRow? trip = ref.read(tripProvider(widget.tripId)).valueOrNull;
    final List<DayPlanRow> days =
        ref.read(tripDaysProvider(widget.tripId)).valueOrNull ?? <DayPlanRow>[];
    final List<JournalEntryRow> entries =
        ref.read(journalEntriesProvider(widget.tripId)).valueOrNull ??
            <JournalEntryRow>[];
    if (trip == null) return;

    setState(() => _busy = true);
    final ExportService svc = ref.read(exportServiceProvider);
    final ExportResult result = await svc.generate(
      trip: trip,
      days: days,
      entries: entries,
      scope: _scope,
      formats: _formats,
      range: _range == null ? null : (start: _range!.start, end: _range!.end),
    );
    if (result.paths.isNotEmpty) await svc.share(result.paths);
    await _refreshHistory();
    if (!mounted) return;
    setState(() => _busy = false);
    final String msg =
        result.pdfFontMissing ? l10n.exportFontMissing : l10n.exportDone;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportTitle)),
      body: ListView(
        children: <Widget>[
          _SectionTitle(text: l10n.exportTitle),
          RadioGroup<ExportScope>(
            groupValue: _scope,
            onChanged: (ExportScope? v) => setState(() => _scope = v ?? _scope),
            child: Column(
              children: <Widget>[
                RadioListTile<ExportScope>(
                  value: ExportScope.all,
                  title: Text(l10n.exportScopeAll),
                ),
                RadioListTile<ExportScope>(
                  value: ExportScope.expenseOnly,
                  title: Text(l10n.exportScopeExpense),
                ),
                RadioListTile<ExportScope>(
                  value: ExportScope.notesOnly,
                  title: Text(l10n.exportScopeNotes),
                ),
                RadioListTile<ExportScope>(
                  value: ExportScope.dateRange,
                  title: Text(l10n.exportScopeDateRange),
                  subtitle: _range == null
                      ? null
                      : Text('${_range!.start.toString().split(' ').first}'
                          ' ~ ${_range!.end.toString().split(' ').first}'),
                  secondary: IconButton(
                    icon: const Icon(Icons.date_range),
                    onPressed: () async {
                      final DateTimeRange? r = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (r != null) {
                        setState(() {
                          _range = r;
                          _scope = ExportScope.dateRange;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionTitle(text: l10n.exportFormatPdf.split('（').first),
          CheckboxListTile(
            value: _formats.contains(ExportFormat.pdf),
            title: Text(l10n.exportFormatPdf),
            onChanged: (bool? v) => setState(() {
              if (v ?? false) {
                _formats.add(ExportFormat.pdf);
              } else {
                _formats.remove(ExportFormat.pdf);
              }
            }),
          ),
          CheckboxListTile(
            value: _formats.contains(ExportFormat.csv),
            title: Text(l10n.exportFormatCsv),
            onChanged: (bool? v) => setState(() {
              if (v ?? false) {
                _formats.add(ExportFormat.csv);
              } else {
                _formats.remove(ExportFormat.csv);
              }
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              label: Text(_busy ? l10n.exportGenerating : l10n.exportGenerate),
            ),
          ),
          if (_history.isNotEmpty) ...<Widget>[
            const Divider(),
            _SectionTitle(text: l10n.exportHistory),
            for (final String path in _history)
              ListTile(
                leading: Icon(
                  path.endsWith('.pdf')
                      ? Icons.picture_as_pdf_outlined
                      : Icons.table_chart_outlined,
                ),
                title: Text(p.basename(path)),
                trailing: IconButton(
                  icon: const Icon(Icons.ios_share),
                  onPressed: () =>
                      ref.read(exportServiceProvider).share(<String>[path]),
                ),
                onTap: () =>
                    ref.read(exportServiceProvider).share(<String>[path]),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
