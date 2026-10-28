import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'app_log.dart';

const _log = AppLog('ExportService');

/// 导出结果
class ExportResult {
  final bool success;
  final String? outputPath;
  final String? error;

  const ExportResult({required this.success, this.outputPath, this.error});
}

/// MP4 导出服务：将已下载的 HLS 分片（加密 TS）重封装为 MP4。
///
/// 输出路径由调用方决定，批量转换会将 MP4 保存在对应剧集目录。
class ExportService {
  /// 构建剧集目录内的稳定 MP4 路径。
  static String outputPath({
    required String m3u8Dir,
    required String episodeName,
  }) {
    final safeEp = episodeName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final fileName = safeEp.isEmpty ? 'converted' : safeEp;
    return '$m3u8Dir/$fileName.mp4';
  }

  /// 构建临时输出路径：临时目录/剧名_第X集_时间戳.mp4
  static Future<String> tempOutputPath({
    required String dramaName,
    required String episodeName,
  }) async {
    final tmpDir = await getTemporaryDirectory();
    final safeDrama = dramaName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final safeEp = episodeName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${tmpDir.path}/${safeDrama}_${safeEp}_$ts.mp4';
  }

  /// 将 m3u8Dir 下的 TS 分片导出为 MP4。
  ///
  /// [m3u8Dir] 包含 playlist.m3u8、key_*.bin、00000.ts...
  /// [outputPath] 目标 mp4 完整路径。
  ///
  /// ffmpeg 会自动从 m3u8 文件所在目录解析相对路径引用（key、TS）。
  static Future<ExportResult> export({
    required String m3u8Dir,
    required String outputPath,
  }) async {
    // 1. 检查 m3u8 源文件
    final m3u8Path = '$m3u8Dir/playlist.m3u8';
    final m3u8File = File(m3u8Path);
    if (!await m3u8File.exists()) {
      _log.e('export: playlist.m3u8 not found at $m3u8Dir');
      return ExportResult(success: false, error: '源文件不存在');
    }

    // 2. 确保输出目录
    await File(outputPath).parent.create(recursive: true);

    // 3. 执行 ffmpeg（使用绝对路径，ffmpeg 从 m3u8 位置解析相对引用）
    final cmd =
        '-allowed_extensions ALL -i "$m3u8Path" -c copy -bsf:a aac_adtstoasc "$outputPath" -y';
    _log.i('export: ffmpeg cmd=$cmd');

    try {
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        final outFile = File(outputPath);
        if (await outFile.exists()) {
          final size = await outFile.length();
          _log.i('export: success, output=$outputPath, size=$size');
          return ExportResult(success: true, outputPath: outputPath);
        }
        return ExportResult(success: false, error: '输出文件未生成');
      } else {
        final logs = await session.getAllLogsAsString();
        _log.e('export: ffmpeg failed, rc=$rc, logs=$logs');
        return ExportResult(success: false, error: '导出失败: $logs');
      }
    } catch (e, stack) {
      _log.e('export: exception', e, stack);
      return ExportResult(success: false, error: e.toString());
    }
  }
}
