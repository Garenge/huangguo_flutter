import 'package:flutter/material.dart';

import '../models/compression_test.dart';
import '../models/storage_usage.dart';

class CompressionTestResults extends StatelessWidget {
  const CompressionTestResults({
    super.key,
    required this.results,
    required this.selected,
    required this.onSelected,
  });

  final List<CompressionTestResult> results;
  final CompressionTestResult selected;
  final ValueChanged<CompressionTestResult>? onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (results.length > 1) ...[
        const Text('选择已完成的结果进行预览对比'),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < results.length; i++)
              ChoiceChip(
                label: Text(
                  '${i + 1}. ${results[i].preset.label} · '
                  '${results[i].preset.codecLabel} · ${formatStorageBytes(results[i].bytes)}',
                ),
                selected: identical(results[i], selected),
                onSelected: onSelected == null
                    ? null
                    : (_) => onSelected!(results[i]),
              ),
          ],
        ),
      ],
      _detail(),
    ],
  );

  Widget _detail() {
    final result = selected;
    final sample = result.range == CompressionTestRange.sample;
    final saved = result.sourceBytes > 0
        ? (1 - result.bytes / result.sourceBytes) * 100
        : 0.0;
    final output = result.outputMedia;
    final deviation = result.targetDeviation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('测试结果 · ${result.preset.label} · ${result.preset.codecLabel}'),
            Text(
              sample
                  ? '片段对比 · ${result.seconds.toStringAsFixed(1)} 秒（不代表整集大小）'
                  : '整集对比',
            ),
            const SizedBox(height: 8),
            Text(
              '${sample ? "原片段" : "原文件"}：${formatStorageBytes(result.sourceBytes)}',
            ),
            Text(
              '${sample ? "压缩片段" : "新文件"}：${formatStorageBytes(result.bytes)}',
            ),
            Text(
              saved >= 0
                  ? '节省 ${saved.toStringAsFixed(1)}%'
                  : '体积增加 ${(-saved).toStringAsFixed(1)}%',
            ),
            if (deviation != null) ...[
              Text('目标大小：${formatStorageBytes(result.targetBytes!)}'),
              Text(
                '目标偏差：${deviation >= 0 ? "+" : ""}${deviation.toStringAsFixed(1)}%'
                ' · ${result.targetMet ? "达标（±10%）" : "未达标（超出 ±10%）"}',
              ),
            ],
            if (output != null)
              Text(
                '输出：${output.width} × ${output.height}'
                ' · ${output.frameRate.toStringAsFixed(2)} fps',
              ),
            Text('耗时：${result.elapsed.inSeconds} 秒'),
            Text(
              '编码参数：${result.preset.encoder} / ${result.preset.speedOption} ${result.preset.speedPreset.isEmpty ? "硬件" : result.preset.speedPreset}'
              ' / ${result.targetBytes == null ? "质量档 ${result.preset.quality}" : "两遍平均码率"}',
            ),
          ],
        ),
      ),
    );
  }
}
