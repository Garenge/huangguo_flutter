import 'dart:math' as math;

import 'compression_media.dart';
import 'compression_preset.dart';

/// 统一预算、缩放和校验的预期，避免编码参数与验收条件不一致。
class CompressionEncodingPlan {
  CompressionEncodingPlan(this.preset, this.source, this.sourceBytes);

  final CompressionPreset preset;
  final CompressionMedia source;
  final int sourceBytes;

  int? get targetBytes => preset.sizeRatio == null
      ? null
      : (sourceBytes * preset.sizeRatio!).floor();

  int get videoBitrate {
    final target = targetBytes;
    if (target == null || source.seconds <= 0 || sourceBytes <= 0) {
      throw StateError('无法计算目标体积，请重新选择有效的视频');
    }
    // 留出 3% 封装余量；音频始终从总预算中扣除。
    final bitrate =
        (target * 8 * .97 / source.seconds -
                (source.hasAudio ? preset.audioKbps * 1000 : 0))
            .floor();
    if (bitrate < 64000) {
      throw StateError('该档位的视频码率预算不足 64 kbps，请选择更大的目标体积');
    }
    return bitrate;
  }

  CompressionMedia get expected {
    final short = math.min(source.width, source.height);
    final cap = preset.maxShortEdge;
    final factor = cap != null && short > cap ? cap / short : 1.0;
    final resize = factor < 1;
    return CompressionMedia(
      seconds: source.seconds,
      width: resize ? _even(source.width * factor) : source.width,
      height: resize ? _even(source.height * factor) : source.height,
      hasAudio: source.hasAudio,
      frameRate: math.min(
        source.frameRate,
        preset.maxFrameRate?.toDouble() ?? source.frameRate,
      ),
    );
  }

  int _even(double value) => math.max(2, (value / 2).floor() * 2);

  List<String> get filters {
    final output = expected;
    final values = [
      if (output.width != source.width || output.height != source.height)
        'scale=${output.width}:${output.height}:flags=lanczos',
      if (output.frameRate < source.frameRate) 'fps=${output.frameRate}',
    ];
    return values.isEmpty ? [] : ['-vf', values.join(',')];
  }

  void validate(CompressionMedia output) {
    output.validateAgainst(
      expected,
      checkFrameRate: preset.maxFrameRate != null,
    );
  }
}
