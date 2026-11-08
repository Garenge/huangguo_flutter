import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/compression_encoding_plan.dart';
import 'package:huangguo_flutter/models/compression_test.dart';

const source = CompressionMedia(
  seconds: 1200,
  width: 1920,
  height: 1080,
  frameRate: 60,
  hasAudio: true,
);

void main() {
  test(
    'AV1 uses libaom when SVT is absent and selects its own speed options',
    () {
      final presets = CompressionPreset.fromEncoders(
        ' V....D libaom-av1 encoder',
      );
      expect(presets.length, 2);
      expect(presets.first.av1, isTrue);
      expect(presets.first.encoder, 'libaom-av1');
      final arguments = presets.first.arguments(source);
      expect(arguments, containsAllInOrder(['-cpu-used', '6']));
      expect(arguments, containsAllInOrder(['-b:v', '0']));
      expect(arguments, isNot(contains('-preset')));
      final preferred = CompressionPreset.fromEncoders(
        ' V....D libaom-av1 encoder\n V..... libsvtav1 encoder',
      );
      expect(preferred.first.encoder, 'libsvtav1');
    },
  );

  test('budgets total bytes including audio and mux overhead', () {
    const preset = CompressionPreset('25%', 'libx265', 26, sizeRatio: .25);
    final plan = CompressionEncodingPlan(preset, source, 600000000);
    expect(plan.targetBytes, 150000000);
    expect(plan.videoBitrate, 874000);
    expect(plan.filters, isEmpty);
    final silent = CompressionEncodingPlan(
      preset,
      const CompressionMedia(
        seconds: 1200,
        width: 1920,
        height: 1080,
        hasAudio: false,
      ),
      600000000,
    );
    expect(silent.videoBitrate, plan.videoBitrate + 96000);
  });

  test('limits landscape and portrait short edge without upscaling', () {
    const preset = CompressionPreset(
      '10%',
      'libx265',
      34,
      sizeRatio: .1,
      maxShortEdge: 540,
      maxFrameRate: 24,
      audioKbps: 48,
    );
    final plan = CompressionEncodingPlan(preset, source, 600000000);
    expect(plan.expected.width, 960);
    expect(plan.expected.height, 540);
    expect(plan.expected.frameRate, 24);
    expect(plan.filters.last, 'scale=960:540:flags=lanczos,fps=24.0');
    final portrait = CompressionEncodingPlan(
      preset,
      const CompressionMedia(
        seconds: 30,
        width: 1080,
        height: 1920,
        frameRate: 30,
        hasAudio: true,
      ),
      10000000,
    );
    expect(portrait.expected.width, 540);
    expect(portrait.expected.height, 960);
    final small = CompressionEncodingPlan(
      preset,
      const CompressionMedia(
        seconds: 30,
        width: 640,
        height: 360,
        frameRate: 15,
        hasAudio: true,
      ),
      10000000,
    );
    expect(small.filters, isEmpty);
    expect(small.expected.frameRate, 15);
    plan.validate(plan.expected);
    expect(() => plan.validate(source), throwsStateError);
  });

  test('rejects impossible budgets and identifies target misses', () {
    const preset = CompressionPreset('10%', 'libx265', 34, sizeRatio: .1);
    expect(
      () => CompressionEncodingPlan(preset, source, 100000).videoBitrate,
      throwsStateError,
    );
    const result = CompressionTestResult(
      path: 'result',
      bytes: 130,
      elapsed: Duration.zero,
      preset: preset,
      range: CompressionTestRange.full,
      sourceBytes: 1000,
      seconds: 30,
      targetBytes: 100,
    );
    expect(result.targetMet, isFalse);
    expect(result.targetDeviation, closeTo(30, .001));
  });
}
