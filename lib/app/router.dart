import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/bootstrap/bootstrap_screen.dart';
import '../features/day_detail/day_detail_screen.dart';
import '../features/day_detail/spot_detail_screen.dart';
import '../features/exchange_rate/exchange_rate_screen.dart';
import '../features/info_hub/info_hub_screen.dart';
import '../features/journal/journal_screen.dart';
import '../features/journal_export/journal_export_screen.dart';
import '../features/reminders/reminders_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/trip_home/all_days_screen.dart';
import '../features/trip_home/trip_home_screen.dart';
import 'routes.dart';

/// go_router 設定。宣告式路由，對應規格 §5.1。
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.tripList,
    debugLogDiagnostics: true,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.tripList,
        name: AppRoutes.nTripList,
        builder: (context, state) => const BootstrapScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: AppRoutes.nSettings,
        builder: (context, state) => const SettingsScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'exchange-rates',
            name: AppRoutes.nExchangeRates,
            builder: (context, state) => const ExchangeRateScreen(),
          ),
        ],
      ),

      // ── 行程範圍（trip-scoped）────────────────────────────────
      GoRoute(
        path: '/trip/:id',
        name: AppRoutes.nTripHome,
        builder: (context, state) =>
            TripHomeScreen(tripId: state.pathParameters['id']!),
        routes: <RouteBase>[
          GoRoute(
            path: 'days',
            name: AppRoutes.nTripDays,
            builder: (context, state) =>
                AllDaysScreen(tripId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'day/:dayIndex',
            name: AppRoutes.nDayDetail,
            builder: (context, state) => DayDetailScreen(
              tripId: state.pathParameters['id']!,
              dayIndex: int.parse(state.pathParameters['dayIndex']!),
            ),
          ),
          GoRoute(
            path: 'spot/:spotId',
            name: AppRoutes.nSpotDetail,
            builder: (context, state) => SpotDetailScreen(
              tripId: state.pathParameters['id']!,
              spotId: state.pathParameters['spotId']!,
            ),
          ),
          GoRoute(
            path: 'info',
            name: AppRoutes.nInfo,
            builder: (context, state) =>
                InfoHubScreen(tripId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'reminders',
            name: AppRoutes.nReminders,
            builder: (context, state) =>
                RemindersScreen(tripId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'journal',
            name: AppRoutes.nJournal,
            builder: (context, state) =>
                JournalScreen(tripId: state.pathParameters['id']!),
            routes: <RouteBase>[
              GoRoute(
                path: 'export',
                name: AppRoutes.nJournalExport,
                builder: (context, state) =>
                    JournalExportScreen(tripId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: 'search',
            name: AppRoutes.nSearch,
            builder: (context, state) =>
                SearchScreen(tripId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('404: ${state.uri}')),
    ),
  );
});
