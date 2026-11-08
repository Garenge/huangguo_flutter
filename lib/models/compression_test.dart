import 'compression_preset.dart';
import 'compression_media.dart';

export 'compression_media.dart';
export 'compression_preset.dart';
export 'compression_encoding_progress.dart';

enum CompressionTestRange {
  sample('30 秒片段'),
  full('完整一集');

  const CompressionTestRange(this.label);
  final String label;
}

class CompressionTestResult {
  const CompressionTestResult({
    required this.path,
    required this.bytes,
    required this.elapsed,
    required this.preset,
    required this.range,
    required this.sourceBytes,
    required this.seconds,
    this.targetBytes,
    this.outputMedia,
  });

  final String path;
  final int bytes;
  final Duration elapsed;
  final CompressionPreset preset;
  final CompressionTestRange range;
  final int sourceBytes;
  final double seconds;
  final int? targetBytes;
  final CompressionMedia? outputMedia;

  double? get targetDeviation =>
      targetBytes == null ? null : (bytes / targetBytes! - 1) * 100;
  bool get targetMet => targetDeviation == null || targetDeviation!.abs() <= 10;
}

class CompressionCancelled implements Exception {
  const CompressionCancelled();
}

class CompressionEncodingFailure implements Exception {
  const CompressionEncodingFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
