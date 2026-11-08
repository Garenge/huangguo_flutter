import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/compression_test.dart';
import 'package:huangguo_flutter/services/compression_progress_tracker.dart';

void main() {
  test(
    'shows zero initially, speed and ETA, then 100 only after validation',
    () {
      final tracker = CompressionProgressTracker(() {});
      addTearDown(tracker.stop);
      tracker.start(30);
      expect(tracker.fraction, 0);
      expect(tracker.remaining, isNull);
      tracker.update(const CompressionEncodingProgress(seconds: 10, speed: 2));
      expect(tracker.fraction, closeTo(1 / 3, .001));
      expect(tracker.remaining, const Duration(seconds: 10));
      tracker.update(const CompressionEncodingProgress(seconds: 30, speed: 2));
      expect(tracker.fraction, lessThan(1));
      tracker.finishEncoding();
      expect(tracker.remaining, isNull);
      tracker.validating();
      expect(tracker.fraction, .99);
      tracker.complete();
      expect(tracker.fraction, 1);
      expect(tracker.encoding, isFalse);
    },
  );

  test('late or regressing statistics cannot undo completed progress', () {
    final tracker = CompressionProgressTracker(() {});
    addTearDown(tracker.stop);
    tracker.start(30);
    tracker.update(const CompressionEncodingProgress(seconds: 20));
    tracker.update(const CompressionEncodingProgress(seconds: 10));
    expect(tracker.processedSeconds, 20);
    tracker.complete();
    tracker.update(const CompressionEncodingProgress(seconds: 1));
    expect(tracker.fraction, 1);
  });

  test(
    'parses normal FFmpeg status as a fallback for statistics callbacks',
    () {
      final value = CompressionEncodingProgress.fromLog(
        'frame= 144 fps=24 time=00:01:02.50 bitrate=800kbits/s speed= 1.25x',
      )!;
      expect(value.seconds, 62.5);
      expect(value.speed, 1.25);
      expect(CompressionEncodingProgress.fromLog('time=N/A speed=N/A'), isNull);
      expect(
        CompressionEncodingProgress.fromLog(
          '[mp4] Starting second pass: moving the moov atom to the beginning',
        )!.finalizing,
        isTrue,
      );
    },
  );
}
