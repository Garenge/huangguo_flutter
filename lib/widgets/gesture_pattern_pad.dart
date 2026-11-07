import 'package:flutter/material.dart';

import '../models/gesture_pattern.dart';
import 'gesture_pattern_painter.dart';

class GesturePatternPad extends StatefulWidget {
  const GesturePatternPad({
    super.key,
    required this.onCompleted,
    this.enabled = true,
  });

  final ValueChanged<List<int>> onCompleted;
  final bool enabled;

  @override
  State<GesturePatternPad> createState() => _GesturePatternPadState();
}

class _GesturePatternPadState extends State<GesturePatternPad> {
  List<int> _points = [];
  Offset? _pointer;
  int? _pointerId;
  Size _size = Size.zero;

  void _sample(Offset position) {
    var next = _points;
    final previous = _pointer ?? position;
    final delta = position - previous;
    final steps = (delta.distance / 8).ceil().clamp(1, 100);
    for (var step = 1; step <= steps; step++) {
      final sample = previous + delta * (step / steps);
      for (var point = 1; point <= 9; point++) {
        if ((GesturePatternPainter.center(point, _size) - sample).distance <
            25) {
          next = GesturePattern.append(next, point);
          break;
        }
      }
    }
    setState(() {
      _points = next;
      _pointer = position;
    });
  }

  void _start(PointerDownEvent event) {
    if (!widget.enabled || _pointerId != null) return;
    _points = [];
    _pointer = null;
    _pointerId = event.pointer;
    _sample(event.localPosition);
  }

  void _finish(PointerEvent event, {bool cancelled = false}) {
    if (event.pointer != _pointerId) return;
    final result = List<int>.of(_points);
    setState(() {
      _points = [];
      _pointer = null;
      _pointerId = null;
    });
    if (!cancelled && widget.enabled && result.isNotEmpty) {
      widget.onCompleted(result);
    }
  }

  @override
  void didUpdateWidget(GesturePatternPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _points = [];
      _pointer = null;
      _pointerId = null;
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '九宫格手势区域，点位从左到右、从上到下为一至九',
    child: SizedBox.square(
      dimension: 300,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _size = constraints.biggest;
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _start,
            onPointerMove: (event) {
              if (widget.enabled && event.pointer == _pointerId) {
                _sample(event.localPosition);
              }
            },
            onPointerUp: _finish,
            onPointerCancel: (event) => _finish(event, cancelled: true),
            child: CustomPaint(
              painter: GesturePatternPainter(
                _points,
                _pointer,
                const Color(0xFF60A5FA),
              ),
            ),
          );
        },
      ),
    ),
  );
}
