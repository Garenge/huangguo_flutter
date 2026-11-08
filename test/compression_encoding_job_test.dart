import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/compression_encoding_plan.dart';
import 'package:huangguo_flutter/models/compression_test.dart';
import 'package:huangguo_flutter/services/compression_encoding_job.dart';

import 'helpers/compression_job_runner.dart';

void main() {
  late Directory root;
  late RecordingCompressionRunner runner;
  late CompressionEncodingJob job;
  late CompressionEncodingPlan plan;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('compression_job_');
    runner = RecordingCompressionRunner();
    job = CompressionEncodingJob(runner);
    plan = CompressionEncodingPlan(
      const CompressionPreset(
        '15%',
        'libx265',
        30,
        sizeRatio: .15,
        maxShortEdge: 720,
        maxFrameRate: 30,
        audioKbps: 64,
      ),
      const CompressionMedia(
        seconds: 30,
        width: 1920,
        height: 1080,
        frameRate: 60,
        hasAudio: true,
      ),
      100000000,
    );
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'shares pass statistics, filters and bitrate, and keeps progress monotonic',
    () async {
      final progress = <CompressionEncodingProgress>[];
      await job.run(
        'source.mp4',
        '${root.path}/output.mp4',
        plan,
        progress.add,
      );
      expect(runner.commands.length, 2);
      final first = runner.commands.first;
      final second = runner.commands.last;
      expect(first, containsAllInOrder(['-f', 'null', '-']));
      expect(first, contains('-an'));
      expect(first, isNot(contains('-crf')));
      expect(second, containsAllInOrder(['-c:a', 'aac', '-b:a', '64k']));
      expect(
        first[first.indexOf('-vf') + 1],
        second[second.indexOf('-vf') + 1],
      );
      expect(
        first[first.indexOf('-b:v') + 1],
        second[second.indexOf('-b:v') + 1],
      );
      expect(
        progress
            .where((value) => !value.finalizing)
            .map((value) => value.seconds),
        [0, 30, 30, 45],
      );
      expect(progress.last.finalizing, isTrue);
      expect(progress.last.pass, 2);
      expect(await root.list().length, 0);
    },
  );

  test(
    'cancelled analysis never starts second pass and removes stats',
    () async {
      runner.cancelFirstPass = true;
      await expectLater(
        job.run('source', '${root.path}/output.mp4', plan, (_) {}),
        throwsA(isA<CompressionCancelled>()),
      );
      expect(runner.commands.length, 1);
      expect(await root.list().length, 0);
    },
  );

  test('failed second pass also removes statistics', () async {
    runner.failSecondPass = true;
    await expectLater(
      job.run('source', '${root.path}/output.mp4', plan, (_) {}),
      throwsA(isA<CompressionEncodingFailure>()),
    );
    expect(await root.list().length, 0);
  });
}
