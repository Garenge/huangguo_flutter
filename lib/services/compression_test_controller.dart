import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/compression_test.dart';
import '../models/compression_encoding_plan.dart';
import '../models/download_task.dart';
import 'app_log.dart';
import 'compression_test_engine.dart';
import 'compression_test_workspace.dart';
import 'compression_test_source.dart';
import 'compression_progress_tracker.dart';

class CompressionTestController extends ChangeNotifier {
  CompressionTestController({
    CompressionTestEngine? engine,
    CompressionTestWorkspace? workspace,
  }) : engine = engine ?? FFmpegCompressionTestEngine(),
       workspace = workspace ?? CompressionTestWorkspace();

  final CompressionTestEngine engine;
  final CompressionTestWorkspace workspace;
  List<CompressionPreset> presets = [];
  late final source = CompressionTestSource(engine, workspace, _checkOpen);
  late final timing = CompressionProgressTracker(_notify);
  CompressionTestRange range = CompressionTestRange.sample;
  String? get sourcePath => source.path;
  int get sourceBytes => source.bytes;
  CompressionMedia? get media => source.media;
  double? get progress => timing.fraction;
  CompressionTestResult? result;
  final List<CompressionTestResult> results = [];
  int _outputSequence = 0;
  bool busy = false;
  bool ready = false;
  String status = '';
  String? error;
  bool _closing = false;
  bool _disposed = false;
  Future<void> _operation = Future.value();
  Future<void>? _closeFuture;

  Future<void> initialize() => _run('正在检查压缩能力', () async {
    await workspace.open();
    _checkOpen();
    presets = await engine.presets();
    _checkOpen();
    ready = true;
  });

  Future<void> select(DownloadTask? task) => _run('正在复制测试资源', () async {
    source.reset();
    await _clearResults();
    await workspace.clear();
    _checkOpen();
    if (task == null) return;
    presets = [];
    await source.prepare(task, range, () => _closing, _setStatus);
    _checkOpen();
    _setStatus('正在检测各方案的压缩能力');
    presets = await engine.verifyPresets(
      sourcePath!,
      media!,
      workspace.directory.path,
    );
    _checkOpen();
  });

  Future<void> changeRange(CompressionTestRange value) =>
      _run('正在准备${value.label}', () async {
        await _clearResults();
        range = value;
        await source.selectRange(value);
        _checkOpen();
      });

  void _setStatus(String message) {
    status = message;
    _notify();
  }

  Future<void> compress(CompressionPreset preset) =>
      _run('正在压缩：${preset.label}', () async {
        final input = sourcePath;
        final sourceMedia = media;
        if (input == null || sourceMedia == null) return;
        final plan = CompressionEncodingPlan(preset, sourceMedia, sourceBytes);
        if (preset.sizeRatio != null) plan.videoBitrate;
        final output =
            '${workspace.directory.path}/compressed_${++_outputSequence}.mp4';
        final file = File(output);
        _checkOpen();
        timing.start(sourceMedia.seconds * preset.passes);
        try {
          await engine.compress(input, output, preset, sourceMedia, (value) {
            timing.update(value);
            if (value.finalizing || value.seconds >= timing.totalSeconds) {
              _setStatus('正在封装视频文件');
              timing.finishEncoding();
            } else if (value.passes > 1 && timing.encoding) {
              _setStatus(
                '正在压缩：${preset.label} · 第 ${value.pass}/${value.passes} 遍',
              );
            }
          }, sourceBytes: sourceBytes);
          _checkOpen();
          timing.finishEncoding();
          _setStatus('正在验证压缩结果');
          timing.validating();
          final inspected = await engine.inspect(output);
          _checkOpen();
          plan.validate(inspected);
          final bytes = await file.length();
          if (bytes <= 0) throw StateError('压缩文件为空');
          _checkOpen();
          result = CompressionTestResult(
            path: output,
            bytes: bytes,
            elapsed: timing.elapsed,
            preset: preset,
            range: range,
            sourceBytes: sourceBytes,
            seconds: sourceMedia.seconds,
            targetBytes: plan.targetBytes,
            outputMedia: inspected,
          );
          results.add(result!);
          status = result!.targetMet ? '压缩完成' : '压缩完成，体积偏离目标';
          timing.complete();
        } finally {
          if (!results.any((entry) => entry.path == output) &&
              await file.exists()) {
            await file.delete();
          }
        }
      });

  void selectResult(CompressionTestResult value) {
    if (busy || _closing || !results.contains(value)) return;
    result = value;
    _notify();
  }

  Future<void> _clearResults() async {
    result = null;
    for (final entry in results) {
      final file = File(entry.path);
      if (await file.exists()) await file.delete();
    }
    results.clear();
  }

  Future<void> _run(String message, Future<void> Function() action) {
    if (busy || _closing) return Future.value();
    busy = true;
    status = message;
    error = null;
    timing.reset();
    _notify();
    return _operation = _guard(action);
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on CompressionCancelled {
      // 返回页面时取消属于正常结束，仍由 close 等待操作完成后清理。
    } catch (exception, stack) {
      error = '$status：$exception';
      const AppLog(
        'compression_test_controller.dart',
      ).e('_guard: 压缩测试操作失败', exception, stack);
    } finally {
      busy = false;
      timing.stop();
      _notify();
    }
  }

  void _checkOpen() {
    if (_closing) throw const CompressionCancelled();
  }

  void _notify() {
    if (!_closing && !_disposed) notifyListeners();
  }

  Future<void> close() =>
      _closeFuture ??= _close().catchError((Object error, StackTrace stack) {
        _closeFuture = null;
        Error.throwWithStackTrace(error, stack);
      });

  Future<void> _close() async {
    _closing = true;
    await engine.cancel();
    await _operation;
    await workspace.close();
  }

  @override
  void dispose() {
    _disposed = true;
    timing.stop();
    super.dispose();
  }
}
