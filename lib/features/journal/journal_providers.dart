import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/journal_repository.dart';

/// 行程的所有札記/相片/支出記錄（依建立時間新→舊）。
final journalEntriesProvider =
    StreamProvider.family<List<JournalEntryRow>, String>((Ref ref, String id) {
  return ref.watch(journalRepositoryProvider).watchEntries(id);
});

/// 依幣別分組的支出原始加總（從串流資料即時計算）。
Map<String, double> sumExpensesByCurrency(List<JournalEntryRow> entries) {
  final Map<String, double> out = <String, double>{};
  for (final JournalEntryRow e in entries) {
    if (e.entryType != EntryType.expense) continue;
    final String cur = e.currency ?? 'JPY';
    out.update(
      cur,
      (double v) => v + (e.amount ?? 0),
      ifAbsent: () => e.amount ?? 0,
    );
  }
  return out;
}

/// 已換算台幣合計與是否全部換算（供 §5.8 加總列使用）。
({double twd, bool allConverted}) convertedTwdTotal(
  List<JournalEntryRow> entries,
) {
  double twd = 0;
  bool all = true;
  for (final JournalEntryRow e in entries) {
    if (e.entryType != EntryType.expense) continue;
    final String cur = e.currency ?? 'JPY';
    if (cur == 'TWD') {
      twd += e.amount ?? 0;
    } else if (e.amountTwd != null) {
      twd += e.amountTwd!;
    } else {
      all = false;
    }
  }
  return (twd: twd, allConverted: all);
}
