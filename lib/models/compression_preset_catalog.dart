import 'compression_preset.dart';

abstract final class CompressionPresetCatalog {
  static List<List<CompressionPreset>> candidates(
    String output, {
    required bool allowHardware,
  }) {
    final names = RegExp(
      r'^\s*V\S{5}\s+(\S+)',
      multiLine: true,
    ).allMatches(output).map((match) => match.group(1)).toSet();
    return [
      if (names.contains('libx265')) _hevc(),
      if (allowHardware)
        for (final encoder in ['hevc_videotoolbox', 'h264_videotoolbox'])
          if (names.contains(encoder)) _standard(encoder),
      if (names.contains('libx264')) _standard('libx264'),
      if (names.contains('libsvtav1') || names.contains('libaom-av1'))
        _av1(names.contains('libsvtav1') ? 'libsvtav1' : 'libaom-av1'),
    ];
  }

  static List<CompressionPreset> _av1(String encoder) => [
    CompressionPreset('AV1 高压缩实验', encoder, 36),
    CompressionPreset('AV1 极限压缩实验', encoder, 40),
  ];

  static List<CompressionPreset> _standard(String encoder) => [
    CompressionPreset('清晰优先', encoder, encoder.contains('264') ? 18 : 20),
    CompressionPreset('体积优先', encoder, encoder.contains('264') ? 28 : 25),
  ];

  static List<CompressionPreset> _hevc() => [
    const CompressionPreset('强力压缩 · 25%', 'libx265', 26, sizeRatio: .25),
    const CompressionPreset(
      '激进压缩 · 15%',
      'libx265',
      30,
      sizeRatio: .15,
      maxShortEdge: 720,
      maxFrameRate: 30,
      audioKbps: 64,
    ),
    const CompressionPreset(
      '极限压缩 · 10%',
      'libx265',
      34,
      sizeRatio: .10,
      maxShortEdge: 540,
      maxFrameRate: 24,
      audioKbps: 48,
    ),
    ..._standard('libx265'),
  ];
}
