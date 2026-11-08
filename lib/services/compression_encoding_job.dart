import 'dart:io';

import '../models/compression_encoding_plan.dart';
import '../models/compression_test.dart';
import 'compression_ffmpeg_runner.dart';

class CompressionEncodingJob {
  CompressionEncodingJob(this.runner);

  final CompressionCommandRunner runner;

  Future<void> run(
    String source,
    String output,
    CompressionEncodingPlan plan,
    void Function(CompressionEncodingProgress) onProgress,
  ) async {
    final preset = plan.preset;
    final stats = '$output.x265.stats';
    final bitrate = preset.passes == 2 ? plan.videoBitrate : null;
    try {
      for (var pass = 1; pass <= preset.passes; pass++) {
        onProgress(
          CompressionEncodingProgress(
            seconds: (pass - 1) * plan.source.seconds,
            pass: pass,
            passes: preset.passes,
          ),
        );
        await runner.execute(
          arguments(source, output, plan, pass, stats, bitrate),
          onProgress: (value) => onProgress(
            CompressionEncodingProgress(
              seconds:
                  (pass - 1) * plan.source.seconds +
                  value.seconds.clamp(0, plan.source.seconds),
              speed: value.speed,
              finalizing: value.finalizing && pass == preset.passes,
              pass: pass,
              passes: preset.passes,
            ),
          ),
        );
      }
    } finally {
      for (final suffix in ['', '.cutree', '.temp', '.cutree.temp']) {
        final file = File('$stats$suffix');
        if (await file.exists()) await file.delete();
      }
    }
  }

  List<String> arguments(
    String source,
    String output,
    CompressionEncodingPlan plan,
    int pass,
    String stats,
    int? bitrate,
  ) {
    final preset = plan.preset;
    final firstPass = preset.passes == 2 && pass == 1;
    final escapedStats = stats.replaceAll('\\', '\\\\').replaceAll(':', '\\:');
    return [
      '-v',
      'info',
      '-stats',
      '-stats_period',
      '0.5',
      '-y',
      '-i',
      source,
      '-map',
      '0:v:0',
      if (!firstPass) ...['-map', '0:a:0?'],
      if (bitrate == null)
        ...preset.arguments(plan.source)
      else ...[
        '-c:v',
        'libx265',
        '-preset',
        preset.speedPreset,
        '-b:v',
        '$bitrate',
        '-x265-params',
        'pass=$pass:stats=$escapedStats',
        '-tag:v',
        'hvc1',
      ],
      ...plan.filters,
      '-fps_mode:v',
      'passthrough',
      if (firstPass) ...[
        '-an',
        '-f',
        'null',
        '-',
      ] else ...[
        if (preset.sizeRatio != null) ...[
          '-c:a',
          'aac',
          '-b:a',
          '${preset.audioKbps}k',
        ] else ...[
          '-c:a',
          'copy',
        ],
        '-movflags',
        '+faststart',
        output,
      ],
    ];
  }
}
