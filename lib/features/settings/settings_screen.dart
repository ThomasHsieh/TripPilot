import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../l10n/generated/app_localizations.dart';
import 'settings_controller.dart';

/// 設定：外觀（深淺色）、語系、匯率管理（§5.1）。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings = ref.watch(settingsControllerProvider);
    final SettingsController ctrl =
        ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: <Widget>[
          _SectionHeader(text: l10n.settingsAppearance),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<ThemeMode>(
              segments: <ButtonSegment<ThemeMode>>[
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  label: Text(l10n.themeSystem),
                  icon: const Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  label: Text(l10n.themeLight),
                  icon: const Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  label: Text(l10n.themeDark),
                  icon: const Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: <ThemeMode>{settings.themeMode},
              onSelectionChanged: (Set<ThemeMode> s) =>
                  ctrl.setThemeMode(s.first),
            ),
          ),
          const Divider(),
          _SectionHeader(text: l10n.settingsLanguage),
          RadioGroup<String>(
            groupValue: _localeKey(settings.locale),
            onChanged: (String? v) => ctrl.setLocale(_localeFor(v)),
            child: Column(
              children: <Widget>[
                RadioListTile<String>(
                  value: 'system',
                  title: Text(l10n.langSystem),
                ),
                RadioListTile<String>(
                  value: 'zh',
                  title: Text(l10n.langZh),
                ),
                RadioListTile<String>(
                  value: 'en',
                  title: Text(l10n.langEn),
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(text: l10n.settingsGeneral),
          ListTile(
            leading: const Icon(Icons.currency_exchange_outlined),
            title: Text(l10n.settingsExchangeRates),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.exchangeRates),
          ),
        ],
      ),
    );
  }

  String _localeKey(Locale? locale) =>
      locale == null ? 'system' : locale.languageCode;

  Locale? _localeFor(String? key) =>
      (key == null || key == 'system') ? null : Locale(key);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
