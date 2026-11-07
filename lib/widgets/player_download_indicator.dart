import 'package:flutter/material.dart';

import '../models/download_task.dart';

class PlayerDownloadIndicator extends StatelessWidget {
  const PlayerDownloadIndicator({
    super.key,
    required this.adding,
    required this.downloaded,
    required this.task,
    required this.onPressed,
  });

  final bool adding;
  final bool downloaded;
  final DownloadTask? task;
  final VoidCallback onPressed;

  bool get _busy =>
      adding ||
      task?.status == DownloadStatus.pending ||
      task?.status == DownloadStatus.downloading;

  String get _tooltip {
    if (downloaded) return '当前剧集已下载';
    if (adding) return '正在加入下载队列';
    return switch (task?.status) {
      DownloadStatus.pending => '等待下载',
      DownloadStatus.downloading => '下载中 ${task!.progressPercent}',
      DownloadStatus.paused => '下载已暂停，点击继续',
      DownloadStatus.failed => '下载失败，点击重试',
      _ => '下载当前剧集',
    };
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _tooltip,
    color: downloaded ? Colors.green : Colors.orange,
    onPressed: downloaded || _busy ? null : onPressed,
    disabledColor: downloaded ? Colors.green : Colors.orange,
    icon: _buildIcon(),
  );

  Widget _buildIcon() {
    if (downloaded) return const Icon(Icons.download_done_rounded);
    if (_busy) return _buildProgress();
    return Icon(switch (task?.status) {
      DownloadStatus.paused => Icons.pause_circle_outline_rounded,
      DownloadStatus.failed => Icons.refresh_rounded,
      _ => Icons.download_rounded,
    });
  }

  Widget _buildProgress() => SizedBox(
    width: 22,
    height: 22,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: Colors.orange,
      value: !adding && task?.status == DownloadStatus.downloading
          ? task!.progress.clamp(0.0, 1.0)
          : null,
    ),
  );
}
