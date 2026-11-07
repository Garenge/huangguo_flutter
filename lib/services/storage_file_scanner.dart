import 'dart:io';

/// 仅在后台 isolate 中使用；忽略符号链接，按规范化后的绝对路径去重。
class StorageFileScanner {
  final _files = <String, int>{};
  final _visited = <String>{};
  final _failed = <String>{};

  ({int? appBytes, Map<String, int?> albumBytes}) scan(
    List<String> appRoots,
    Map<String, List<String>> albums,
  ) {
    final roots = appRoots.map(_normalize).toSet();
    for (final root in roots) {
      _visit(root);
    }
    final appBytes = roots.isEmpty ? null : _sum(roots);
    final albumBytes = <String, int?>{};
    for (final album in albums.entries) {
      final paths = album.value.map(_normalize).toSet();
      for (final path in paths) {
        _visit(path);
      }
      albumBytes[album.key] = _sum(paths);
    }
    return (appBytes: appBytes, albumBytes: albumBytes);
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

  int? _sum(Set<String> roots) {
    if (_failed.any((path) => roots.any((root) => _within(path, root)))) {
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
      } else if (type == FileSystemEntityType.directory) {
        for (final child in Directory(path).listSync(followLinks: false)) {
          _visit(_normalize(child.path));
        }
      }
    } on FileSystemException catch (error) {
      // 下载、转码、删除可以与扫描同时发生，已消失的文件不算读取失败。
      if (error.osError?.errorCode != 2 && error.osError?.errorCode != 3) {
        _failed.add(path);
      }
    }
  }
}
