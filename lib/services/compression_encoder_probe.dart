import 'dart:io';

import '../models/compression_test.dart';
import 'app_log.dart';
import 'compression_ffmpeg_runner.dart';

/// 使用当前素材试编码，不能仅凭编码器列表认定硬件可用。
class CompressionEncoderProbe {
  CompressionEncoderProbe(this.runner, {bool? allowHardware})
    : allowHardware = allowHardware ?? (Platform.isMacOS || Platform.isIOS);

  final CompressionCommandRunner runner;
  final bool allowHardware;
  List<List<CompressionPreset>> _candidates = [];
  final List<String> unavailableReasons = [];
  List<String> _missing = [];

  Future<List<CompressionPreset>> load() async {
    final output = await runner.execute(['-hide_banner', '-encoders']);
    _candidates = CompressionPreset.candidates(
      output,
      allowHardware: allowHardware,
    );
    _missing = [
      if (!_candidates.any((group) => group.first.encoder == 'libx265'))
        '当前编码组件不包含 x265，25% / 15% / 10% 目标体积方案不可用。',
      if (!_candidates.any((group) => group.first.av1))
        '当前编码组件不包含 SVT-AV1 或 libaom-av1，AV1 实验方案不可用。',
    ];
    unavailableReasons
      ..clear()
      ..addAll(_missing);
    return _candidates.expand((group) => group).toList();
  }

  Future<List<CompressionPreset>> verify(
    String source,
    CompressionMedia media,
    String directory,
  ) async {
    final output = File('$directory/encoder_probe.mp4');
    final available = <CompressionPreset>[];
    unavailableReasons
      ..clear()
      ..addAll(_missing);
    for (final group in _candidates) {
      try {
        await _tryEncoder(source, media, output.path, group.first);
        if (!await output.exists() || await output.length() == 0) {
          throw const CompressionEncodingFailure('试编码未生成有效文件');
        }
        available.addAll(group);
      } on CompressionEncodingFailure catch (error) {
        unavailableReasons.add('${group.first.encoder} 在当前素材上试编码失败：$error');
        const AppLog(
          'compression_encoder_probe.dart',
        ).w('verify: 当前素材试编码不可用，编码器=${group.first.encoder}，原因=$error');
      } finally {
        if (await output.exists()) await output.delete();
      }
    }
    return available;
  }

  Future<void> _tryEncoder(
    String source,
    CompressionMedia media,
    String output,
    CompressionPreset preset,
  ) async {
    await runner.execute([
      '-v',
      'error',
      '-y',
      '-i',
      source,
      '-map',
      '0:v:0',
      '-an',
      ...preset.arguments(media),
      '-frames:v',
      '3',
      output,
    ], timeout: Duration(seconds: preset.hardware ? 8 : 30));
  }
}
