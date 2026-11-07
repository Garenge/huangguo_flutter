import 'package:flutter/material.dart';

import 'gesture_pattern_pad.dart';

class GesturePrompt extends StatelessWidget {
  const GesturePrompt({
    super.key,
    required this.title,
    required this.message,
    required this.onCompleted,
    this.busy = false,
    this.error,
  });

  final String title;
  final String message;
  final String? error;
  final bool busy;
  final ValueChanged<List<int>> onCompleted;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gesture_rounded, size: 44, color: Color(0xFF60A5FA)),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          GesturePatternPad(enabled: !busy, onCompleted: onCompleted),
          SizedBox(
            height: 48,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      error ?? '至少连接 4 个点',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: error == null ? Colors.grey : Colors.redAccent,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}
