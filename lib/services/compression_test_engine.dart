import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';

import '../models/compression_test.dart';
import '../models/compression_encoding_plan.dart';
import 'compression_encoding_job.dart';
import 'compression_ffmpeg_runner.dart';
import 'compression_encoder_probe.dart';

abstract class CompressionTestEngine {
  List<String> get unavailableReasons;
  Future<List<CompressionPreset>> presets();
  Future<List<CompressionPreset>> verifyPresets(
    String source,
    CompressionMedia media,
    String directory,
  );
  Future<CompressionMedia> inspect(String path);
  Future<void> remux(String source, String output, {double? seconds});
  Future<void> compress(
    String source,
    String output,
    CompressionPreset preset,
    CompressionMedia media,
    void Function(CompressionEncodingProgress progress) onProgress, {
    int sourceBytes = 0,
  });
  Future<void> cancel();
}

class FFmpegCompressionTestEngine implements CompressionTestEngine {
  FFmpegCompressionTestEngine({CompressionCommandRunner? runner})
    : _runner = runner ?? CompressionFFmpegRunner();

  final CompressionCommandRunner _runner;
  late final CompressionEncoderProbe _probe = CompressionEncoderProbe(_runner);

  @override
  List<String> get unavailableReasons => _probe.unavailableReasons;

  @override
  Future<List<CompressionPreset>> presets() => _probe.load();

  @override
  Future<List<CompressionPreset>> verifyPresets(
    String source,
    CompressionMedia media,
    String directory,
  ) => _probe.verify(source, media, directory);

  @override
  Future<CompressionMedia> inspect(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    final streams = info?.getStreams() ?? [];
    final videos = streams.where((stream) => stream.getType() == 'video');
    final seconds = double.tryParse(info?.getDuration() ?? '') ?? 0;
    if (videos.isEmpty || !seconds.isFinite || seconds <= 0) {
      throw StateError('无法读取视频轨道或有效时长');
    }
    final video = videos.first;
    return CompressionMedia(
      seconds: seconds,
      width: video.getWidth() ?? 0,
      height: video.getHeight() ?? 0,
      hasAudio: streams.any((stream) => stream.getType() == 'audio'),
      videoBitrate:
          int.tryParse(video.getBitrate() ?? '') ??
          ((int.tryParse(info?.getBitrate() ?? '') ?? 0) -
              streams
                  .where((stream) => stream.getType() == 'audio')
                  .fold<int>(
                    0,
                    (sum, stream) =>
                        sum + (int.tryParse(stream.getBitrate() ?? '') ?? 0),
                  )),
      frameRate: _frameRate(video.getAverageFrameRate()),
    );
  }

  double _frameRate(String? value) {
    final parts = value?.split('/') ?? [];
    if (parts.length != 2) return 30;
    final denominator = double.tryParse(parts[1]) ?? 0;
    final fps = denominator > 0
        ? (double.tryParse(parts[0]) ?? 0) / denominator
        : 0.0;
    return fps > 0 && fps.isFinite ? fps : 30.0;
  }

  @override
  Future<void> remux(String source, String output, {double? seconds}) async {
    await _runner.execute([
      '-v',
      'error',
      '-y',
      if (source.toLowerCase().endsWith('.m3u8')) ...[
        '-allowed_extensions',
        'ALL',
      ],
      '-protocol_whitelist',
      'file,crypto,data',
      '-i',
      source,
      '-map',
      '0:v:0',
      '-map',
      '0:a:0?',
      '-c',
      'copy',
      if (seconds != null) ...[
        '-t',
        '$seconds',
        '-avoid_negative_ts',
        'make_zero',
      ],
      output,
    ]);
  }

  @override
  Future<void> compress(
    String source,
    String output,
    CompressionPreset preset,
    CompressionMedia media,
    void Function(CompressionEncodingProgress progress) onProgress, {
    int sourceBytes = 0,
  }) async {
    await CompressionEncodingJob(_runner).run(
      source,
      output,
      CompressionEncodingPlan(preset, media, sourceBytes),
      onProgress,
    );
  }

  @override
  Future<void> cancel() => _runner.cancel();
}
