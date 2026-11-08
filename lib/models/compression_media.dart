class CompressionMedia {
  const CompressionMedia({
    required this.seconds,
    required this.width,
    required this.height,
    required this.hasAudio,
    this.videoBitrate = 0,
    this.frameRate = 30,
  });

  final double seconds;
  final int width;
  final int height;
  final bool hasAudio;
  final int videoBitrate;
  final double frameRate;

  void validateAgainst(CompressionMedia source, {bool checkFrameRate = false}) {
    final tolerance = source.seconds * .01;
    if ((seconds - source.seconds).abs() > (tolerance < 1 ? 1 : tolerance) ||
        width != source.width ||
        height != source.height ||
        hasAudio != source.hasAudio ||
        (checkFrameRate && (frameRate - source.frameRate).abs() > .2)) {
      throw StateError('压缩文件的时长、分辨率、帧率或音轨与方案预期不符');
    }
  }
}
