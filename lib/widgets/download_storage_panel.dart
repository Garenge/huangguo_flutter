import 'package:flutter/material.dart';

import '../models/storage_usage.dart';
import '../pages/app_storage_page.dart';
import '../services/download_storage_controller.dart';

class DownloadStoragePanel extends StatelessWidget {
  final DownloadStorageController controller;

  const DownloadStoragePanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Material(
        color: const Color(0xFF1B1B1B),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: _content(context),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final usage = controller.usage;
    final used = usage?.usedBytes;
    final total = usage?.totalBytes;
    final progress = used != null && total != null ? used / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.storage_rounded, color: Colors.orange, size: 18),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                '存储管理',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            IconButton(
              tooltip: '刷新空间统计',
              onPressed: controller.refreshing ? null : controller.refresh,
              constraints: const BoxConstraints.tightFor(width: 40, height: 32),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8, top: 2, bottom: 10),
          child: LinearProgressIndicator(
            value: progress,
            color: Colors.orange,
            backgroundColor: Colors.white12,
            borderRadius: BorderRadius.circular(3),
            minHeight: 5,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _metric('设备总空间', total),
              _metric('设备已用', used),
              _appEntry(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _appEntry(BuildContext context) => Expanded(
    child: InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AppStoragePage(
            downloads: controller.downloads,
            service: controller.service,
            onUsageChanged: controller.updateAppUsage,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App 占用',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 3),
            Tooltip(
              message: _appHint,
              child: Text(
                _appValue,
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String get _appValue {
    final usage = controller.appUsage;
    if (usage?.appBytes == null && controller.appRefreshing) return '统计中…';
    final suffix = usage?.isPartial == true ? '（部分）' : '';
    return '${formatStorageBytes(usage?.appBytes)}$suffix ›';
  }

  String get _appHint {
    if (controller.appRefreshFailed && controller.appUsage?.appBytes != null) {
      return '重新统计失败，保留上次结果；点击进入空间管理重试。';
    }
    return '按可读取文件大小估算，可能与系统设置不同；点击进入空间管理查看详情和重新统计。';
  }

  Widget _metric(String label, int? bytes) {
    final loading = controller.usage == null && controller.refreshing;
    return Expanded(
      child: Tooltip(
        message: label.startsWith('App')
            ? '按可读取文件大小统计，包含下载、数据和缓存；估算值可能与系统设置不同。'
            : label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 3),
            Text(
              loading ? '统计中…' : formatStorageBytes(bytes),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
