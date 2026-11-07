import 'dart:io';

/// 一个本地媒体播放列表及其实际引用文件的逻辑大小。
class HlsSourceSize {
  final int bytes;
  final int segmentCount;

  const HlsSourceSize({required this.bytes, required this.segmentCount});

  static Future<HlsSourceSize> read(String playlistPath) async {
    final playlist = File(playlistPath);
    final content = await playlist.readAsString();
    final files = <String>{playlist.absolute.uri.normalizePath().toFilePath()};
    final segments = <String>{};
    for (final line in content.split('\n').map((line) => line.trim())) {
      if (line.isEmpty) continue;
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        throw const FormatException('源大小统计需要媒体播放列表，不能使用多码率主播放列表');
      }
      if (!line.startsWith('#')) {
        final path = _resolve(playlist, line);
        files.add(path);
        segments.add(path);
      } else if (line.startsWith('#EXT-X-KEY:') ||
          line.startsWith('#EXT-X-MAP:')) {
        for (final match in RegExp(r'URI="([^"]+)"').allMatches(line)) {
          files.add(_resolve(playlist, match.group(1)!));
        }
      }
    }
    var bytes = 0;
    for (final path in files) {
      // 任一引用读取失败则整体报错，避免用不完整的源大小计算膨胀率。
      bytes += await File(path).length();
    }
    return HlsSourceSize(bytes: bytes, segmentCount: segments.length);
  }

  static String _resolve(File playlist, String reference) {
    final uri = playlist.absolute.uri.resolve(reference).normalizePath();
    if (uri.scheme != 'file') {
      throw FormatException('源大小统计只支持本地文件：$reference');
    }
    return uri.toFilePath();
  }
}
