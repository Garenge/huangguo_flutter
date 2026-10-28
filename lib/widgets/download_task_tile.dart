import 'package:flutter/material.dart';
import '../models/download_task.dart';

/// 下载任务列表项组件
class DownloadTaskTile extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onDelete;
  final VoidCallback? onPlay;
  final VoidCallback? onExport;

  const DownloadTaskTile({
    super.key,
    required this.task,
    this.onPause,
    this.onResume,
    this.onDelete,
    this.onPlay,
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (task.status == DownloadStatus.downloading) ...[
              const SizedBox(height: 8),
              _buildProgress(),
            ],
            if (task.status == DownloadStatus.failed && task.errorMessage != null) ...[
              const SizedBox(height: 6),
              _buildError(),
            ],
            const SizedBox(height: 8),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _statusIcon(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.dramaName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                task.episodeName,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (task.status == DownloadStatus.downloading) ...[
          Text(
            task.progressPercent,
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _statusIcon() {
    switch (task.status) {
      case DownloadStatus.pending:
        return const Icon(Icons.hourglass_empty, color: Colors.grey, size: 22);
      case DownloadStatus.downloading:
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.orange,
          ),
        );
      case DownloadStatus.paused:
        return const Icon(Icons.pause_circle, color: Colors.orange, size: 22);
      case DownloadStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 22);
      case DownloadStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 22);
    }
  }

  Widget _buildProgress() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: task.progress,
            minHeight: 4,
            backgroundColor: Colors.white10,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (task.speedText.isNotEmpty) ...[
              Text(
                task.speedText,
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
            if (task.sizeText.isNotEmpty) ...[
              if (task.speedText.isNotEmpty)
                Text(' · ', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              Text(
                task.sizeText,
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        task.errorMessage!,
        style: const TextStyle(color: Colors.redAccent, fontSize: 11),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (task.status == DownloadStatus.downloading && onPause != null)
          _actionButton(Icons.pause_rounded, '暂停', onPause!),
        if (task.status == DownloadStatus.paused && onResume != null)
          _actionButton(Icons.play_arrow_rounded, '继续', onResume!),
        if (task.status == DownloadStatus.failed && onResume != null)
          _actionButton(Icons.refresh_rounded, '重试', onResume!),
        if (task.status == DownloadStatus.completed && onPlay != null)
          _actionButton(Icons.play_circle_outline, '播放', onPlay!),
        if (task.status == DownloadStatus.completed && onExport != null)
          _actionButton(Icons.file_download_outlined, '导出', onExport!),
        if (onDelete != null)
          _actionButton(Icons.delete_outline, '删除', onDelete!),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
  }
}
