import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/compression_test.dart';
import 'package:huangguo_flutter/services/compression_failure_details.dart';
import 'package:huangguo_flutter/services/compression_ffmpeg_runner.dart';
import 'package:huangguo_flutter/services/compression_test_engine.dart';

class RemuxRunner implements CompressionCommandRunner {
  List<String> command = [];

  @override
  Future<String> execute(
    List<String> arguments, {
    void Function(CompressionEncodingProgress)? onProgress,
    Duration? timeout,
  }) async {
    command = arguments;
    return '';
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  test('MP4 sampling omits HLS-only demuxer options', () async {
    final runner = RemuxRunner();
    final engine = FFmpegCompressionTestEngine(runner: runner);
    await engine.remux('source.mp4', 'sample.mp4', seconds: 30);
    expect(runner.command, isNot(contains('-allowed_extensions')));
    expect(runner.command, containsAllInOrder(['-t', '30.0']));
    expect(runner.command, containsAllInOrder(['-c', 'copy']));
  });

  test('HLS remux retains local encrypted segment support', () async {
    final runner = RemuxRunner();
    await FFmpegCompressionTestEngine(
      runner: runner,
    ).remux('source.m3u8', 'original.mp4');
    expect(runner.command, containsAllInOrder(['-allowed_extensions', 'ALL']));
    expect(
      runner.command,
      containsAllInOrder(['-protocol_whitelist', 'file,crypto,data']),
    );
  });

  test(
    'failure explanation keeps actionable diagnostics and bounds length',
    () {
      expect(
        CompressionFailureDetails.describe(
          'ffmpeg version 6.0\nOption allowed_extensions not found.\n',
        ),
        'Option allowed_extensions not found.',
      );
      expect(CompressionFailureDetails.describe(null), contains('未提供'));
      expect(
        CompressionFailureDetails.describe('Error: ${'x' * 2000}').length,
        600,
      );
    },
  );
}
