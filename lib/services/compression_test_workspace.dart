import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/compression_test.dart';
import '../models/download_task.dart';

/// 测试文件仅存在于专属子目录，绝不清理下载源目录。
class CompressionTestWorkspace {
  CompressionTestWorkspace({this.temporaryDirectory = getTemporaryDirectory});

  final Future<Directory> Function() temporaryDirectory;
  static final Set<String> _activePaths = {};
  Directory? _directory;

  Directory get directory => _directory!;

  Future<void> open() async {
    final temp = await temporaryDirectory();
    final root = Directory('${temp.path}/video_compression_tests');
    await root.create(recursive: true);
    final session = await root.createTemp('session_');
    _directory = session;
    _activePaths.add(session.path);
    await _removeStale(root);
  }

  Future<void> _removeStale(Directory root) async {
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory &&
          entity.uri.pathSegments
              .where((s) => s.isNotEmpty)
              .last
              .startsWith('session_') &&
          !_activePaths.contains(entity.path)) {
        await entity.delete(recursive: true);
      }
    }
  }

  static String? sourcePath(DownloadTask task) {
    for (final path in [task.mp4Path, task.filePath]) {
      if (path != null && File(path).existsSync()) return path;
    }
    return null;
  }

  Future<({String path, int bytes})> copySource(
    String path, {
    required bool Function() cancelled,
  }) async {
    final source = File(path);
    final target = Directory('${directory.path}/source');
    await target.create(recursive: true);
    if (!path.toLowerCase().endsWith('.m3u8')) {
      _checkCancelled(cancelled);
      final copy = await source.copy('${target.path}/original.mp4');
      _checkCancelled(cancelled);
      return (path: copy.path, bytes: await copy.length());
    }
    return _copyPlaylist(source, target, cancelled);
  }

  Future<({String path, int bytes})> _copyPlaylist(
    File source,
    Directory target,
    bool Function() cancelled,
  ) async {
    final content = await source.readAsString();
    final references = _references(content);
    var bytes = await source.length();
    for (final reference in references) {
      _checkCancelled(cancelled);
      bytes += await _copyReference(source, target, reference);
    }
    _checkCancelled(cancelled);
    final playlist = await source.copy('${target.path}/playlist.m3u8');
    return (path: playlist.path, bytes: bytes);
  }

  Future<int> _copyReference(
    File playlist,
    Directory target,
    String reference,
  ) async {
    final uri = Uri.parse(reference);
    final decodedPath = Uri.decodeComponent(uri.path).replaceAll(r'\', '/');
    if (uri.hasScheme ||
        uri.hasAuthority ||
        decodedPath.startsWith('/') ||
        decodedPath.split('/').contains('..')) {
      throw const FormatException('测试只支持剧集目录内的本地分片和密钥');
    }
    // 解码后再规范路径，避免编码形式的 ../ 逃出测试目录。
    final source = File.fromUri(
      playlist.absolute.uri.resolveUri(uri),
    ).absolute.uri.normalizePath();
    final destination = File.fromUri(
      target.absolute.uri.resolveUri(uri),
    ).absolute.uri.normalizePath();
    if (!source.toString().startsWith(
          playlist.parent.absolute.uri.toString(),
        ) ||
        !destination.toString().startsWith(target.absolute.uri.toString())) {
      throw const FormatException('测试只支持剧集目录内的本地分片和密钥');
    }
    final output = File.fromUri(destination);
    await output.parent.create(recursive: true);
    await File.fromUri(source).copy(output.path);
    return output.length();
  }

  Set<String> _references(String content) {
    final references = <String>{};
    for (final line in content.split('\n').map((line) => line.trim())) {
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        throw const FormatException('请选择已下载完成的媒体播放列表');
      }
      if (line.isEmpty) continue;
      if (!line.startsWith('#')) {
        references.add(line);
      } else {
        references.addAll(
          RegExp(
            r'URI="([^"]+)"',
          ).allMatches(line).map((match) => match.group(1)!),
        );
      }
    }
    if (references.isEmpty) throw const FormatException('播放列表没有本地分片');
    return references;
  }

  void _checkCancelled(bool Function() cancelled) {
    if (cancelled()) throw const CompressionCancelled();
  }

  Future<void> clear() async {
    final dir = _directory;
    if (dir == null || !await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      await entity.delete(recursive: true);
    }
  }

  Future<void> close() async {
    final dir = _directory;
    if (dir == null) return;
    if (await dir.exists()) await dir.delete(recursive: true);
    _activePaths.remove(dir.path);
    _directory = null;
  }
}
