import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/storage_usage.dart';
import 'app_log.dart';
import 'download_service.dart';
import 'storage_usage_service.dart';

const _log = AppLog('download_storage_controller.dart');

class DownloadStorageController extends ChangeNotifier {
  final DownloadService downloads;
  final StorageUsageService service;
  StorageUsage? usage;
  StorageUsage? appUsage;
  bool appRefreshing = false;
  bool appRefreshFailed = false;
  int _appRevision = 0;
  bool refreshing = false;
  bool _active = false;
  bool _disposed = false;
  bool _dirty = false;
  Timer? _refreshTimer;
  Timer? _changeTimer;
  late List<(String, String?, String?)> _resourceSignature;

  DownloadStorageController(this.downloads, this.service) {
    _resourceSignature = _completedResources();
    downloads.addListener(_onDownloadsChanged);
  }

  void setActive(bool active) {
    if (_active == active) return;
    _active = active;
    _refreshTimer?.cancel();
    _changeTimer?.cancel();
    _changeTimer = null;
    if (!active) return;
    unawaited(refresh());
    unawaited(refreshAppUsage());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => refresh(),
    );
  }

  void _onDownloadsChanged() {
    final signature = _completedResources();
    if (listEquals(signature, _resourceSignature)) return;
    _resourceSignature = signature;
    _scheduleRefresh();
  }

  List<(String, String?, String?)> _completedResources() => [
    for (final task in downloads.completedTasks)
      (task.id, task.filePath, task.mp4Path),
  ];

  void _scheduleRefresh() {
    if (!_active || _changeTimer != null) return;
    _changeTimer = Timer(const Duration(seconds: 3), () {
      _changeTimer = null;
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (_disposed) return;
    if (refreshing) {
      _dirty = true;
      return;
    }
    refreshing = true;
    notifyListeners();
    try {
      usage = await service.readDownloadUsage(downloads);
    } catch (error, stack) {
      _log.e('refresh: 存储统计失败', error, stack);
      usage = const StorageUsage();
    } finally {
      refreshing = false;
      if (!_disposed) {
        notifyListeners();
        if (_dirty && _active) _scheduleRefresh();
        _dirty = false;
      }
    }
  }

  Future<void> refreshAppUsage() async {
    if (_disposed || appRefreshing) return;
    final revision = _appRevision;
    appRefreshing = true;
    appRefreshFailed = false;
    notifyListeners();
    try {
      final result = await service.read(downloads);
      if (!_disposed && revision == _appRevision) updateAppUsage(result);
    } catch (error, stack) {
      _log.e('refreshAppUsage: App 占用统计失败', error, stack);
      if (!_disposed && revision == _appRevision) appRefreshFailed = true;
    } finally {
      appRefreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// 管理页的较新结果优先于已下载页尚未完成的扫描。
  void updateAppUsage(StorageUsage result) {
    if (_disposed) return;
    _appRevision++;
    appRefreshFailed = result.appBytes == null;
    if (!appRefreshFailed || appUsage == null) appUsage = result;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _changeTimer?.cancel();
    downloads.removeListener(_onDownloadsChanged);
    super.dispose();
  }
}
