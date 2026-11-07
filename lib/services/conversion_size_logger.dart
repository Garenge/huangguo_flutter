import 'dart:io';

import '../models/storage_usage.dart';
import 'app_log.dart';
import 'hls_source_size.dart';

const _log = AppLog('conversion_size_logger.dart');

/// 统计失败只记录诊断，不阻断原有转换或复用行为。
class ConversionSizeLogger {
  final String label;
  final String playlistPath;
  final String outputPath;
  HlsSourceSize? _source;

  ConversionSizeLogger({
    required this.label,
    required this.playlistPath,
    required this.outputPath,
  });

  Future<void> logBefore() async {
    try {
      _source = await HlsSourceSize.read(playlistPath);
    } catch (error, stack) {
      _log.e('logBefore: 源资源统计失败，剧集=$label，播放列表=$playlistPath', error, stack);
    }
    _log.i(
      'logBefore: 转换前，剧集=$label，源资源=${_size(_source?.bytes)}，'
      '分片=${_source?.segmentCount ?? "暂不可用"}，播放列表=$playlistPath',
    );
  }

  Future<void> logAfter() async {
    final outputBytes = await _readOutput('logAfter', label, outputPath);
    final sourceBytes = _source?.bytes;
    final comparable =
        sourceBytes != null && sourceBytes > 0 && outputBytes != null;
    final delta = comparable ? outputBytes - sourceBytes : null;
    final percent = comparable
        ? _signed((outputBytes / sourceBytes - 1) * 100)
        : null;
    final ratio = comparable
        ? (outputBytes / sourceBytes).toStringAsFixed(2)
        : null;
    _log.i(
      'logAfter: 转换完成，剧集=$label，源资源=${_size(sourceBytes)}，'
      'MP4=${_size(outputBytes)}，变化=${_deltaSize(delta)}，'
      '变化率=${percent == null ? "暂不可用" : "$percent%"}，'
      '体积倍数=${ratio == null ? "暂不可用" : "${ratio}x"}，输出=$outputPath',
    );
  }

  static Future<void> logReused({
    required String label,
    required String outputPath,
  }) async {
    final bytes = await _readOutput('logReused', label, outputPath);
    _log.i(
      'logReused: 复用已有 MP4，跳过转换，剧集=$label，'
      'MP4=${_size(bytes)}，输出=$outputPath',
    );
  }

  static Future<int?> _readOutput(
    String function,
    String label,
    String path,
  ) async {
    try {
      return await File(path).length();
    } catch (error, stack) {
      _log.e('$function: MP4 统计失败，剧集=$label，输出=$path', error, stack);
      return null;
    }
  }

  static String _size(int? bytes) =>
      bytes == null ? '暂不可用' : '${formatStorageBytes(bytes)} ($bytes B)';

  static String _signed(double value) =>
      '${value > 0 ? "+" : ""}${value.toStringAsFixed(2)}';

  static String _deltaSize(int? bytes) {
    if (bytes == null) return '暂不可用';
    if (bytes == 0) return '0 B';
    return '${bytes > 0 ? "+" : "-"}${_size(bytes.abs())}';
  }
}
