import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/routes.dart';
import '../../core/constants.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/trip_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../import/sample_loader.dart';
import '../reminders/reminder_scheduler.dart';
import '../settings/settings_controller.dart';

/// 啟動引導：確保內建訂製行程已載入，然後直接導向其行程首頁（§ 規格調整）。
class BootstrapScreen extends ConsumerStatefulWidget {
  const BootstrapScreen({super.key});

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      final TripRepository repo = ref.read(tripRepositoryProvider);
      final SharedPreferences prefs = ref.read(sharedPrefsProvider);
      final List<TripRow> trips = await repo.getTrips();
      final int storedVersion = prefs.getInt(_kContentVersion) ?? 0;

      String tripId;
      // 首次安裝（空）或內建行程內容版本更新時，重新載入內建行程。
      if (trips.isEmpty || storedVersion != AppConstants.sampleContentVersion) {
        for (final TripRow t in trips) {
          await repo.deleteTrip(t.id);
        }
        tripId = await loadSampleTrip(repo);
        if (mounted) {
          await ref
              .read(reminderSchedulerProvider)
              .createDefaults(tripId, AppLocalizations.of(context));
        }
        await prefs.setInt(
          _kContentVersion,
          AppConstants.sampleContentVersion,
        );
      } else {
        tripId = trips.first.id;
      }
      if (mounted) context.go(AppRoutes.tripHome(tripId));
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  static const String _kContentVersion = 'sample_content_version';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(AppLocalizations.of(context).errorGeneric),
                    const SizedBox(height: 8),
                    Text(_error!, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() => _error = null);
                        _init();
                      },
                      child: Text(AppLocalizations.of(context).commonRetry),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
