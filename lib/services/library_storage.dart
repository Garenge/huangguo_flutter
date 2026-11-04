import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'migration_storage.dart';

/// 收藏和长期观看状态独立于有容量上限的播放历史。
class LibraryStorage {
  LibraryStorage({this.directory});

  final Directory? directory;
  Future<void> _pending = Future.value();

  Future<File> _file() async {
    final root = directory ?? await getApplicationDocumentsDirectory();
    return File('${root.path}/library.json');
  }

  Future<Map<String, dynamic>> read() async {
    final file = await _file();
    if (!await file.exists()) return {};
    return Map<String, dynamic>.from(
      jsonDecode(await file.readAsString()) as Map,
    );
  }

  Future<void> write(Map<String, dynamic> data) {
    // 入队时拍快照，避免后续操作修改正在保存的数据。
    final snapshot = jsonDecode(jsonEncode(data));
    final operation = _pending.then((_) async {
      await writeMigrationJson(await _file(), snapshot);
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}
