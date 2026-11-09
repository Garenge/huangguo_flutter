import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_log.dart';

/// Native code preserves the original title for the entire fullscreen session.
class PlaybackWindowTitle {
  static const channel = MethodChannel('huangguo/playback_window');

  static Future<void> update(String? title) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      await channel.invokeMethod<void>('setPlaybackTitle', title);
    } catch (error, stack) {
      const AppLog(
        'playback_window_title.dart',
      ).e('update: 更新播放窗口标题失败', error, stack);
    }
  }
}
