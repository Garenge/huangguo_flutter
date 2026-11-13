import 'dart:io';

import '../models/download_task.dart';
import 'download_layout.dart';

/// 只删除指定集的文件与源目录，不能递归删除共享的 MP4 剧目录。
class DownloadResourceDeletion {
  const DownloadResourceDeletion(this.layout);

  final DownloadLayout layout;

  Future<void> delete(DownloadTask task) async {
    final files = <String>{
      if (task.mp4Path case final String path) path,
      if (task.filePath case final String path when path.endsWith('.mp4')) path,
      ...layout.mp4Candidates(task.dramaId, task.ep),
    };
    for (final path in files) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    final directories = <String>{
      layout.sourceDirectory(task),
      layout.legacyDirectory(task),
      if (task.filePath case final String path when path.endsWith('.m3u8'))
        File(path).parent.path,
    };
    for (final path in directories) {
      final directory = Directory(path);
      if (await directory.exists()) await directory.delete(recursive: true);
    }
    for (final path in layout.ownedAlbums(task.dramaId).toList()) {
      final directory = Directory(path);
      final children = await directory.list(followLinks: false).toList();
      if (children.length == 1 &&
          children.single.path == '$path/${DownloadLayout.ownerFile}') {
        await children.single.delete();
        await directory.delete();
      }
    }
  }
}
