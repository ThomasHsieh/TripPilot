import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 平台安全儲存包裝。**絕不**把 API key 存於 SharedPreferences 或 DB。
/// 見規格 §4.2 / §7.2。
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  static const String _kClaudeApiKey = 'claude_api_key';
  static const String _kClaudeModel = 'claude_model';
  static const String _kPdfConsent = 'pdf_upload_consent';

  Future<String?> getClaudeApiKey() => _storage.read(key: _kClaudeApiKey);

  Future<void> setClaudeApiKey(String value) =>
      _storage.write(key: _kClaudeApiKey, value: value);

  Future<void> clearClaudeApiKey() => _storage.delete(key: _kClaudeApiKey);

  Future<bool> hasClaudeApiKey() async {
    final String? key = await getClaudeApiKey();
    return key != null && key.trim().isNotEmpty;
  }

  Future<String?> getClaudeModel() => _storage.read(key: _kClaudeModel);

  Future<void> setClaudeModel(String value) =>
      _storage.write(key: _kClaudeModel, value: value);

  /// PDF 上傳（抽出文字至 Claude API）同意旗標（§7.3，可記住）。
  Future<bool> getPdfUploadConsent() async {
    final String? v = await _storage.read(key: _kPdfConsent);
    return v == 'true';
  }

  Future<void> setPdfUploadConsent(bool value) =>
      _storage.write(key: _kPdfConsent, value: value ? 'true' : 'false');
}

/// 全域 provider，供服務層與設定頁使用。
final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());
