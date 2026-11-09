import 'dart:isolate';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/storage_usage.dart';
import 'app_log.dart';
import 'download_service.dart';
import 'storage_file_scanner.dart';

const _log = AppLog('storage_usage_service.dart');

class StorageUsageService {
  static const channel = MethodChannel('huangguo/storage_usage');

  Future<StorageUsage> read(DownloadService downloads) async {
    final albums = _albumPaths(downloads);
    final tasks = _taskPaths(downloads);
    final platform = await _platformUsage();
    final roots =
        (platform['appRoots'] as List?)?.cast<String>() ??
        await _dataRoots(downloads.downloadRoot);
    final files = await Isolate.run(
      () => StorageFileScanner().scan(roots, albums, tasks: tasks),
    );
    return StorageUsage(
      totalBytes: platform['totalBytes'] as int?,
      availableBytes: platform['availableBytes'] as int?,
      appBytes: files.appBytes,
      includesApplication: platform['includesApplication'] == true,
      albumBytes: files.albumBytes,
      taskBytes: files.taskBytes,
      failedPaths: files.failedPaths,
    );
  }

  /// 下载页仅扫描下载资源，不遍历应用本体、数据和缓存。
  Future<StorageUsage> readDownloadUsage(DownloadService downloads) async {
    final albums = _albumPaths(downloads);
    final tasks = _taskPaths(downloads);
    final platform = await _platformUsage();
    final files = await Isolate.run(
      () => StorageFileScanner().scan([], albums, tasks: tasks),
    );
    return StorageUsage(
      totalBytes: platform['totalBytes'] as int?,
      availableBytes: platform['availableBytes'] as int?,
      albumBytes: files.albumBytes,
      taskBytes: files.taskBytes,
    );
  }

  Map<String, List<String>> _albumPaths(DownloadService downloads) {
    final albums = <String, List<String>>{};
    final tasks = _taskPaths(downloads);
    for (final task in downloads.completedTasks) {
      final key = '${task.dramaName} (${task.dramaId})';
      albums.putIfAbsent(key, () => []).addAll(tasks[task.id]!);
    }
    return albums;
  }

  Map<String, List<String>> _taskPaths(DownloadService downloads) => {
    for (final task in downloads.completedTasks)
      task.id: [
        // 未初始化的测试服务没有下载根目录，不能解析为当前工作目录。
        if ((task.filePath?.isNotEmpty ?? false) ||
            downloads.downloadRoot.isNotEmpty)
          downloads.episodeDirectoryFor(task),
        if (task.mp4Path case final String path when path.isNotEmpty) path,
      ],
  };

  Future<Map<Object?, Object?>> _platformUsage() async {
    try {
      return await channel.invokeMapMethod<Object?, Object?>('read') ?? {};
    } on MissingPluginException {
      return {};
    } catch (error, stack) {
      _log.e('_platformUsage: 无法读取设备空间', error, stack);
      return {};
    }
  }

  Future<List<String>> _dataRoots(String downloadRoot) async {
    final roots = <String>[if (downloadRoot.isNotEmpty) downloadRoot];
    for (final provider in [
      if (Platform.isIOS || Platform.isAndroid)
        getApplicationDocumentsDirectory,
      getApplicationSupportDirectory,
      getApplicationCacheDirectory,
      if (Platform.isIOS || Platform.isAndroid) getTemporaryDirectory,
    ]) {
      try {
        roots.add((await provider()).path);
      } on MissingPluginException {
        // 不支持的平台保留“暂不可用”。
      } catch (error, stack) {
        _log.e('_dataRoots: 无法读取应用目录', error, stack);
      }
    }
    return roots;
  }
}
