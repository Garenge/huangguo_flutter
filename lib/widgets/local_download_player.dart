import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/download_task.dart';
import '../services/local_media_server.dart';
import 'app_video_player.dart';

/// 已下载剧集的连续播放器，支持同专辑内切集和自动播放下一集。
class LocalDownloadPlayer extends StatefulWidget {
  final List<DownloadTask> tasks;
  final DownloadTask initialTask;

  const LocalDownloadPlayer({
    super.key,
    required this.tasks,
    required this.initialTask,
  });

  @override
  State<LocalDownloadPlayer> createState() => _LocalDownloadPlayerState();
}

class _LocalDownloadPlayerState extends State<LocalDownloadPlayer> {
  final LocalMediaServer _server = LocalMediaServer();
  VideoPlayerController? _controller;
  late List<DownloadTask> _tasks;
  late DownloadTask _currentTask;
  bool _loading = true;
  bool _autoPlay = true;
  bool _completionHandled = false;
  String? _error;
  int _loadGeneration = 0;

  int get _currentIndex =>
      _tasks.indexWhere((task) => task.id == _currentTask.id);

  @override
  void initState() {
    super.initState();
    _tasks = widget.tasks.where(_hasResource).toList();
    _currentTask = _tasks.firstWhere(
      (task) => task.id == widget.initialTask.id,
      orElse: () => _tasks.first,
    );
    _loadCurrentTask();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _server.stop();
    super.dispose();
  }

  bool _hasResource(DownloadTask task) {
    final mp4Path = _mp4Path(task);
    if (mp4Path != null && File(mp4Path).existsSync()) {
      return true;
    }
    final m3u8Path = task.filePath;
    return m3u8Path != null && File(m3u8Path).existsSync();
  }

  String? _mp4Path(DownloadTask task) {
    if (task.mp4Path != null &&
        task.mp4Path!.isNotEmpty &&
        File(task.mp4Path!).existsSync()) {
      return task.mp4Path;
    }
    final sourcePath = task.filePath;
    if (sourcePath != null &&
        sourcePath.toLowerCase().endsWith('.mp4') &&
        File(sourcePath).existsSync()) {
      return sourcePath;
    }
    return null;
  }

  Future<void> _loadCurrentTask() async {
    final generation = ++_loadGeneration;
    final previous = _controller;
    previous?.removeListener(_onControllerChanged);
    setState(() {
      _controller = null;
      _loading = true;
      _error = null;
      _completionHandled = false;
    });
    await previous?.dispose();
    _server.stop();

    VideoPlayerController? candidate;
    try {
      candidate = await _createController(_currentTask);
      await candidate.initialize();
      if (!mounted || generation != _loadGeneration) {
        await candidate.dispose();
        return;
      }
      setState(() {
        _controller = candidate;
        _loading = false;
      });
      candidate.addListener(_onControllerChanged);
      await candidate.play();
    } catch (error) {
      await candidate?.dispose();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = '播放失败：$error';
      });
    }
  }

  Future<VideoPlayerController> _createController(DownloadTask task) async {
    final mp4Path = _mp4Path(task);
    if (mp4Path != null) {
      return VideoPlayerController.file(File(mp4Path));
    }

    final sourcePath = task.filePath;
    if (sourcePath == null || !File(sourcePath).existsSync()) {
      throw StateError('文件已丢失，请重新下载');
    }
    await _server.start(File(sourcePath).parent.path);
    return VideoPlayerController.networkUrl(Uri.parse(_server.playlistUrl));
  }

  void _onControllerChanged() {
    final value = _controller?.value;
    if (value == null || value.duration <= Duration.zero || value.hasError) {
      return;
    }
    if (value.position < value.duration) {
      _completionHandled = false;
      return;
    }
    if (value.isBuffering || _completionHandled) return;
    _completionHandled = true;
    if (_autoPlay) _playNext();
  }

  void _playNext() {
    if (_currentIndex < 0 || _currentIndex >= _tasks.length - 1) return;
    _selectTask(_tasks[_currentIndex + 1]);
  }

  void _playPrevious() {
    if (_currentIndex <= 0) return;
    _selectTask(_tasks[_currentIndex - 1]);
  }

  void _selectTask(DownloadTask task) {
    if (task.id == _currentTask.id) return;
    setState(() => _currentTask = task);
    _loadCurrentTask();
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _currentTask.dramaName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 240,
            child: AppVideoPlayer(
              controller: _controller,
              title: _currentTask.episodeName,
              loading: _loading,
              error: _error,
              onRetry: _loadCurrentTask,
              onBack: () => Navigator.of(context).pop(),
              onPrevious: index > 0 ? _playPrevious : null,
              onNext: index >= 0 && index < _tasks.length - 1
                  ? _playNext
                  : null,
            ),
          ),
          Expanded(child: _buildEpisodeList()),
        ],
      ),
    );
  }

  Widget _buildEpisodeList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _tasks.length + 1,
      itemBuilder: (_, index) =>
          index == 0 ? _buildPlaylistHeader() : _buildEpisodeTile(index - 1),
    );
  }

  Widget _buildPlaylistHeader() {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          const Icon(
            Icons.playlist_play_rounded,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '已下载剧集  ${_currentIndex + 1}/${_tasks.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Text(
            '自动下一集',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Switch(
            value: _autoPlay,
            activeThumbColor: Colors.orange,
            onChanged: (value) => setState(() => _autoPlay = value),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeTile(int index) {
    final task = _tasks[index];
    final isSelected = task.id == _currentTask.id;
    return ListTile(
      selected: isSelected,
      selectedTileColor: Colors.orange.withValues(alpha: 0.12),
      leading: Icon(
        isSelected ? Icons.play_circle_filled : Icons.video_file_outlined,
        color: isSelected ? Colors.orange : Colors.grey,
      ),
      title: Text(
        task.episodeName,
        style: TextStyle(color: isSelected ? Colors.orange : Colors.white70),
      ),
      trailing: Text(
        '${index + 1}',
        style: const TextStyle(color: Colors.grey),
      ),
      onTap: () => _selectTask(task),
    );
  }
}
