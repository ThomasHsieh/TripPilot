import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';

/// 注入的 SharedPreferences 實例（於 main 取得後 override）。
final sharedPrefsProvider = Provider<SharedPreferences>((Ref ref) {
  throw UnimplementedError('sharedPrefsProvider 必須於 main 以實例 override');
});

/// App 層級偏好設定（主題模式、語系、AI 模型），持久化於 SharedPreferences。
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.claudeModel = AppConstants.defaultClaudeModel,
  });

  final ThemeMode themeMode;

  /// null = 跟隨系統（zh-Hant 為第一語系）。
  final Locale? locale;

  final String claudeModel;

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool clearLocale = false,
    String? claudeModel,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: clearLocale ? null : (locale ?? this.locale),
      claudeModel: claudeModel ?? this.claudeModel,
    );
  }
}

class SettingsController extends Notifier<AppSettings> {
  static const String _kTheme = 'settings_theme_mode';
  static const String _kLocale = 'settings_locale';

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  AppSettings build() {
    return AppSettings(
      themeMode: _themeFrom(_prefs.getString(_kTheme)),
      locale: _localeFrom(_prefs.getString(_kLocale)),
    );
  }

  void setThemeMode(ThemeMode mode) {
    _prefs.setString(_kTheme, mode.name);
    state = state.copyWith(themeMode: mode);
  }

  void setLocale(Locale? locale) {
    if (locale == null) {
      _prefs.remove(_kLocale);
      state = state.copyWith(clearLocale: true);
    } else {
      _prefs.setString(_kLocale, locale.languageCode);
      state = state.copyWith(locale: locale);
    }
  }

  void setClaudeModel(String model) =>
      state = state.copyWith(claudeModel: model);

  static ThemeMode _themeFrom(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static Locale? _localeFrom(String? v) =>
      (v == null || v.isEmpty) ? null : Locale(v);
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
