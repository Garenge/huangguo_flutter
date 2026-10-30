import 'package:flutter/widgets.dart';

import '../services/playback_coordinator.dart';
import '../services/playback_settings_service.dart';

class PlaybackScope extends InheritedWidget {
  const PlaybackScope({
    super.key,
    required this.settings,
    required this.coordinator,
    required this.onlineVisible,
    this.localVisible = true,
    required super.child,
  });

  final PlaybackSettingsService settings;
  final PlaybackCoordinator coordinator;
  final bool onlineVisible;
  final bool localVisible;

  static PlaybackScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlaybackScope>();

  @override
  bool updateShouldNotify(PlaybackScope oldWidget) =>
      settings != oldWidget.settings ||
      coordinator != oldWidget.coordinator ||
      onlineVisible != oldWidget.onlineVisible ||
      localVisible != oldWidget.localVisible;
}
