import 'dart:io';

import 'package:huangguo_flutter/models/compression_test.dart';
import 'package:huangguo_flutter/services/compression_ffmpeg_runner.dart';

class RecordingCompressionRunner implements CompressionCommandRunner {
  final commands = <List<String>>[];
  bool cancelFirstPass = false;
  bool failSecondPass = false;

  @override
  Future<String> execute(
    List<String> arguments, {
    void Function(CompressionEncodingProgress)? onProgress,
    Duration? timeout,
  }) async {
    commands.add(arguments);
    final params = arguments[arguments.indexOf('-x265-params') + 1];
    final stats = params.substring(params.indexOf('stats=') + 6);
    if (commands.length == 1) {
      await File(stats).writeAsString('stats');
      await File('$stats.cutree').writeAsString('cutree');
      onProgress?.call(
        const CompressionEncodingProgress(seconds: 30, speed: 2),
      );
      if (cancelFirstPass) throw const CompressionCancelled();
    } else {
      expectStatsExists(stats);
      if (failSecondPass) {
        throw const CompressionEncodingFailure('second pass failed');
      }
      onProgress?.call(
        const CompressionEncodingProgress(seconds: 15, speed: 1),
      );
      onProgress?.call(
        const CompressionEncodingProgress(seconds: 0, finalizing: true),
      );
    }
    return '';
  }

  void expectStatsExists(String path) {
    if (!File(path).existsSync()) throw StateError('两遍编码统计文件丢失');
  }

  @override
  Future<void> cancel() async {}
}

class SystemCompressionRunner implements CompressionCommandRunner {
  @override
  Future<String> execute(
    List<String> arguments, {
    void Function(CompressionEncodingProgress)? onProgress,
    Duration? timeout,
  }) async {
    final executable =
        Platform.environment['COMPRESSION_FFMPEG_EXECUTABLE'] ?? 'ffmpeg';
    final result = await Process.run(executable, arguments);
    if (result.exitCode != 0) {
      throw StateError('FFmpeg smoke encoding failed: ${result.stderr}');
    }
    return '${result.stdout}\n${result.stderr}';
  }

  @override
  Future<void> cancel() async {}
}
