class CompressionEncodingProgress {
  const CompressionEncodingProgress({
    required this.seconds,
    this.speed = 0,
    this.finalizing = false,
    this.pass = 1,
    this.passes = 1,
  });

  final double seconds;
  final double speed;
  final bool finalizing;
  final int pass;
  final int passes;

  static CompressionEncodingProgress? fromLog(String message) {
    if (message.contains('moving the moov atom')) {
      return const CompressionEncodingProgress(seconds: 0, finalizing: true);
    }
    final match = RegExp(
      r'time=(\d+):(\d+):(\d+(?:\.\d+)?)',
    ).firstMatch(message);
    if (match == null) return null;
    final seconds =
        int.parse(match[1]!) * 3600 +
        int.parse(match[2]!) * 60 +
        double.parse(match[3]!);
    final speed =
        double.tryParse(
          RegExp(r'speed=\s*([\d.]+)x').firstMatch(message)?[1] ?? '',
        ) ??
        0;
    return CompressionEncodingProgress(seconds: seconds, speed: speed);
  }
}
