import 'dart:async';

import '../models/compression_test.dart';

class CompressionProgressTracker {
  CompressionProgressTracker(this.onChanged);

  final void Function() onChanged;
  final Stopwatch _watch = Stopwatch();
  Timer? _ticker;
  double totalSeconds = 0;
  double processedSeconds = 0;
  double _reportedSpeed = 0;
  double? fraction;
  bool encoding = false;

  Duration get elapsed => _watch.elapsed;
  double get speed => _reportedSpeed > 0
      ? _reportedSpeed
      : (elapsed.inMilliseconds > 0
            ? processedSeconds / (elapsed.inMilliseconds / 1000)
            : 0);
  Duration? get remaining => encoding && speed > 0
      ? Duration(
          milliseconds: ((totalSeconds - processedSeconds) / speed * 1000)
              .clamp(0, 2147483647)
              .round(),
        )
      : null;

  void start(double seconds) {
    reset();
    totalSeconds = seconds;
    fraction = 0;
    encoding = true;
    _watch.start();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => onChanged(),
    );
  }

  void update(CompressionEncodingProgress value) {
    if (!encoding || !value.seconds.isFinite) return;
    processedSeconds = value.seconds.clamp(processedSeconds, totalSeconds);
    if (value.speed.isFinite && value.speed > 0) _reportedSpeed = value.speed;
    fraction = (processedSeconds / totalSeconds).clamp(0, .97);
    onChanged();
  }

  void finishEncoding() {
    encoding = false;
    processedSeconds = totalSeconds;
    fraction = .98;
    onChanged();
  }

  void validating() {
    fraction = .99;
    onChanged();
  }

  void complete() {
    fraction = 1;
    stop();
    onChanged();
  }

  void stop() {
    _watch.stop();
    _ticker?.cancel();
    _ticker = null;
    encoding = false;
  }

  void reset() {
    stop();
    _watch.reset();
    totalSeconds = 0;
    processedSeconds = 0;
    _reportedSpeed = 0;
    fraction = null;
  }
}
