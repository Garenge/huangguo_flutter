import 'package:flutter/material.dart';

import '../models/compression_test.dart';

class CompressionTestRangeSelector extends StatelessWidget {
  const CompressionTestRangeSelector({
    super.key,
    required this.range,
    required this.enabled,
    required this.onChanged,
  });

  final CompressionTestRange range;
  final bool enabled;
  final ValueChanged<CompressionTestRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('测试范围'),
        const SizedBox(height: 8),
        SegmentedButton<CompressionTestRange>(
          segments: [
            for (final value in CompressionTestRange.values)
              ButtonSegment(value: value, label: Text(value.label)),
          ],
          selected: {range},
          onSelectionChanged: enabled
              ? (values) => onChanged(values.single)
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          range == CompressionTestRange.sample
              ? '仅对比开头约 30 秒；不足 30 秒时使用全部内容。'
              : '压缩完整一集，用于确认整集效果。',
        ),
      ],
    );
  }
}
