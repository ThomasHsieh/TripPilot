import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/launchers.dart';
import '../../data/database/app_database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../journal/photo_viewer.dart';
import '../trip_home/trip_providers.dart';
import 'spot_image.dart';

/// 景點詳情（§5.3）：名稱、visit_type、介紹、退費條款、地圖。
class SpotDetailScreen extends ConsumerWidget {
  const SpotDetailScreen({
    super.key,
    required this.tripId,
    required this.spotId,
  });

  final String tripId;
  final String spotId;

  String _visitLabel(AppLocalizations l10n, VisitType t) => switch (t) {
        VisitType.enter => l10n.visitTypeEnter,
        VisitType.photo => l10n.visitTypePhoto,
        VisitType.driveBy => l10n.visitTypeDriveBy,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<SpotRow?> spot = ref.watch(spotProvider(spotId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.spotDetailTitle)),
      body: spot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (SpotRow? s) {
          if (s == null) return Center(child: Text(l10n.errorGeneric));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              if (s.imagePath != null) ...<Widget>[
                GestureDetector(
                  onTap: () =>
                      showPhotoViewer(context, <String>[s.imagePath!], 0),
                  child: SpotImage(path: s.imagePath!, height: 220),
                ),
                const SizedBox(height: 16),
              ],
              Text(s.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Chip(label: Text(_visitLabel(l10n, s.visitType))),
              if (s.description != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(s.description!,
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
              if (s.refundNote != null) ...<Widget>[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.info_outline, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${l10n.refundNote}: ${s.refundNote}'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Launchers.openMap(context, s.name),
                icon: const Icon(Icons.map_outlined),
                label: Text(l10n.commonMap),
              ),
            ],
          );
        },
      ),
    );
  }
}
