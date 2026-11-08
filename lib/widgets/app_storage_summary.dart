import 'package:flutter/material.dart';

import '../models/storage_usage.dart';

class AppStorageSummary extends StatelessWidget {
  final StorageUsage? usage;
  final bool refreshing;
  final bool failed;
  final VoidCallback onRetry;

  const AppStorageSummary({
    super.key,
    required this.usage,
    required this.refreshing,
    required this.failed,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        usage?.appLabel ?? 'App 占用',
        style: const TextStyle(color: Colors.grey),
      ),
      const SizedBox(height: 12),
      Text(
        usage == null && refreshing
            ? '正在统计…'
            : formatStorageBytes(usage?.appBytes),
        style: const TextStyle(color: Colors.white, fontSize: 32),
      ),
      if (refreshing) ...[
        const SizedBox(height: 16),
        const LinearProgressIndicator(color: Colors.orange),
        const SizedBox(height: 12),
        const Text(
          '正在后台扫描应用文件，文件较多时可能需要一些时间，可随时返回。',
          style: TextStyle(color: Colors.grey, height: 1.6),
        ),
      ],
      const SizedBox(height: 16),
      const Text(
        '按可读取文件的逻辑大小估算，包含统计范围内的下载、数据和缓存；'
        '仅在平台支持时包含应用本体，与系统设置的占用可能不同。',
        style: TextStyle(color: Colors.grey, height: 1.6),
      ),
      if (!refreshing && (failed || usage?.appBytes == null)) _retry(),
      if (usage?.isPartial ?? false)
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            '部分文件无法读取，当前仅显示已读取部分，实际占用可能更大。',
            style: TextStyle(color: Colors.orange, height: 1.6),
          ),
        ),
      if (usage?.failedPaths.isNotEmpty ?? false) _failures(),
    ],
  );

  Widget _retry() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      Text(
        failed && usage != null ? '重新统计失败，保留上次结果。' : '未能读取应用占用，请重试。',
        style: const TextStyle(color: Colors.orange),
      ),
      TextButton(onPressed: onRetry, child: const Text('重试统计')),
    ],
  );

  Widget _failures() => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text(
      '无法读取的路径（${usage!.failedPaths.length}）',
      style: const TextStyle(color: Colors.orange),
    ),
    children: [
      for (final path in usage!.failedPaths.take(20))
        ListTile(
          title: SelectableText(
            path,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      if (usage!.failedPaths.length > 20)
        const Text(
          '仅展示前 20 个路径，完整原因见运行日志。',
          style: TextStyle(color: Colors.grey),
        ),
    ],
  );
}
