import 'compression_media.dart';
import 'compression_preset_catalog.dart';

class CompressionPreset {
  const CompressionPreset(
    this.label,
    this.encoder,
    this.quality, {
    this.sizeRatio,
    this.maxShortEdge,
    this.maxFrameRate,
    this.audioKbps = 96,
  });

  final String label;
  final String encoder;
  final int quality;
  final double? sizeRatio;
  final int? maxShortEdge;
  final int? maxFrameRate;
  final int audioKbps;

  String get id => '${encoder}_${quality}_${sizeRatio ?? "crf"}';
  bool get hardware => encoder.endsWith('_videotoolbox');
  bool get av1 => encoder == 'libsvtav1' || encoder == 'libaom-av1';
  String get speedOption => encoder == 'libaom-av1' ? 'cpu-used' : 'preset';
  int get passes => sizeRatio == null ? 1 : 2;
  String get speedPreset => hardware ? '' : (av1 ? '6' : 'medium');
  String get codecLabel =>
      av1 ? 'AV1' : (encoder.contains('264') ? 'H.264' : 'H.265');
  String get modeLabel => hardware ? '硬件加速' : '软件压缩，速度较慢';
  String get description => sizeRatio != null
      ? '$codecLabel · 两遍编码，目标为原体积 ${(sizeRatio! * 100).round()}%（允许 ±10% 偏差）'
            ' · ${maxShortEdge == null ? "保留分辨率" : "短边最高 ${maxShortEdge}p"}'
            ' · ${maxFrameRate == null ? "保留帧率" : "最高 $maxFrameRate fps"}'
            ' · AAC $audioKbps kbps，画质会下降'
      : '$codecLabel · $modeLabel · ${hardware ? "目标码率" : "CRF $quality / $speedOption $speedPreset"}'
            '${av1 ? " · $encoder" : ""}'
            ' · 保留分辨率和帧率${av1 ? "，实验方案，预览取决于设备解码能力" : ""}';

  List<String> arguments(CompressionMedia media) => [
    '-c:v',
    encoder,
    if (hardware) ...[
      '-allow_sw',
      '0',
      '-realtime',
      '1',
      '-b:v',
      '${targetBitrate(media)}',
    ] else if (encoder == 'libaom-av1') ...[
      '-cpu-used',
      speedPreset,
      '-crf',
      '$quality',
      '-b:v',
      '0',
      '-row-mt',
      '1',
      '-threads',
      '4',
    ] else ...[
      '-preset',
      speedPreset,
      '-crf',
      '$quality',
      '-threads',
      '0',
    ],
    if (encoder.contains('265') || encoder.startsWith('hevc_')) ...[
      '-tag:v',
      'hvc1',
    ],
  ];

  int targetBitrate(CompressionMedia media) {
    final sourceRate = media.videoBitrate > 0
        ? media.videoBitrate
        : media.width * media.height * media.frameRate * .10;
    final factor = label == '清晰优先' ? .80 : .55;
    return (sourceRate * factor).round().clamp(64000, 100000000);
  }

  static List<List<CompressionPreset>> candidates(
    String output, {
    required bool allowHardware,
  }) {
    return CompressionPresetCatalog.candidates(
      output,
      allowHardware: allowHardware,
    );
  }

  static List<CompressionPreset> fromEncoders(String output) => candidates(
    output,
    allowHardware: false,
  ).expand((group) => group).toList();
}
