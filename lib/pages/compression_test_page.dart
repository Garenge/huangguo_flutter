import 'dart:async';

import 'package:flutter/material.dart';

import '../models/compression_test.dart';
import '../models/download_task.dart';
import '../models/storage_usage.dart';
import '../services/app_log.dart';
import '../services/compression_test_controller.dart';
import '../services/compression_test_workspace.dart';
import '../widgets/app_notice.dart';
import '../widgets/compression_test_options.dart';
import '../widgets/compression_test_preview.dart';
import '../widgets/compression_test_selector.dart';
import '../widgets/compression_test_range_selector.dart';

class CompressionTestPage extends StatefulWidget {
  const CompressionTestPage({super.key, required this.tasks, this.controller});

  final List<DownloadTask> tasks;
  final CompressionTestController? controller;

  @override
  State<CompressionTestPage> createState() => _CompressionTestPageState();
}

class _CompressionTestPageState extends State<CompressionTestPage> {
  final _preview = GlobalKey<CompressionTestPreviewState>();
  late final CompressionTestController _controller;
  late final List<DownloadTask> _tasks;
  String? _drama;
  DownloadTask? _episode;
  bool _previewBusy = false;
  bool _leaving = false;
  bool _allowPop = false;
  Future<void>? _cleanupFuture;

  bool get _enabled =>
      _controller.ready && !_controller.busy && !_previewBusy && !_leaving;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? CompressionTestController();
    _tasks = widget.tasks
        .where(
          (task) =>
              task.status == DownloadStatus.completed &&
              CompressionTestWorkspace.sourcePath(task) != null,
        )
        .toList();
    unawaited(_controller.initialize());
  }

  Future<void> _select(DownloadTask? task) async {
    if (!_enabled) return;
    setState(() {
      _episode = task;
      _previewBusy = true;
    });
    try {
      await _preview.currentState?.release();
      if (mounted && !_leaving) await _controller.select(task);
    } finally {
      if (mounted) setState(() => _previewBusy = false);
    }
  }

  Future<void> _changeDrama(String? drama) async {
    if (!_enabled) return;
    setState(() => _drama = drama);
    await _select(null);
  }

  Future<void> _showPreview(bool compressed) async {
    if (!_enabled) return;
    final path = compressed ? _controller.result?.path : _controller.sourcePath;
    if (path == null) return;
    setState(() => _previewBusy = true);
    try {
      await _preview.currentState?.show(
        path,
        '${compressed ? "压缩" : "原"}'
        '${_controller.range == CompressionTestRange.sample ? "片段" : "视频"}'
        ' · ${_episode?.episodeName}',
      );
    } finally {
      if (mounted) setState(() => _previewBusy = false);
    }
  }

  Future<void> _changeRange(CompressionTestRange range) async {
    if (!_enabled || range == _controller.range) return;
    setState(() => _previewBusy = true);
    try {
      await _preview.currentState?.release();
      if (mounted && !_leaving) await _controller.changeRange(range);
    } finally {
      if (mounted) setState(() => _previewBusy = false);
    }
  }

  Future<void> _compress(CompressionPreset preset) async {
    if (!_enabled) return;
    setState(() => _previewBusy = true);
    try {
      await _preview.currentState?.release();
      if (mounted && !_leaving) await _controller.compress(preset);
    } finally {
      if (mounted) setState(() => _previewBusy = false);
    }
  }

  Future<void> _cleanup() => _cleanupFuture ??= _releaseResources();

  Future<void> _releaseResources() async {
    final preview = _preview.currentState;
    await _controller.engine.cancel();
    await preview?.release();
    await _controller.close();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      await _cleanup();
      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (error, stack) {
      const AppLog(
        'compression_test_page.dart',
      ).e('_leave: 退出时清理测试资源失败', error, stack);
      if (!mounted) return;
      _cleanupFuture = null;
      setState(() => _leaving = false);
      showAppNotice(context, '测试目录清理失败，请重试返回');
    }
  }

  @override
  void dispose() {
    unawaited(
      _cleanup()
          .catchError((Object error, StackTrace stack) {
            const AppLog(
              'compression_test_page.dart',
            ).e('dispose: 测试资源清理失败，将在下次进入时重试', error, stack);
          })
          .whenComplete(_controller.dispose),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('压缩测试'),
          leading: BackButton(onPressed: _leave),
        ),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _body(),
        ),
      ),
    );
  }

  Widget _body() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CompressionTestSelector(
            tasks: _tasks,
            drama: _drama,
            episode: _episode,
            enabled: _enabled,
            onDramaChanged: _changeDrama,
            onEpisodeChanged: _select,
          ),
          if (_tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('暂无可测试的已下载剧集，请先完成下载。'),
            ),
          const SizedBox(height: 16),
          CompressionTestRangeSelector(
            range: _controller.range,
            enabled: _enabled && _controller.sourcePath != null,
            onChanged: _changeRange,
          ),
          const SizedBox(height: 16),
          Text(
            '整集资源大小：${_controller.sourcePath == null ? "选择剧集后显示" : formatStorageBytes(_controller.source.fullBytes)}',
          ),
          if (_controller.sourcePath != null &&
              _controller.range == CompressionTestRange.sample)
            Text('本次原片段大小：${formatStorageBytes(_controller.sourceBytes)}'),
          if (_controller.sourcePath != null)
            Text(
              '分辨率：${_controller.media!.width} × ${_controller.media!.height}',
            ),
          OutlinedButton.icon(
            onPressed: _enabled && _controller.sourcePath != null
                ? () => _showPreview(false)
                : null,
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('预览原视频'),
          ),
          const SizedBox(height: 12),
          CompressionTestPreview(key: _preview),
          const SizedBox(height: 20),
          CompressionTestOptions(
            controller: _controller,
            enabled: _enabled,
            onCompress: _compress,
            onPreview: () => _showPreview(true),
            onSelectResult: (value) {
              if (!_enabled) return;
              _controller.selectResult(value);
              unawaited(_showPreview(true));
            },
          ),
          const SizedBox(height: 16),
          Text(
            _leaving
                ? '正在停止处理并清理测试文件…'
                : '点击方案开始压缩所选范围。测试文件仅保存在临时目录，返回后自动删除。'
                      '原视频与压缩视频可在相同播放位置切换对比。',
          ),
        ],
      ),
    );
  }
}
