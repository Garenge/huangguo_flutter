import 'dart:io';

import 'package:video_player/video_player.dart';

import '../models/download_task.dart';
import '../models/episode.dart';
import 'download_service.dart';
import 'local_download_lookup.dart';
import 'local_media_server.dart';

/// 两个播放入口共用的本地资源选择和 HLS 服务生命周期。
class LocalPlaybackSource {
  LocalPlaybackSource(this.path);

  final String path;
  final LocalMediaServer _server = LocalMediaServer();
  bool _disposed = false;

  static LocalPlaybackSource? forEpisode(
    DownloadService? downloads,
    String? dramaId,
    String ep, {
    String episodeUrl = '',
    String episodeName = '',
  }) {
    if (downloads == null) return null;
    final lookup = LocalDownloadLookup(
      downloads,
      Episode(name: episodeName, url: episodeUrl, ep: ep),
      dramaId: dramaId,
    );
    final tasks = lookup.tasks;
    if (tasks.any(
      (task) =>
          task.status != DownloadStatus.completed &&
          task.status != DownloadStatus.failed,
    )) {
      return null;
    }
    for (final task in tasks) {
      final source = forTask(
        task,
        directory: downloads.episodeDirectoryFor(task),
      );
      if (source != null) return source;
    }
    if (lookup.dramaId case final String id) {
      for (final path in downloads.layout.mp4Candidates(id, ep)) {
        return LocalPlaybackSource(path);
      }
      final source = forDirectory(downloads.layout.sourceDirectoryFor(id, ep));
      if (source != null) return source;
    }
    for (final directory in lookup.directories) {
      final source = forDirectory(directory);
      if (source != null) return source;
    }
    return null;
  }

  static LocalPlaybackSource? forTask(DownloadTask task, {String? directory}) {
    for (final path in [task.mp4Path, task.filePath]) {
      if (_exists(path) && path!.toLowerCase().endsWith('.mp4')) {
        return LocalPlaybackSource(path);
      }
    }
    final root = directory ?? _taskDirectory(task);
    final source = root == null ? null : forDirectory(root);
    if (source != null && source.path.toLowerCase().endsWith('.mp4')) {
      return source;
    }
    if (_exists(task.filePath) &&
        task.filePath!.toLowerCase().endsWith('.m3u8')) {
      return LocalPlaybackSource(task.filePath!);
    }
    return source;
  }

  static String? _taskDirectory(DownloadTask task) {
    final path = task.filePath;
    if (path != null && path.toLowerCase().endsWith('.m3u8')) {
      return File(path).parent.path;
    }
    // MP4 的父目录由整部剧共享，不能扫描并误播其他集。
    return null;
  }

  static LocalPlaybackSource? forDirectory(String root) {
    final folder = Directory(root);
    if (folder.existsSync()) {
      for (final file
          in folder.listSync(followLinks: false).whereType<File>()) {
        if (file.path.toLowerCase().endsWith('.mp4')) {
          return LocalPlaybackSource(file.path);
        }
      }
    }
    final playlist = '$root/playlist.m3u8';
    return _exists(playlist) ? LocalPlaybackSource(playlist) : null;
  }

  static bool _exists(String? path) =>
      path != null && path.isNotEmpty && File(path).existsSync();

  Future<VideoPlayerController> createController() async {
    if (_disposed) throw StateError('本地播放源已关闭');
    if (path.toLowerCase().endsWith('.mp4')) {
      return VideoPlayerController.file(File(path));
    }
    await _server.start(File(path).parent.path);
    if (_disposed) {
      _server.stop();
      throw StateError('本地播放源已关闭');
    }
    final name = Uri.file(path).pathSegments.last;
    return VideoPlayerController.networkUrl(
      Uri.parse(
        'http://127.0.0.1:${_server.port}/${Uri.encodeComponent(name)}',
      ),
    );
  }

  void dispose() {
    _disposed = true;
    _server.stop();
  }
}
