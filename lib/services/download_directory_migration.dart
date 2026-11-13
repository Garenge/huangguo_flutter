import 'dart:io';

import '../models/download_task.dart';
import 'app_log.dart';
import 'download_layout.dart';

/// 每次启动检查，按文件实际位置恢复；目标冲突时保留旧文件，供下次重试。
class DownloadDirectoryMigration {
  DownloadDirectoryMigration(this.layout, this.tasks, this.persist);

  final DownloadLayout layout;
  final List<DownloadTask> tasks;
  final Future<void> Function() persist;
  static const _log = AppLog('download_directory_migration.dart');

  Future<void> run() async {
    var moved = 0;
    for (final task in tasks) {
      try {
        if (await _migrateTask(task)) moved++;
      } catch (error, stack) {
        _log.e('run: 整理下载失败 taskId=${task.id}', error, stack);
      }
    }
    try {
      await _migrateUntracked();
    } catch (error, stack) {
      _log.e('run: 检查遗留目录失败，保留原文件', error, stack);
    }
    _log.i('run: 下载目录检查完成，整理任务数=$moved');
  }

  Future<bool> _migrateTask(DownloadTask task) async {
    final legacy = layout.legacyDirectory(task);
    final playlist = '${layout.sourceDirectory(task)}/playlist.m3u8';
    // 源目录重命名后进程中断时，旧记录可由新位置恢复。
    if (task.filePath?.endsWith('.m3u8') == true &&
        !File(task.filePath!).existsSync() &&
        File(playlist).existsSync()) {
      task.filePath = playlist;
      await persist();
    }
    final source = _existingMp4(task, legacy);
    final target = layout.mp4Path(task);
    if (source != null && source != target && File(target).existsSync()) {
      _log.w('_migrateTask: 目标已存在，保留原视频 source=$source target=$target');
      return false;
    }
    if (source != null) {
      final previousFilePath = task.filePath;
      final previousMp4Path = task.mp4Path;
      await layout.prepareAlbum(task);
      if (source != target) await File(source).rename(target);
      if (task.filePath == source ||
          (task.filePath?.toLowerCase().endsWith('.mp4') == true &&
              !File(task.filePath!).existsSync())) {
        task.filePath = target;
      }
      task.mp4Path = target;
      // 先落盘再整理源目录；中断后可从规范路径恢复。
      if (source != target ||
          previousFilePath != task.filePath ||
          previousMp4Path != task.mp4Path) {
        await persist();
      }
    }
    await _moveSources(task, legacy);
    await _removeEmpty(Directory(legacy));
    await _removeEmpty(Directory(legacy).parent);
    return source != null && source != target;
  }

  String? _existingMp4(DownloadTask task, String legacy) {
    for (final path in [task.mp4Path, task.filePath]) {
      if (path != null &&
          path.toLowerCase().endsWith('.mp4') &&
          File(path).existsSync()) {
        return path;
      }
    }
    final oldDirectory = Directory(legacy);
    if (oldDirectory.existsSync()) {
      final files = oldDirectory
          .listSync(followLinks: false)
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.mp4'))
          .toList();
      if (files.length == 1) return files.single.path;
    }
    final target = layout.mp4Path(task);
    return File(target).existsSync() ? target : null;
  }

  Future<void> _moveSources(DownloadTask task, String legacy) async {
    final recorded = task.filePath;
    final from = recorded != null && recorded.endsWith('.m3u8')
        ? File(recorded).parent.path
        : legacy;
    final target = layout.sourceDirectory(task);
    if (from == target || !Directory(from).existsSync()) return;
    final folder = Directory(from);
    // 未迁移的 MP4 或额外文件保留原目录，避免顺带移动未知资源。
    final files = await folder.list(followLinks: false).toList();
    if (files.isEmpty ||
        files.any((file) => file is! File || !_isSource(file.path))) {
      return;
    }
    if (Directory(target).existsSync()) return;
    await Directory(target).parent.create(recursive: true);
    await folder.rename(target);
    if (recorded != null && File(recorded).parent.path == from) {
      task.filePath = '$target/${File(recorded).uri.pathSegments.last}';
    }
    await persist();
    await _removeEmpty(Directory(from).parent);
  }

  bool _isSource(String path) {
    final name = File(path).uri.pathSegments.last.toLowerCase();
    return name == 'playlist.m3u8' ||
        name.endsWith('.ts') ||
        (name.startsWith('key_') && name.endsWith('.bin'));
  }

  Future<void> _migrateUntracked() async {
    final root = Directory(layout.root);
    final albums = await root.list(followLinks: false).toList();
    for (final album in albums.whereType<Directory>()) {
      final match = RegExp(
        r'^(.+) \(([^()]+)\)$',
      ).firstMatch(album.uri.pathSegments.where((s) => s.isNotEmpty).last);
      if (match == null || layout.albumOwner(album.path) != null) continue;
      final episodes = await album.list(followLinks: false).toList();
      for (final episode in episodes.whereType<Directory>()) {
        try {
          await _migrateUntrackedEpisode(episode, match[1]!, match[2]!);
        } catch (error, stack) {
          _log.e(
            '_migrateUntracked: 整理遗留视频失败 path=${episode.path}',
            error,
            stack,
          );
        }
      }
      await _removeEmpty(album);
    }
  }

  Future<void> _migrateUntrackedEpisode(
    Directory directory,
    String dramaName,
    String dramaId,
  ) async {
    final name = directory.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final match = RegExp(r'^第\s*(\d+)\s*集$').firstMatch(name);
    if (match == null ||
        tasks.any(
          (task) =>
              task.dramaId == dramaId &&
              DownloadLayout.episodeNumber(task.ep) ==
                  DownloadLayout.episodeNumber(match[1]!),
        )) {
      return;
    }
    final task = DownloadTask(
      id: '',
      dramaId: dramaId,
      dramaName: dramaName,
      episodeName: name,
      episodeUrl: '',
      ep: match[1]!,
    );
    final source = _existingMp4(task, directory.path);
    if (source == null || source == layout.mp4Path(task)) return;
    final target = layout.mp4Path(task);
    if (File(target).existsSync()) {
      _log.w('_migrateUntrackedEpisode: 目标已存在，保留原视频 path=$source');
      return;
    }
    await layout.prepareAlbum(task);
    await File(source).rename(target);
    await _moveSources(task, directory.path);
    await _removeEmpty(directory);
  }

  Future<void> _removeEmpty(Directory directory) async {
    if (await directory.exists() && await directory.list().isEmpty) {
      await directory.delete();
    }
  }
}
