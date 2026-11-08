import 'dart:async';

import 'package:flutter/material.dart';

import '../models/storage_usage.dart';
import '../services/app_log.dart';
import '../services/download_service.dart';
import '../services/storage_usage_service.dart';
import '../widgets/app_storage_summary.dart';

const _log = AppLog('app_storage_page.dart');

/// 空间管理入口；全量扫描只在进入页面或手动刷新时执行。
class AppStoragePage extends StatefulWidget {
  final DownloadService downloads;
  final StorageUsageService service;
  final ValueChanged<StorageUsage>? onUsageChanged;

  const AppStoragePage({
    super.key,
    required this.downloads,
    required this.service,
    this.onUsageChanged,
  });

  @override
  State<AppStoragePage> createState() => _AppStoragePageState();
}

class _AppStoragePageState extends State<AppStoragePage> {
  StorageUsage? _usage;
  bool _refreshing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _failed = false;
    });
    try {
      final usage = await widget.service.read(widget.downloads);
      if (mounted) {
        setState(() => _usage = usage);
        widget.onUsageChanged?.call(usage);
      }
    } catch (error, stack) {
      _log.e('_refresh: App 空间统计失败', error, stack);
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0D0D0D),
    appBar: AppBar(
      title: const Text('App 空间管理'),
      backgroundColor: const Color(0xFF0D0D0D),
      actions: [
        IconButton(
          tooltip: '重新统计 App 占用',
          onPressed: _refreshing ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppStorageSummary(
            usage: _usage,
            refreshing: _refreshing,
            failed: _failed,
            onRetry: _refresh,
          ),
          const SizedBox(height: 24),
          const Text('后续空间管理', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          const Text(
            '后续将在此提供大文件列表和 MP4 压缩，本次暂未开放。',
            style: TextStyle(color: Colors.grey, height: 1.6),
          ),
        ],
      ),
    ),
  );
}
