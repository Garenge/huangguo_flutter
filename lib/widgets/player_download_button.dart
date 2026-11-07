import 'package:flutter/material.dart';

import '../models/drama.dart';
import '../models/episode.dart';
import '../services/app_log.dart';
import '../services/download_service.dart';
import 'app_notice.dart';
import 'player_download_indicator.dart';

class PlayerDownloadButton extends StatefulWidget {
  const PlayerDownloadButton({
    super.key,
    required this.service,
    required this.drama,
    required this.episode,
  });

  final DownloadService service;
  final Drama drama;
  final Episode episode;

  @override
  State<PlayerDownloadButton> createState() => _PlayerDownloadButtonState();
}

class _PlayerDownloadButtonState extends State<PlayerDownloadButton> {
  bool _adding = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) => PlayerDownloadIndicator(
      adding: _adding,
      downloaded: widget.service.isResourceDownloaded(
        widget.drama,
        widget.episode,
      ),
      task: widget.service.taskForEpisode(widget.drama.id, widget.episode.ep),
      onPressed: _download,
    ),
  );

  Future<void> _download() async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      await _enqueue();
    } catch (error, stack) {
      const AppLog(
        'player_download_button.dart',
      ).e('_download: 加入下载队列失败', error, stack);
      if (mounted) showAppNotice(context, '加入下载失败，请重试');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _enqueue() async {
    final service = widget.service;
    final drama = widget.drama;
    final episode = widget.episode;
    final task = service.taskForEpisode(drama.id, episode.ep);
    if (service.isResourceDownloaded(drama, episode)) return;
    if (task != null) {
      await service.resumeTask(task.id);
    } else {
      await service.addTask(drama, episode);
    }
    if (mounted) {
      showAppNotice(
        context,
        '已加入下载队列：${episode.name}',
        backgroundColor: Colors.green[700],
      );
    }
  }
}
