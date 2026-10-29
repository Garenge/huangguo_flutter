import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/drama.dart';
import '../models/episode.dart';
import '../models/download_task.dart';
import '../services/huangguo_api.dart';
import '../services/html_parser.dart';
import '../services/image_decryptor.dart';
import '../services/download_service.dart';
import '../services/app_log.dart';
import '../widgets/loading_indicator.dart';

const _log = AppLog('DetailPage');

class DetailPage extends StatefulWidget {
  final Drama drama;
  final HuangguoApi api;
  final HtmlParser htmlParser;
  final ImageDecryptor imageDecryptor;
  final DownloadService downloadService;
  final void Function(Episode episode, List<Episode> allEpisodes) onPlayEpisode;

  const DetailPage({
    super.key,
    required this.drama,
    required this.api,
    required this.htmlParser,
    required this.imageDecryptor,
    required this.downloadService,
    required this.onPlayEpisode,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  List<Episode> _episodes = [];
  final Map<String, DownloadStatus> _observedTaskStatuses = {};
  bool _isLoading = true;
  bool _isAddingAll = false;
  String? _errorMessage;
  Uint8List? _decryptedImage;

  @override
  void initState() {
    super.initState();
    for (final task in widget.downloadService.tasks) {
      _observedTaskStatuses[task.id] = task.status;
    }
    widget.downloadService.addListener(_onDownloadServiceChanged);
    _log.i('initState: drama=${widget.drama.name}, id=${widget.drama.id}');
    _loadDetail();
  }

  @override
  void dispose() {
    widget.downloadService.removeListener(_onDownloadServiceChanged);
    super.dispose();
  }

  void _onDownloadServiceChanged() {
    final completedEpisodes = <String>[];
    final activeTaskIds = <String>{};
    for (final task in widget.downloadService.tasks) {
      activeTaskIds.add(task.id);
      final previousStatus = _observedTaskStatuses[task.id];
      if (task.status == DownloadStatus.completed &&
          previousStatus != null &&
          previousStatus != DownloadStatus.completed) {
        completedEpisodes.add(task.episodeName);
      }
      _observedTaskStatuses[task.id] = task.status;
    }
    _observedTaskStatuses.removeWhere(
      (taskId, _) => !activeTaskIds.contains(taskId),
    );

    if (!mounted) return;
    setState(() {});
    for (final episodeName in completedEpisodes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('下载完成：$episodeName'),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadDetail() async {
    _log.i('_loadDetail: start');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final html = await widget.api.fetchDetail(widget.drama.id);
      final episodes = widget.htmlParser.parseEpisodes(html);
      final coverUrl = widget.htmlParser.parseDetailCover(html);
      final image =
          await _loadImage(coverUrl) ??
          (coverUrl == widget.drama.pic
              ? null
              : await _loadImage(widget.drama.pic));
      setState(() {
        _episodes = episodes;
        _decryptedImage = image;
        _isLoading = false;
      });
      _log.i('_loadDetail: success, episodes=${_episodes.length}');
    } catch (e, stack) {
      _log.e('_loadDetail: failed', e, stack);
      setState(() {
        _isLoading = false;
        _errorMessage = '加载失败：$e';
      });
    }
  }

  Future<Uint8List?> _loadImage(String imageUrl) async {
    if (imageUrl.isEmpty) return null;
    try {
      final bytes = await widget.api.fetchImageBytes(imageUrl);
      return widget.imageDecryptor.decrypt(Uint8List.fromList(bytes));
    } catch (e, stack) {
      _log.e('_loadImage: failed', e, stack);
      return null;
    }
  }

  void _onEpisodeTap(Episode episode) {
    _log.i('_onEpisodeTap: ${episode.name}');
    widget.onPlayEpisode(episode, _episodes);
  }

  void _onDownloadEpisode(Episode episode) async {
    _log.i('_onDownloadEpisode: ${episode.name}');
    final task = await widget.downloadService.addTask(widget.drama, episode);
    if (task == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('该剧集已在下载队列中'),
          backgroundColor: Colors.grey,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已加入下载队列：${episode.name}'),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onDownloadAll() async {
    if (_isAddingAll || _episodes.isEmpty) return;

    setState(() => _isAddingAll = true);
    try {
      final result = await widget.downloadService.addTasks(
        widget.drama,
        _episodes,
      );
      if (!mounted) return;
      final message = result.skippedCount == 0
          ? '已加入 ${result.addedCount} 集下载任务'
          : '新增 ${result.addedCount} 集，跳过 ${result.skippedCount} 集';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e, stack) {
      _log.e('_onDownloadAll: failed', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加入下载失败：$e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: Text(widget.drama.name),
        backgroundColor: const Color(0xFF0D0D0D),
      ),
      body: _isLoading
          ? const LoadingIndicator(message: '正在加载详情...')
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: Colors.grey[400])),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadDetail, child: const Text('重试')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildCoverImage(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.drama.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.drama.remark.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.drama.remark,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[300],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '共 ${_episodes.length} 集',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Icon(
                Icons.playlist_play_rounded,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '剧集列表',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _isAddingAll || _episodes.isEmpty
                    ? null
                    : _onDownloadAll,
                icon: _isAddingAll
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 16),
                label: Text(_isAddingAll ? '加入中' : '全部下载'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${_episodes.length} 集',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEpisodeList(),
        ],
      ),
    );
  }

  Widget _buildEpisodeList() {
    if (_episodes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('没有解析到剧集', style: TextStyle(color: Colors.grey)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _episodes.map((ep) {
        final task = widget.downloadService.taskForEpisode(
          widget.drama.id,
          ep.ep,
        );
        return _EpisodeChip(
          episode: ep,
          downloadStatus: task?.status,
          isDownloaded: widget.downloadService.isEpisodeDownloaded(
            widget.drama.id,
            ep.ep,
          ),
          onTap: () => _onEpisodeTap(ep),
          onDownload: () => _onDownloadEpisode(ep),
        );
      }).toList(),
    );
  }

  Widget _buildCoverImage() {
    const width = 160.0;
    const height = 224.0;
    if (_decryptedImage != null) {
      return Image.memory(
        _decryptedImage!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(width, height),
      );
    }
    return _placeholder(width, height);
  }

  Widget _placeholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[900],
      child: const Icon(Icons.movie_outlined, size: 48, color: Colors.grey),
    );
  }
}

/// 带独立播放区和下载按钮的剧集条目。
class _EpisodeChip extends StatelessWidget {
  final Episode episode;
  final DownloadStatus? downloadStatus;
  final bool isDownloaded;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const _EpisodeChip({
    required this.episode,
    required this.downloadStatus,
    required this.isDownloaded,
    required this.onTap,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final isInProgress =
        downloadStatus == DownloadStatus.pending ||
        downloadStatus == DownloadStatus.downloading ||
        downloadStatus == DownloadStatus.paused;
    final statusIcon = isDownloaded
        ? const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green)
        : isInProgress
        ? const Icon(Icons.downloading_rounded, size: 16, color: Colors.orange)
        : null;

    return Material(
      color: isDownloaded
          ? Colors.green.withOpacity(0.16)
          : Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (statusIcon != null) ...[
                      statusIcon,
                      const SizedBox(width: 6),
                    ],
                    Text(
                      episode.name,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            if (!isDownloaded)
              IconButton(
                onPressed: isInProgress ? null : onDownload,
                icon: Icon(
                  isInProgress
                      ? Icons.downloading_rounded
                      : Icons.download_rounded,
                  size: 19,
                ),
                color: Colors.orange,
                disabledColor: Colors.orange.withOpacity(0.7),
                tooltip: isInProgress ? '下载中' : '下载${episode.name}',
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
          ],
        ),
      ),
    );
  }
}
