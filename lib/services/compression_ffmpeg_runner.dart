import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../models/compression_test.dart';
import 'app_log.dart';
import 'compression_failure_details.dart';

abstract class CompressionCommandRunner {
  Future<String> execute(
    List<String> arguments, {
    void Function(CompressionEncodingProgress)? onProgress,
    Duration? timeout,
  });
  Future<void> cancel();
}

class CompressionFFmpegRunner implements CompressionCommandRunner {
  int? _sessionId;
  bool _cancelled = false;

  @override
  Future<String> execute(
    List<String> arguments, {
    void Function(CompressionEncodingProgress)? onProgress,
    Duration? timeout,
  }) async {
    if (_cancelled) throw const CompressionCancelled();
    var timedOut = false;
    var acceptingProgress = true;
    final completed = Completer<FFmpegSession>();
    final session = await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (value) {
        if (!completed.isCompleted) completed.complete(value);
      },
      (log) {
        final progress = CompressionEncodingProgress.fromLog(log.getMessage());
        if (acceptingProgress && !_cancelled && progress != null) {
          onProgress?.call(progress);
        }
      },
      (statistics) {
        if (acceptingProgress && !_cancelled) {
          onProgress?.call(
            CompressionEncodingProgress(
              seconds: statistics.getTime() / 1000,
              speed: statistics.getSpeed(),
            ),
          );
        }
      },
    );
    _sessionId = session.getSessionId();
    final timeoutTimer = timeout == null
        ? null
        : Timer(timeout, () {
            timedOut = true;
            unawaited(_cancelSession().catchError((Object _) {}));
          });
    try {
      if (_cancelled) await _cancelSession();
      final done = await completed.future;
      if (_cancelled) throw const CompressionCancelled();
      if (timedOut) throw const CompressionEncodingFailure('编码器试编码超时');
      return await _readResult(done);
    } finally {
      acceptingProgress = false;
      timeoutTimer?.cancel();
      _sessionId = null;
    }
  }

  Future<String> _readResult(FFmpegSession session) async {
    final code = await session.getReturnCode();
    if (ReturnCode.isCancel(code)) throw const CompressionCancelled();
    if (!ReturnCode.isSuccess(code)) {
      final logs = await session.getAllLogsAsString();
      const AppLog(
        'compression_ffmpeg_runner.dart',
      ).e('_readResult: 视频处理失败，返回码=$code，诊断=$logs');
      throw CompressionEncodingFailure(
        '视频处理失败：${CompressionFailureDetails.describe(logs)}',
      );
    }
    return await session.getOutput() ?? '';
  }

  Future<void> _cancelSession() async {
    final id = _sessionId;
    if (id == null) return;
    try {
      await FFmpegKit.cancel(id);
    } catch (error, stack) {
      const AppLog(
        'compression_ffmpeg_runner.dart',
      ).e('_cancelSession: 停止测试转码失败', error, stack);
      rethrow;
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    await _cancelSession();
  }
}
