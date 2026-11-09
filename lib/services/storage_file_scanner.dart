import 'dart:io';

import 'app_log.dart';

const _log = AppLog('storage_file_scanner.dart');

/// 仅在后台 isolate 中使用；忽略符号链接，按规范化后的绝对路径去重。
class StorageFileScanner {
  final _files = <String, int>{};
  final _visited = <String>{};
  final _failed = <String>{};
  final _readable = <String>{};
  final List<FileSystemEntity> Function(String) _listDirectory;

  StorageFileScanner({List<FileSystemEntity> Function(String)? listDirectory})
    : _listDirectory = listDirectory ?? _children;

  static List<FileSystemEntity> _children(String path) =>
      Directory(path).listSync(followLinks: false);

  ({
    int? appBytes,
    Map<String, int?> albumBytes,
    Map<String, int?> taskBytes,
    List<String> failedPaths,
  })
  scan(
    List<String> appRoots,
    Map<String, List<String>> albums, {
    Map<String, List<String>> tasks = const {},
  }) {
    final roots = appRoots.map(_normalize).toSet();
    for (final root in roots) {
      _visit(root);
    }
    final failedPaths = _failed.toList();
    final readable = _readable.any(
      (path) => roots.any((root) => _within(path, root)),
    );
    final appBytes = roots.isEmpty || (!readable && failedPaths.isNotEmpty)
        ? null
        : _sum(roots, allowPartial: true);
    final albumBytes = _scanGroups(albums);
    final taskBytes = _scanGroups(tasks);
    return (
      appBytes: appBytes,
      albumBytes: albumBytes,
      taskBytes: taskBytes,
      failedPaths: failedPaths,
    );
  }

  Map<String, int?> _scanGroups(Map<String, List<String>> groups) {
    final sizes = <String, int?>{};
    for (final group in groups.entries) {
      final paths = group.value.map(_normalize).toSet();
      for (final path in paths) {
        _visit(path);
      }
      sizes[group.key] = _sum(paths);
    }
    return sizes;
  }

  String _normalize(String path) =>
      File(path).absolute.uri.normalizePath().toFilePath();

  bool _within(String path, String root) =>
      path == root ||
      path.startsWith(
        root.endsWith(Platform.pathSeparator)
            ? root
            : '$root${Platform.pathSeparator}',
      );

  int? _sum(Set<String> roots, {bool allowPartial = false}) {
    if (!allowPartial &&
        _failed.any((path) => roots.any((root) => _within(path, root)))) {
      return null;
    }
    return _files.entries
        .where((file) => roots.any((root) => _within(file.key, root)))
        .fold<int>(0, (total, file) => total + file.value);
  }

  void _visit(String path) {
    if (!_visited.add(path)) return;
    try {
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.file) {
        _files[path] = File(path).lengthSync();
        _readable.add(path);
      } else if (type == FileSystemEntityType.directory) {
        final children = _listDirectory(path);
        _readable.add(path);
        for (final child in children) {
          _visit(_normalize(child.path));
        }
      }
    } on FileSystemException catch (error) {
      // 下载、转码、删除可以与扫描同时发生，已消失的文件不算读取失败。
      if (error.osError?.errorCode != 2 && error.osError?.errorCode != 3) {
        _failed.add(path);
        _log.w('_visit: 无法读取路径=$path，原因=$error');
      }
    }
  }
}
