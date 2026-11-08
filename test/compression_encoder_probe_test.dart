import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/compression_test.dart';
import 'package:huangguo_flutter/services/compression_encoder_probe.dart';
import 'package:huangguo_flutter/services/compression_ffmpeg_runner.dart';

import 'helpers/compression_test_fixture.dart';

class ProbeRunner implements CompressionCommandRunner {
  final supported = <String>{};
  final tried = <String>[];
  final commands = <List<String>>[];
  bool cancelProbe = false;
  Duration? probeTimeout;
  static const encoders =
      ' V....D hevc_videotoolbox encoder\n'
      ' V....D h264_videotoolbox encoder\n'
      ' V....D libx265 encoder\n'
      ' V....D libx264 encoder\n';

  @override
  Future<String> execute(
    List<String> arguments, {
    void Function(CompressionEncodingProgress)? onProgress,
    Duration? timeout,
  }) async {
    if (arguments.contains('-encoders')) return encoders;
    probeTimeout = timeout;
    commands.add(arguments);
    final encoder = arguments[arguments.indexOf('-c:v') + 1];
    tried.add(encoder);
    if (cancelProbe) throw const CompressionCancelled();
    if (!supported.contains(encoder)) {
      throw const CompressionEncodingFailure('测试硬件不可用');
    }
    await File(arguments.last).writeAsBytes([1]);
    return '';
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  late Directory root;
  late ProbeRunner runner;
  late CompressionEncoderProbe probe;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('compression_probe_');
    runner = ProbeRunner();
    probe = CompressionEncoderProbe(runner, allowHardware: true);
    await probe.load();
  });
  tearDown(() => root.delete(recursive: true));

  test('uses verified HEVC hardware with software fallback disabled', () async {
    runner.supported.add('hevc_videotoolbox');
    final presets = await probe.verify(
      'source.mp4',
      FakeCompressionEngine.sourceMedia,
      root.path,
    );
    expect(presets.first.hardware, isTrue);
    expect(presets.first.encoder, 'hevc_videotoolbox');
    expect(runner.tried, [
      'libx265',
      'hevc_videotoolbox',
      'h264_videotoolbox',
      'libx264',
    ]);
    expect(runner.commands[1], containsAllInOrder(['-allow_sw', '0']));
    expect(await root.list().length, 0);
  });

  test('tries H264 when HEVC is listed but cannot encode the source', () async {
    runner.supported.add('h264_videotoolbox');
    final presets = await probe.verify(
      'source.mp4',
      FakeCompressionEngine.sourceMedia,
      root.path,
    );
    expect(presets.first.encoder, 'h264_videotoolbox');
    expect(runner.tried, [
      'libx265',
      'hevc_videotoolbox',
      'h264_videotoolbox',
      'libx264',
    ]);
  });

  test('keeps software high compression alongside verified hardware', () async {
    runner.supported.addAll(['libx265', 'libx264', 'hevc_videotoolbox']);
    final presets = await probe.verify(
      'source.mp4',
      FakeCompressionEngine.sourceMedia,
      root.path,
    );
    expect(presets.first.encoder, 'libx265');
    expect(presets.where((preset) => preset.sizeRatio != null).length, 3);
    expect(presets.any((preset) => preset.hardware), isTrue);
    expect(presets.any((preset) => preset.encoder == 'libx264'), isTrue);
    expect(presets.first.modeLabel, contains('速度较慢'));
    expect(
      presets.first.arguments(FakeCompressionEngine.sourceMedia),
      containsAllInOrder(['-preset', 'medium']),
    );
    expect(
      probe.unavailableReasons.any((reason) => reason.contains('SVT-AV1')),
      isTrue,
    );
  });

  test('cancelling a hardware probe never starts a fallback', () async {
    runner.cancelProbe = true;
    await expectLater(
      probe.verify('source.mp4', FakeCompressionEngine.sourceMedia, root.path),
      throwsA(isA<CompressionCancelled>()),
    );
    expect(runner.tried, ['libx265']);
  });

  test('hardware bitrate follows source and selected quality', () {
    const source = CompressionMedia(
      seconds: 30,
      width: 1920,
      height: 1080,
      hasAudio: true,
      videoBitrate: 2000000,
    );
    const clear = CompressionPreset('清晰优先', 'hevc_videotoolbox', 20);
    const small = CompressionPreset('体积优先', 'hevc_videotoolbox', 25);
    expect(clear.targetBitrate(source), 1600000);
    expect(small.targetBitrate(source), 1100000);
  });
}
