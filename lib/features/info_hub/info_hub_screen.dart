import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/enums.dart';
import '../../data/database/app_database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../trip_home/trip_providers.dart';
import '../trip_home/widgets/trip_scaffold.dart';
import 'info_labels.dart';

/// 注意事項 / 須知知識庫：依 category 分頁籤 + 全文檢索（§5.4）。
class InfoHubScreen extends ConsumerStatefulWidget {
  const InfoHubScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<InfoHubScreen> createState() => _InfoHubScreenState();
}

class _InfoHubScreenState extends ConsumerState<InfoHubScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<InfoSectionRow>> sections =
        ref.watch(tripInfoSectionsProvider(widget.tripId));

    return TripScaffold(
      tripId: widget.tripId,
      currentTab: TripTab.info,
      title: l10n.infoHubTitle,
      body: sections.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (List<InfoSectionRow> list) => Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SearchBar(
                hintText: l10n.infoSearchHint,
                leading: const Icon(Icons.search),
                onChanged: (String v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty
                  ? _CategoryTabs(sections: list)
                  : _FilteredList(sections: list, query: _query.trim()),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.sections});
  final List<InfoSectionRow> sections;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // 依 enum 順序取出有內容的分類。
    final Map<InfoCategory, List<InfoSectionRow>> grouped =
        <InfoCategory, List<InfoSectionRow>>{};
    for (final InfoCategory c in InfoCategory.values) {
      final List<InfoSectionRow> items =
          sections.where((InfoSectionRow s) => s.category == c).toList();
      if (items.isNotEmpty) grouped[c] = items;
    }
    if (grouped.isEmpty) {
      return Center(child: Text(l10n.searchNoResult));
    }
    final List<InfoCategory> cats = grouped.keys.toList();

    return DefaultTabController(
      length: cats.length,
      child: Column(
        children: <Widget>[
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              for (final InfoCategory c in cats)
                Tab(text: infoCategoryLabel(l10n, c)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                for (final InfoCategory c in cats)
                  ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: <Widget>[
                      for (final InfoSectionRow s in grouped[c]!)
                        _InfoCard(section: s),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilteredList extends StatelessWidget {
  const _FilteredList({required this.sections, required this.query});
  final List<InfoSectionRow> sections;
  final String query;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String q = query.toLowerCase();
    final List<InfoSectionRow> hits = sections
        .where(
          (InfoSectionRow s) =>
              s.title.toLowerCase().contains(q) ||
              s.body.toLowerCase().contains(q),
        )
        .toList();
    if (hits.isEmpty) {
      return Center(child: Text(l10n.searchNoResult));
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
        for (final InfoSectionRow s in hits) _InfoCard(section: s),
      ],
    );
  }
}

/// 非摺疊、完整可捲動的須知卡片：標題 + 內文（標題已等同分類，故不再重覆顯示分類）。
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.section});
  final InfoSectionRow section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              section.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(
              section.body,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
