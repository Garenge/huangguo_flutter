import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../services/app_log.dart';
import '../services/playback_window_title.dart';
import 'fullscreen_keyboard_shortcuts.dart';
import 'video_player_surface.dart';
import '../services/playback_session.dart';
import 'playback_route_guard.dart';

/// Source resolution and controller ownership stay with the calling page.
class AppVideoPlayer extends StatefulWidget {
  final VideoPlayerController? controller;
  final String title;
  final String? dramaName;

  String get windowTitle {
    final drama = dramaName?.trim() ?? '';
    final episode = title.trim();
    if (drama.isEmpty) return episode;
    if (episode.isEmpty || episode == drama) return drama;
    return '$drama · $episode';
  }

  final PlaybackSession? session;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  const AppVideoPlayer({
    super.key,
    required this.controller,
    required this.title,
    this.dramaName,
    this.session,
    this.loading = false,
    this.error,
    this.onRetry,
    this.onPrevious,
    this.onNext,
    this.onBack,
  });

  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer> {
  late final ValueNotifier<AppVideoPlayer> _source;
  bool _fullscreen = false;
  Route<void>? _fullscreenRoute;
  bool _exitFullscreenScheduled = false;

  @override
  void initState() {
    super.initState();
    _source = ValueNotifier(widget);
    widget.controller?.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AppVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
    }
    if (_fullscreen && oldWidget.windowTitle != widget.windowTitle) {
      PlaybackWindowTitle.update(widget.windowTitle);
    }
    // The fullscreen route is a sibling, so notify it after this build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _source.value = widget;
    });
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    if (_fullscreen) PlaybackWindowTitle.update(null);
    _source.dispose();
    super.dispose();
  }

  bool get _lastEpisodeCompleted {
    final value = widget.controller?.value;
    return widget.onNext == null &&
        !widget.loading &&
        widget.error == null &&
        value != null &&
        value.isInitialized &&
        !value.hasError &&
        !value.isBuffering &&
        value.duration > Duration.zero &&
        value.position >= value.duration;
  }

  void _onControllerChanged() {
    final route = _fullscreenRoute;
    if (_exitFullscreenScheduled ||
        !_fullscreen ||
        route == null ||
        !route.isCurrent ||
        !_lastEpisodeCompleted) {
      return;
    }
    _exitFullscreenScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _exitFullscreenScheduled = false;
      if (mounted &&
          route == _fullscreenRoute &&
          route.isCurrent &&
          _lastEpisodeCompleted) {
        route.navigator?.pop();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _setScreenMode(bool fullscreen) async {
    final platform = Theme.of(context).platform;
    final supportsOrientationLock =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    if (!supportsOrientationLock) return;
    try {
      final aspectRatio = widget.controller?.value.aspectRatio ?? 0;
      final isLandscape = aspectRatio <= 0 || aspectRatio >= 1;
      await SystemChrome.setPreferredOrientations(
        fullscreen
            ? isLandscape
                  ? [
                      DeviceOrientation.landscapeLeft,
                      DeviceOrientation.landscapeRight,
                    ]
                  : [DeviceOrientation.portraitUp]
            : [DeviceOrientation.portraitUp],
      );
      await SystemChrome.setEnabledSystemUIMode(
        fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    } catch (error, stack) {
      const AppLog(
        'app_video_player.dart',
      ).e('_setScreenMode: 屏幕方向切换失败', error, stack);
    }
  }

  Future<void> _openFullscreen() async {
    if (_fullscreen) return;
    setState(() => _fullscreen = true);
    try {
      await PlaybackWindowTitle.update(widget.windowTitle);
      await _setScreenMode(true);
      if (!mounted) return;
      final route = MaterialPageRoute<void>(builder: _buildFullscreen);
      _fullscreenRoute = route;
      final closed = Navigator.of(
        context,
        rootNavigator: true,
      ).push<void>(route);
      _onControllerChanged();
      await closed;
    } finally {
      _fullscreenRoute = null;
      await PlaybackWindowTitle.update(null);
      await _setScreenMode(false);
      if (mounted) setState(() => _fullscreen = false);
    }
  }

  Widget _buildFullscreen(BuildContext context) {
    return FullscreenKeyboardShortcuts(child: _buildFullscreenSurface());
  }

  Widget _buildFullscreenSurface() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<AppVideoPlayer>(
        valueListenable: _source,
        builder: (context, source, _) => PlaybackRouteGuard(
          session: source.session,
          child: VideoPlayerSurface(
            controller: source.controller,
            session: source.session,
            title: source.title,
            loading: source.loading,
            error: source.error,
            onRetry: source.onRetry,
            onPrevious: source.onPrevious,
            onNext: source.onNext,
            fullscreen: true,
            onBack: () => Navigator.of(context).pop(),
            onToggleFullscreen: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlaybackRouteGuard(
      session: widget.session,
      ignoreCover: () => _fullscreen,
      child: Visibility(
        visible: !_fullscreen,
        maintainState: true,
        child: VideoPlayerSurface(
          controller: widget.controller,
          session: widget.session,
          title: widget.title,
          loading: widget.loading,
          error: widget.error,
          onRetry: widget.onRetry,
          onPrevious: widget.onPrevious,
          onNext: widget.onNext,
          onBack: widget.onBack,
          active: !_fullscreen,
          onToggleFullscreen: _openFullscreen,
        ),
      ),
    );
  }
}
