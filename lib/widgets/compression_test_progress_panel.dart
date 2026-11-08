import 'package:flutter/material.dart';

import '../services/compression_test_controller.dart';

class CompressionTestProgressPanel extends StatelessWidget {
  const CompressionTestProgressPanel({super.key, required this.controller});

  final CompressionTestController controller;

  @override
  Widget build(BuildContext context) {
    final timing = controller.timing;
    final progress = controller.progress;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Text(
            '${controller.status}'
            '${progress == null ? "" : " ${(progress * 100).floor()}%"}',
          ),
          if (timing.totalSeconds > 0) ...[
            Text(
              '已处理 ${_time(timing.processedSeconds)} / '
              '${_time(timing.totalSeconds)}',
            ),
            Text('已耗时 ${_time(timing.elapsed.inMilliseconds / 1000)}'),
            if (timing.encoding) _estimate(),
          ],
        ],
      ),
    );
  }

  Widget _estimate() {
    final timing = controller.timing;
    final remaining = timing.remaining;
    if (remaining == null) {
      return const Text('正在等待编码器报告进度，剩余时间暂不可估计');
    }
    return Text(
      '处理速度 ${timing.speed.toStringAsFixed(2)}× · '
      '预计剩余 ${_time(remaining.inMilliseconds / 1000)}',
    );
  }

  String _time(double seconds) {
    final whole = seconds.floor();
    final minutes = whole ~/ 60;
    final rest = (whole % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }
}
