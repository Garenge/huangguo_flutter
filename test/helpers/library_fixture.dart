import 'dart:convert';

import 'package:huangguo_flutter/models/drama.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/services/download_service.dart';
import 'package:huangguo_flutter/services/library_service.dart';
import 'package:huangguo_flutter/services/library_storage.dart';

const libraryDrama = Drama(
  id: 'drama-1',
  name: '媒体库测试剧',
  pic: '/poster.jpg',
  remark: '全10集',
);

class MemoryLibraryStorage extends LibraryStorage {
  Map<String, dynamic> data = {};
  bool failWrites = false;
  int writes = 0;

  @override
  Future<Map<String, dynamic>> read() async =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);

  @override
  Future<void> write(Map<String, dynamic> data) async {
    if (failWrites) throw StateError('模拟存储失败');
    writes++;
    this.data = Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
  }
}

Future<LibraryService> memoryLibrary() async {
  final library = LibraryService(storage: MemoryLibraryStorage());
  await library.load();
  return library;
}

class LibraryDownloads extends DownloadService {
  LibraryDownloads(super.api);
  final items = <DownloadTask>[];

  @override
  List<DownloadTask> get tasks => items;

  void changed() => notifyListeners();
}
