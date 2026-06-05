import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/search_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../info_hub/info_labels.dart';
import '../trip_home/widgets/trip_scaffold.dart';

/// 搜尋鍵：行程 + 查詢字。
typedef SearchKey = ({String tripId, String query});

final searchResultsProvider =
    FutureProvider.family<SearchResults, SearchKey>((Ref ref, SearchKey key) {
  if (key.query.trim().isEmpty) return const SearchResults();
  return ref.watch(searchRepositoryProvider).search(key.tripId, key.query);
});

/// 全行程全文檢索（Spot / DayPlan / InfoSection，FTS5）。結果分三類（§5.6）。
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<SearchResults> results = ref.watch(
      searchResultsProvider((tripId: widget.tripId, query: _query)),
    );

    return TripScaffold(
      tripId: widget.tripId,
      currentTab: TripTab.search,
      title: l10n.searchTitle,
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              hintText: l10n.searchHint,
              leading: const Icon(Icons.search),
              onChanged: _onChanged,
            ),
          ),
          Expanded(
            child: _query.trim().isEmpty
                ? const SizedBox.shrink()
                : results.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (Object e, _) => Center(child: Text('$e')),
                    data: (SearchResults r) =>
                        _ResultsList(tripId: widget.tripId, results: r),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.tripId, required this.results});
  final String tripId;
  final SearchResults results;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (results.isEmpty) {
      return Center(child: Text(l10n.searchNoResult));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: <Widget>[
        if (results.spots.isNotEmpty) ...<Widget>[
          _GroupHeader(label: l10n.searchResultSpots),
          for (final SpotRow s in results.spots)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(s.name),
              subtitle: s.description == null
                  ? null
                  : Text(s.description!,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => context.push(AppRoutes.spotDetail(tripId, s.id)),
            ),
        ],
        if (results.days.isNotEmpty) ...<Widget>[
          _GroupHeader(label: l10n.searchResultDays),
          for (final DayPlanRow d in results.days)
            ListTile(
              leading: CircleAvatar(child: Text('${d.dayIndex}')),
              title: Text(d.routeSummary ?? l10n.dayLabel(d.dayIndex)),
              subtitle: d.hotelName == null ? null : Text(d.hotelName!),
              onTap: () =>
                  context.push(AppRoutes.dayDetail(tripId, d.dayIndex)),
            ),
        ],
        if (results.info.isNotEmpty) ...<Widget>[
          _GroupHeader(label: l10n.searchResultInfo),
          for (final InfoSectionRow i in results.info)
            ExpansionTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(i.title),
              subtitle: Text(infoCategoryLabel(l10n, i.category)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(i.body),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
