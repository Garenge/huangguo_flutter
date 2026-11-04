import 'package:video_player/video_player.dart';

import '../services/library_service.dart';

/// 只有播放器确实在播放且已产生进度，才记录“看过”，不等同于看完。
void recordWatchProgress({
  required LibraryService? library,
  required VideoPlayerValue value,
  required String? dramaId,
  required String dramaName,
  required String ep,
}) {
  if (library == null ||
      !value.isInitialized ||
      !value.isPlaying ||
      value.isBuffering ||
      value.hasError ||
      value.position <= Duration.zero ||
      library.hasWatched(dramaId, dramaName, ep: ep)) {
    return;
  }
  library.markWatched(dramaId, dramaName, ep);
}
