import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_pilot/features/settings/settings_controller.dart';

/// M8：外觀 / 語系設定狀態 + 持久化。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('主題模式與語系切換並持久化', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    final SettingsController ctrl = c.read(settingsControllerProvider.notifier);

    expect(c.read(settingsControllerProvider).themeMode, ThemeMode.system);
    expect(c.read(settingsControllerProvider).locale, isNull);

    ctrl.setThemeMode(ThemeMode.dark);
    expect(c.read(settingsControllerProvider).themeMode, ThemeMode.dark);
    expect(prefs.getString('settings_theme_mode'), 'dark');

    ctrl.setLocale(const Locale('en'));
    expect(c.read(settingsControllerProvider).locale, const Locale('en'));
    expect(prefs.getString('settings_locale'), 'en');

    ctrl.setLocale(null);
    expect(c.read(settingsControllerProvider).locale, isNull);
    expect(prefs.getString('settings_locale'), isNull);
  });

  test('啟動時從持久化讀回設定', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings_theme_mode': 'light',
      'settings_locale': 'en',
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);

    final AppSettings s = c.read(settingsControllerProvider);
    expect(s.themeMode, ThemeMode.light);
    expect(s.locale, const Locale('en'));
  });
}
