import 'package:uuid/uuid.dart';

/// 統一的 ID 產生器（TEXT uuid 主鍵）。
class Ids {
  Ids._();
  static const Uuid _uuid = Uuid();
  static String newId() => _uuid.v4();
}
