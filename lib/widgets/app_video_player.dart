import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../services/app_log.dart';
import 'video_player_surface.dart';

/// Source resolution and controller ownership stay with the calling page.
class AppVideoPlayer extends StatefulWidget {
  final VideoPlayerController? controller;
  final String title;
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

  @override
  void initState() {
    super.initState();
    _source = ValueNotifier(widget);
  }

  @override
  void didUpdateWidget(covariant AppVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The fullscreen route is a sibling, so notify it after this build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _source.value = widget;
    });
  }

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  Future<void> _setScreenMode(bool fullscreen) async {
    try {
      await SystemChrome.setPreferredOrientations(
        fullscreen
            ? [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
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
      await _setScreenMode(true);
      if (!mounted) return;
      await Navigator.of(
        context,
        rootNavigator: true,
      ).push<void>(MaterialPageRoute(builder: _buildFullscreen));
    } finally {
      await _setScreenMode(false);
      if (mounted) setState(() => _fullscreen = false);
    }
  }

  Widget _buildFullscreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<AppVideoPlayer>(
        valueListenable: _source,
        builder: (context, source, _) => VideoPlayerSurface(
          controller: source.controller,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: !_fullscreen,
      maintainState: true,
      child: VideoPlayerSurface(
        controller: widget.controller,
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
    );
  }
}
