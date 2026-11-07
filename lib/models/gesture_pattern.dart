/// Point numbers run from 1 (top left) to 9 (bottom right).
class GesturePattern {
  static List<int> append(List<int> points, int next) {
    if (next < 1 || next > 9 || points.contains(next)) return points;
    final result = [...points];
    if (result.isNotEmpty) {
      final last = result.last - 1;
      final target = next - 1;
      final dx = target % 3 - last % 3;
      final dy = target ~/ 3 - last ~/ 3;
      if ((dx.abs() == 2 || dy.abs() == 2) && dx.isEven && dy.isEven) {
        final middle = (last ~/ 3 + dy ~/ 2) * 3 + last % 3 + dx ~/ 2 + 1;
        if (!result.contains(middle)) result.add(middle);
      }
    }
    return result..add(next);
  }

  static bool isValid(List<int> points) {
    if (points.length < 4 || points.length > 9) return false;
    var normalized = <int>[];
    for (final point in points) {
      normalized = append(normalized, point);
    }
    return normalized.join() == points.join();
  }
}
