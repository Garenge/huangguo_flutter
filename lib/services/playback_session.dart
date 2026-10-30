import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'app_log.dart';
import 'playback_coordinator.dart';
import 'playback_settings_service.dart';

class PlaybackSession with WidgetsBindingObserver {
  PlaybackSession(this.settings, this.coordinator) {
    coordinator.register(this);
    settings.addListener(_applyVisibility);
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  final PlaybackSettingsService settings;
  final PlaybackCoordinator coordinator;
  VideoPlayerController? controller;
  bool _visible = true;
  bool _routeVisible = true;
  bool _foreground = true;
  bool _interrupted = false;
  bool _disposed = false;

  bool get canPlay =>
      !_disposed &&
      !_interrupted &&
      _foreground &&
      ((_visible && _routeVisible) || !settings.pauseOnLeave) &&
      coordinator.owns(this);

  Future<void> begin() async {
    if (_disposed) return;
    _interrupted = false;
    await coordinator.claim(this);
  }

  Future<void> attach(VideoPlayerController value) async {
    controller = value;
    await settings.load();
    if (!_disposed && controller == value) {
      await value.setPlaybackSpeed(settings.speed);
    }
  }

  void setVisible(bool value) {
    _visible = value;
    _applyVisibility();
  }

  void _applyVisibility() {
    if ((!_visible || !_routeVisible) && settings.pauseOnLeave) interrupt();
  }

  void setRouteVisible(bool value) {
    _routeVisible = value;
    _applyVisibility();
  }

  Future<void> interrupt() async {
    _interrupted = true;
    try {
      await controller?.pause();
    } catch (error, stack) {
      const AppLog(
        'playback_session.dart',
      ).e('interrupt: 暂停播放失败', error, stack);
    }
  }

  Future<void> play({bool explicit = false}) async {
    if (explicit &&
        !_disposed &&
        _foreground &&
        ((_visible && _routeVisible) || !settings.pauseOnLeave)) {
      await begin();
    }
    final current = controller;
    if (!canPlay || current == null) return;
    await current.play();
    if (!canPlay || controller != current) await current.pause();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) interrupt();
  }

  void dispose() {
    _disposed = true;
    controller = null;
    settings.removeListener(_applyVisibility);
    WidgetsBinding.instance.removeObserver(this);
    coordinator.remove(this);
  }
}
