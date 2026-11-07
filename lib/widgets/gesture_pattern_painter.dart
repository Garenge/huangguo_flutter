import 'package:flutter/material.dart';

class GesturePatternPainter extends CustomPainter {
  GesturePatternPainter(this.points, this.pointer, this.color);

  final List<int> points;
  final Offset? pointer;
  final Color color;

  static Offset center(int point, Size size) => Offset(
    ((point - 1) % 3 + 0.5) * size.width / 3,
    ((point - 1) ~/ 3 + 0.5) * size.height / 3,
  );

  @override
  void paint(Canvas canvas, Size size) {
    _paintLines(canvas, size);
    _paintPoints(canvas, size);
  }

  void _paintLines(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final path = Path()
      ..moveTo(center(points.first, size).dx, center(points.first, size).dy);
    for (final point in points.skip(1)) {
      final position = center(point, size);
      path.lineTo(position.dx, position.dy);
    }
    if (pointer != null) path.lineTo(pointer!.dx, pointer!.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.65)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintPoints(Canvas canvas, Size size) {
    for (var point = 1; point <= 9; point++) {
      final selected = points.contains(point);
      final position = center(point, size);
      if (selected) {
        canvas.drawCircle(
          position,
          23,
          Paint()..color = color.withValues(alpha: 0.14),
        );
      }
      canvas.drawCircle(
        position,
        11,
        Paint()..color = selected ? color : const Color(0xFF64748B),
      );
    }
  }

  @override
  bool shouldRepaint(GesturePatternPainter oldDelegate) => true;
}
