import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../services/app_log.dart';

/// Limits desktop playback keys to the visible route, including its controls.
class PlaybackKeyboardShortcuts extends StatefulWidget {
  const PlaybackKeyboardShortcuts({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onPlayPause,
    required this.onSeek,
    required this.child,
  });

  final VideoPlayerController? controller;
  final bool enabled;
  final Future<void> Function() onPlayPause;
  final VoidCallback onSeek;
  final Widget child;

  @override
  State<PlaybackKeyboardShortcuts> createState() =>
      _PlaybackKeyboardShortcutsState();
}

class _PlaybackKeyboardShortcutsState extends State<PlaybackKeyboardShortcuts> {
  Future<void> _queue = Future<void>.value();
  Duration? _target;
  int _generation = 0;
  int _pendingSeeks = 0;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_handleKey);
  }

  @override
  void didUpdateWidget(covariant PlaybackKeyboardShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.enabled != widget.enabled) {
      _generation++;
      _target = null;
      _pendingSeeks = 0;
      _queue = Future<void>.value();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleKey);
    super.dispose();
  }

  bool get _canHandle {
    final platform = Theme.of(context).platform;
    final desktop =
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return desktop &&
        widget.enabled &&
        widget.controller?.value.isInitialized == true &&
        widget.controller?.value.hasError == false &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
        ModalRoute.of(context)?.isCurrent == true &&
        !_editingText;
  }

  bool get _editingText {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    return focusContext?.widget is EditableText ||
        focusContext?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _handleKey(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (!_canHandle ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed ||
        keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.space &&
        key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) return KeyEventResult.handled;
    if (key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) _enqueue(widget.onPlayPause);
    } else if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _seek(key == LogicalKeyboardKey.arrowLeft ? -5 : 5);
    }
    return KeyEventResult.handled;
  }

  void _enqueue(Future<void> Function() action, {VoidCallback? onDone}) {
    final generation = _generation;
    _queue = _queue.then((_) async {
      try {
        if (!mounted || generation != _generation || !_canHandle) return;
        await action();
      } catch (error, stack) {
        const AppLog(
          'playback_keyboard_shortcuts.dart',
        ).e('_enqueue: 键盘播放控制失败', error, stack);
      } finally {
        onDone?.call();
      }
    });
  }

  void _seek(int seconds) {
    final controller = widget.controller;
    if (controller == null || controller.value.duration <= Duration.zero) {
      return;
    }
    final value = controller.value;
    final target = Duration(
      milliseconds: ((_target ?? value.position) + Duration(seconds: seconds))
          .inMilliseconds
          .clamp(0, value.duration.inMilliseconds),
    );
    final generation = _generation;
    _target = target;
    _pendingSeeks++;
    _enqueue(
      () async {
        await controller.seekTo(target);
        if (mounted && generation == _generation) widget.onSeek();
      },
      onDone: () {
        if (generation == _generation && --_pendingSeeks == 0) _target = null;
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
