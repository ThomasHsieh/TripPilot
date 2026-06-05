import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/id.dart';

/// 將相片複製進 App 私有沙盒（規格 §7.2），回傳本地路徑。
class PhotoStore {
  const PhotoStore();

  Future<String> save(String sourcePath) async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory photoDir = Directory(p.join(docs.path, 'journal_photos'));
    if (!photoDir.existsSync()) {
      photoDir.createSync(recursive: true);
    }
    final String ext =
        p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final String dest = p.join(photoDir.path, '${Ids.newId()}$ext');
    await File(sourcePath).copy(dest);
    return dest;
  }
}
