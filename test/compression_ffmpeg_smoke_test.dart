import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/compression_encoding_plan.dart';
import 'package:huangguo_flutter/models/compression_test.dart';
import 'package:huangguo_flutter/services/compression_encoding_job.dart';
import 'package:huangguo_flutter/services/compression_test_engine.dart';

import 'helpers/compression_job_runner.dart';

void main() {
  test(
    'FFmpeg encodes three target tiers and available AV1 with real media',
    () async {
      final root = await Directory.systemTemp.createTemp('compression_real_');
      addTearDown(() => root.delete(recursive: true));
      final runner = SystemCompressionRunner();
      final input = '${root.path}/source.mp4';
      await runner.execute([
        '-v',
        'error',
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=1280x720:rate=60',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:sample_rate=48000',
        '-t',
        '4',
        '-c:v',
        'libx264',
        '-preset',
        'ultrafast',
        '-crf',
        '10',
        '-c:a',
        'aac',
        input,
      ]);
      final sourceBytes = await File(input).length();
      final sample = '${root.path}/sample.mp4';
      await FFmpegCompressionTestEngine(
        runner: runner,
      ).remux(input, sample, seconds: 1);
      expect(await File(sample).length(), greaterThan(0));
      const media = CompressionMedia(
        seconds: 4,
        width: 1280,
        height: 720,
        frameRate: 60,
        hasAudio: true,
      );
      final encoders = await runner.execute(['-hide_banner', '-encoders']);
      final presets = CompressionPreset.fromEncoders(
        encoders,
      ).where((preset) => preset.sizeRatio != null || preset.av1).toList();
      expect(presets.where((preset) => preset.sizeRatio != null).length, 3);
      for (final preset in presets) {
        final output = '${root.path}/${preset.id}.mp4';
        final plan = CompressionEncodingPlan(preset, media, sourceBytes);
        await CompressionEncodingJob(runner).run(input, output, plan, (_) {});
        final probe = await Process.run('ffprobe', [
          '-v',
          'error',
          '-show_streams',
          '-show_format',
          '-of',
          'json',
          output,
        ]);
        expect(probe.exitCode, 0);
        final info = jsonDecode(probe.stdout as String) as Map<String, dynamic>;
        final streams = (info['streams'] as List).cast<Map<String, dynamic>>();
        final video = streams.firstWhere(
          (stream) => stream['codec_type'] == 'video',
        );
        final rate = (video['avg_frame_rate'] as String)
            .split('/')
            .map(double.parse)
            .toList();
        plan.validate(
          CompressionMedia(
            seconds: double.parse(info['format']['duration'] as String),
            width: video['width'] as int,
            height: video['height'] as int,
            hasAudio: streams.any((stream) => stream['codec_type'] == 'audio'),
            frameRate: rate[0] / rate[1],
          ),
        );
        final bytes = await File(output).length();
        expect(bytes, lessThan(sourceBytes));
        if (plan.targetBytes case final target?) {
          expect((bytes / target - 1).abs(), lessThanOrEqualTo(.10));
        }
        final decoded = await Process.run('ffmpeg', [
          '-v',
          'error',
          '-i',
          output,
          '-f',
          'null',
          '-',
        ]);
        expect(decoded.exitCode, 0, reason: '${decoded.stderr}');
        stdout.writeln(
          'compression_ffmpeg_smoke_test.dart smoke: '
          '${preset.label}, source=$sourceBytes, output=$bytes, '
          'target=${plan.targetBytes}, dimensions=${video["width"]}x${video["height"]}, fps=${rate[0] / rate[1]}',
        );
      }
      expect(
        await root.list().any((file) => file.path.contains('.stats')),
        isFalse,
      );
    },
    skip: Platform.environment['RUN_COMPRESSION_FFMPEG_SMOKE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
