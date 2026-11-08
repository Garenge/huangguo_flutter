import 'package:flutter/material.dart';

import '../models/compression_test.dart';
import '../services/compression_test_controller.dart';
import 'compression_test_progress_panel.dart';
import 'compression_test_results.dart';

class CompressionTestOptions extends StatelessWidget {
  const CompressionTestOptions({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onCompress,
    required this.onPreview,
    required this.onSelectResult,
  });

  final CompressionTestController controller;
  final bool enabled;
  final ValueChanged<CompressionPreset> onCompress;
  final VoidCallback onPreview;
  final ValueChanged<CompressionTestResult> onSelectResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '压缩方案',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...controller.presets.map(_preset),
        for (final reason in controller.engine.unavailableReasons)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('编码支持说明：$reason'),
          ),
        if (controller.ready &&
            controller.sourcePath != null &&
            controller.presets.isEmpty)
          const Text('当前设备的编码组件没有可用的压缩方案。'),
        if (controller.busy || controller.result != null)
          CompressionTestProgressPanel(controller: controller),
        if (controller.error case final error?)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(error, style: const TextStyle(color: Colors.redAccent)),
          ),
        if (controller.result case final result?) ...[
          const SizedBox(height: 16),
          CompressionTestResults(
            results: controller.results,
            selected: result,
            onSelected: enabled ? onSelectResult : null,
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: enabled && controller.result != null ? onPreview : null,
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('预览压缩视频'),
        ),
      ],
    );
  }

  Widget _preset(CompressionPreset preset) {
    return Card(
      child: ListTile(
        title: Text(preset.label),
        subtitle: Text(preset.description),
        trailing: const Icon(Icons.compress),
        enabled: enabled && controller.sourcePath != null,
        onTap: enabled && controller.sourcePath != null
            ? () => onCompress(preset)
            : null,
      ),
    );
  }
}
