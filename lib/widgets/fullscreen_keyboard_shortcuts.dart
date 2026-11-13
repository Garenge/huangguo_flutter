import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps fullscreen exit available even while playback is loading or has failed.
class FullscreenKeyboardShortcuts extends StatefulWidget {
  const FullscreenKeyboardShortcuts({super.key, required this.child});

  final Widget child;

  @override
  State<FullscreenKeyboardShortcuts> createState() =>
      _FullscreenKeyboardShortcutsState();
}

class _FullscreenKeyboardShortcutsState
    extends State<FullscreenKeyboardShortcuts> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_handleKey);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleKey);
    super.dispose();
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.escape &&
        event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (ModalRoute.of(context)?.isCurrent != true ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed ||
        keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) Navigator.of(context).pop();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
