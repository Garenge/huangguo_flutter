import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../services/playback_session.dart';
import '../services/playback_settings_service.dart';
import '../services/playback_coordinator.dart';
import '../widgets/playback_scope.dart';
import '../models/episode.dart';
import '../models/drama.dart';
import '../models/playback_history.dart';
import '../services/huangguo_api.dart';
import '../services/html_parser.dart';
import '../services/stream_resolver.dart';
import '../services/download_service.dart';
import '../services/playback_history_service.dart';
import '../services/app_log.dart';
import '../widgets/episode_grid.dart';
import '../widgets/app_video_player.dart';

const _log = AppLog('PlayerPage');

class PlayerPage extends StatefulWidget {
  final HuangguoApi api;
  final HtmlParser htmlParser;
  final Episode? initialEpisode;
  final List<Episode> allEpisodes;
  final DownloadService? downloadService;
  final PlaybackHistoryService? historyService;
  final Duration? startPosition;
  final String? dramaName;
  final String? dramaId;
  final void Function(PlaybackHistoryEntry entry)? onPlayFromHistory;

  const PlayerPage({
    super.key,
    required this.api,
    required this.htmlParser,
    this.initialEpisode,
    this.allEpisodes = const [],
    this.downloadService,
    this.historyService,
    this.startPosition,
    this.dramaName,
    this.dramaId,
    this.onPlayFromHistory,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  StreamResolver? _resolver;
  Episode? _currentEp;

  VideoPlayerController? _controller;
  PlaybackSession? _session;
  PlaybackSettingsService? _ownedSettings;
  String? _streamUrl;
  bool _isLoading = false;
  String? _errorMessage;
  bool _autoPlay = true;

  int _loadGeneration = 0;
  bool _completionHandled = false;
  Duration? _pendingStartPosition;
  static const double _playerHeight = 240.0;

  // 历史记录
  Timer? _saveTimer;
  late List<Episode> _allEpisodes;

  @override
  void initState() {
    super.initState();
    _log.i('initState');
    _resolver = StreamResolver(widget.api);
    _pendingStartPosition = widget.startPosition;
    _allEpisodes = List.from(widget.allEpisodes);
    if (widget.initialEpisode != null) {
      _currentEp = widget.initialEpisode;
    }
    // 从历史记录进入时，重新拉取剧集列表
    if (widget.dramaId != null && widget.dramaId!.isNotEmpty) {
      _fetchEpisodes();
    }
  }

  @override
  void didUpdateWidget(PlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialEpisode != null &&
        (widget.initialEpisode != oldWidget.initialEpisode ||
            widget.startPosition != oldWidget.startPosition ||
            widget.dramaId != oldWidget.dramaId)) {
      _log.i('didUpdateWidget: new episode ${widget.initialEpisode!.name}');
      _saveHistory(source: oldWidget);
      _pendingStartPosition = widget.startPosition;
      _currentEp = widget.initialEpisode;
      _allEpisodes = List.from(widget.allEpisodes);
      _resolveAndPlay();
      if (widget.dramaId != null && widget.dramaId!.isNotEmpty) {
        _fetchEpisodes();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = PlaybackScope.maybeOf(context);
    if (_session == null) {
      final settings =
          scope?.settings ?? (_ownedSettings = PlaybackSettingsService());
      _session = PlaybackSession(
        settings,
        scope?.coordinator ?? PlaybackCoordinator(),
      );
      settings.load();
      _session!.setVisible(scope?.onlineVisible ?? true);
      if (_currentEp != null) _resolveAndPlay();
    }
    _session!.setVisible(scope?.onlineVisible ?? true);
  }

  @override
  void dispose() {
    _log.d('dispose');
    _session?.dispose();
    _ownedSettings?.dispose();
    _loadGeneration++;
    _stopSaveTimer();
    _saveHistory();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  // ----- 剧集拉取 -----

  Future<void> _fetchEpisodes() async {
    final dramaId = widget.dramaId;
    _log.i('_fetchEpisodes: dramaId=$dramaId');
    try {
      final html = await widget.api.fetchDetail(dramaId!);
      final episodes = widget.htmlParser.parseEpisodes(html);
      _log.i('_fetchEpisodes: fetched ${episodes.length} episodes');
      if (mounted && dramaId == widget.dramaId) {
        setState(() {
          _allEpisodes = episodes;
        });
      }
    } catch (e, stack) {
      _log.e('_fetchEpisodes: failed', e, stack);
    }
  }

  // ----- 历史记录保存 -----

  void _startSaveTimer() {
    _stopSaveTimer();
    _saveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _saveHistory(),
    );
  }

  void _stopSaveTimer() {
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  void _saveHistory({PlayerPage? source}) {
    final page = source ?? widget;
    if (_currentEp == null || page.historyService == null) return;
    final positionMs = _controller?.value.position.inMilliseconds ?? 0;
    if (positionMs <= 0) return;
    _log.d(
      '_saveHistory: drama=${page.dramaName}, ep=${_currentEp!.ep}, pos=${positionMs}ms',
    );
    page.historyService!.saveEntry(
      dramaName: page.dramaName ?? _currentEp!.name,
      episodeName: _currentEp!.name,
      ep: _currentEp!.ep,
      url: _currentEp!.url,
      positionMs: positionMs,
      dramaId: page.dramaId,
    );
  }

  int get _currentEpisodeIndex {
    if (_currentEp == null || _allEpisodes.isEmpty) return -1;
    return _allEpisodes.indexOf(_currentEp!);
  }

  // ----- 解析与播放 -----

  Future<void> _resolveAndPlay() async {
    final episode = _currentEp;
    if (episode == null) return;
    final generation = ++_loadGeneration;
    final previous = _controller;
    _stopSaveTimer();
    previous?.removeListener(_onControllerChanged);
    setState(() {
      _controller = null;
      _isLoading = true;
      _errorMessage = null;
      _streamUrl = null;
      _completionHandled = false;
    });
    _session!.controller = null;
    await _session!.begin();
    await _loadEpisode(episode, generation, previous);
  }

  Future<void> _loadEpisode(
    Episode episode,
    int generation,
    VideoPlayerController? previous,
  ) async {
    VideoPlayerController? candidate;
    try {
      await previous?.dispose();
      final url = await _resolver!.resolveStream(episode);
      if (!mounted || generation != _loadGeneration) return;
      candidate = VideoPlayerController.networkUrl(Uri.parse(url));
      await candidate.initialize();
      if (!mounted || generation != _loadGeneration) {
        await candidate.dispose();
        return;
      }
      await _restorePosition(candidate);
      if (!mounted || generation != _loadGeneration) {
        await candidate.dispose();
        return;
      }
      await _session!.attach(candidate);
      if (!mounted || generation != _loadGeneration) {
        await candidate.dispose();
        return;
      }
      _attachController(candidate, url);
      if (mounted && generation == _loadGeneration) await _session!.play();
    } catch (error, stack) {
      if (candidate != null && candidate != _controller) {
        await candidate.dispose();
      }
      _log.e('player_page.dart _loadEpisode: 播放加载失败', error, stack);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '播放失败：$error';
      });
    }
  }

  Future<void> _restorePosition(VideoPlayerController controller) async {
    final position = _pendingStartPosition;
    final duration = controller.value.duration;
    if (position == null || position <= Duration.zero || position >= duration) {
      return;
    }
    await controller.seekTo(position);
  }

  void _attachController(VideoPlayerController controller, String url) {
    setState(() {
      _controller = controller;
      _streamUrl = url;
      _isLoading = false;
      _pendingStartPosition = null;
    });
    controller.addListener(_onControllerChanged);
    _startSaveTimer();
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
    _saveHistory();
    if (_autoPlay && _session!.canPlay) _playNextEpisode();
  }

  void _playNextEpisode() {
    if (_currentEp == null || _allEpisodes.isEmpty) return;
    final currentIndex = _allEpisodes.indexOf(_currentEp!);
    if (currentIndex < 0 || currentIndex >= _allEpisodes.length - 1) {
      _log.i(
        '_playNextEpisode: no next episode (currentIndex=$currentIndex, total=${_allEpisodes.length})',
      );
      return;
    }
    final nextEp = _allEpisodes[currentIndex + 1];
    _log.i('_playNextEpisode: switching to ${nextEp.name}');
    _onEpisodeChanged(nextEp);
  }

  void _onEpisodeChanged(Episode ep) {
    if (_currentEp == ep && _isLoading) return;
    _saveHistory();
    _pendingStartPosition = null;
    setState(() => _currentEp = ep);
    _resolveAndPlay();
  }

  void _playPrevEpisode() {
    if (_currentEpisodeIndex <= 0) return;
    _onEpisodeChanged(_allEpisodes[_currentEpisodeIndex - 1]);
  }

  void _stopPlayback() {
    _log.i('_stopPlayback');
    _loadGeneration++;
    _pendingStartPosition = null;
    _stopSaveTimer();
    _saveHistory();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _controller = null;
    setState(() {
      _currentEp = null;
      _streamUrl = null;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  void _copyStreamUrl() {
    if (_streamUrl != null) {
      Clipboard.setData(ClipboardData(text: _streamUrl!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '\u5df2\u590d\u5236\u6d41\u5730\u5740\u5230\u526a\u8d34\u677f',
          ),
          backgroundColor: Colors.grey[800],
        ),
      );
    }
  }

  void _downloadCurrent() async {
    if (_currentEp == null) return;
    final ds = widget.downloadService;
    if (ds == null) return;

    final dramaName = widget.dramaName ?? '\u672a\u77e5\u5267\u96c6';
    final dramaId = widget.dramaId ?? '0';
    final drama = Drama(id: dramaId, name: dramaName, pic: '', remark: '');
    final task = await ds.addTask(drama, _currentEp!);
    if (task == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u8be5\u5267\u96c6\u5df2\u5728\u4e0b\u8f7d\u961f\u5217\u4e2d',
          ),
          backgroundColor: Colors.grey,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\u5df2\u52a0\u5165\u4e0b\u8f7d\u961f\u5217\uff1a${_currentEp!.name}',
          ),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showHistory() {
    if (widget.historyService == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _HistorySheet(
        historyService: widget.historyService!,
        api: widget.api,
        htmlParser: widget.htmlParser,
        onPlayEntry: (entry) {
          Navigator.pop(ctx);
          widget.onPlayFromHistory?.call(entry);
        },
        onDeleteEntry: (id) {
          widget.historyService!.deleteEntry(id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentEp == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text(
            '\u64ad\u653e',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          centerTitle: false,
          backgroundColor: Colors.black,
          actions: [
            if (widget.historyService != null)
              IconButton(
                icon: const Icon(Icons.history_rounded),
                color: Colors.orange,
                tooltip: '\u64ad\u653e\u5386\u53f2',
                onPressed: _showHistory,
              ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                size: 80,
                color: Colors.grey[800],
              ),
              const SizedBox(height: 16),
              Text(
                '\u4ece\u9996\u9875\u6216\u641c\u7d22\u9009\u62e9\u77ed\u5267\n\u70b9\u51fb\u5267\u96c6\u5373\u53ef\u5728\u6b64\u64ad\u653e',
                style: TextStyle(color: Colors.grey[500], fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.dramaName != null && widget.dramaName!.isNotEmpty)
              Text(
                widget.dramaName!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            Text(
              _currentEp!.name,
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.historyService != null)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              color: Colors.orange,
              tooltip: '\u64ad\u653e\u5386\u53f2',
              onPressed: _showHistory,
            ),
          if (widget.downloadService != null)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              color: Colors.orange,
              tooltip: '\u4e0b\u8f7d\u5f53\u524d\u5267\u96c6',
              onPressed: _downloadCurrent,
            ),
          IconButton(
            icon: const Icon(Icons.stop_rounded),
            color: Colors.redAccent,
            tooltip: '\u505c\u6b62\u64ad\u653e',
            onPressed: _stopPlayback,
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildPlayer(),
          if (_streamUrl != null && !_isLoading) _buildStreamInfo(),
          _buildEpisodeList(),
          if (widget.historyService != null)
            _HistorySection(
              historyService: widget.historyService!,
              api: widget.api,
              htmlParser: widget.htmlParser,
              onPlayEntry: (entry) {
                widget.onPlayFromHistory?.call(entry);
              },
              onViewAll: _showHistory,
            ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    return SizedBox(
      height: _playerHeight,
      child: AppVideoPlayer(
        controller: _controller,
        session: _session,
        title: _currentEp?.name ?? '播放器',
        loading: _isLoading,
        error: _errorMessage,
        onRetry: _resolveAndPlay,
        onPrevious: _currentEpisodeIndex > 0 ? _playPrevEpisode : null,
        onNext:
            _currentEpisodeIndex >= 0 &&
                _currentEpisodeIndex < _allEpisodes.length - 1
            ? _playNextEpisode
            : null,
      ),
    );
  }

  Widget _buildStreamInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey[900],
      child: Row(
        children: [
          const Icon(Icons.link, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _streamUrl!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.grey,
              ),
            ),
          ),
          GestureDetector(
            onTap: _copyStreamUrl,
            child: const Icon(
              Icons.copy_rounded,
              size: 18,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeList() {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.playlist_play_rounded,
                color: Colors.orange,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.dramaName != null &&
                        widget.dramaName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          widget.dramaName!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    const Text(
                      '\u5267\u96c6\u5207\u6362',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\u5f53\u524d: ${_currentEp!.name}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 自动播放开关
          Row(
            children: [
              SizedBox(
                height: 28,
                child: Checkbox(
                  value: _autoPlay,
                  onChanged: (v) => setState(() => _autoPlay = v ?? true),
                  activeColor: Colors.orange,
                  checkColor: Colors.black,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _autoPlay = !_autoPlay),
                child: Text(
                  '\u81ea\u52a8\u64ad\u653e\u4e0b\u4e00\u96c6',
                  style: TextStyle(
                    fontSize: 13,
                    color: _autoPlay ? Colors.orange : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          EpisodeGrid(
            episodes: _allEpisodes,
            currentEp: _currentEp!.ep,
            onTap: _onEpisodeChanged,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ===== 全屏播放页 =====

/// 播放历史底部弹窗
class _HistorySheet extends StatefulWidget {
  final PlaybackHistoryService historyService;
  final HuangguoApi api;
  final HtmlParser htmlParser;
  final void Function(PlaybackHistoryEntry entry) onPlayEntry;
  final void Function(String id) onDeleteEntry;

  const _HistorySheet({
    required this.historyService,
    required this.api,
    required this.htmlParser,
    required this.onPlayEntry,
    required this.onDeleteEntry,
  });

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  List<PlaybackHistoryEntry> _entries = [];
  final Map<String, int> _remainingMap = {}; // dedupKey -> 剩余集数
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await widget.historyService.getEntries();
    if (mounted) {
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    }
    // 后台拉取剩余集数
    await _fetchRemainingCounts();
  }

  /// 为每条有 dramaId 的历史记录拉取剧集总数，计算剩余集数
  Future<void> _fetchRemainingCounts() async {
    final seenDramaIds = <String>{};
    for (final entry in _entries) {
      if (entry.dramaId == null || entry.dramaId!.isEmpty) continue;
      if (seenDramaIds.contains(entry.dramaId)) continue;
      seenDramaIds.add(entry.dramaId!);
      try {
        final html = await widget.api.fetchDetail(entry.dramaId!);
        final episodes = widget.htmlParser.parseEpisodes(html);
        final total = episodes.length;
        // 为所有该 dramaId 的条目计算剩余
        for (final e in _entries.where((e) => e.dramaId == entry.dramaId)) {
          final currentEp = e.parsedEp;
          if (currentEp != null && total > 0) {
            final remaining = total - currentEp;
            if (remaining >= 0) {
              _remainingMap[e.dedupKey] = remaining;
            }
          }
        }
      } catch (_) {
        // 拉取失败则忽略，不显示剩余信息
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // 顶部抓手
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 标题栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '\u64ad\u653e\u5386\u53f2',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (_entries.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        widget.historyService.clearAll();
                        setState(() => _entries.clear());
                      },
                      child: const Text(
                        '\u6e05\u7a7a',
                        style: TextStyle(fontSize: 13, color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // 列表
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    )
                  : _entries.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _entries.length,
                      itemBuilder: (_, i) => _HistoryTile(
                        entry: _entries[i],
                        remainingEpisodes: _remainingMap[_entries[i].dedupKey],
                        onTap: () => widget.onPlayEntry(_entries[i]),
                        onDelete: () {
                          final entry = _entries[i];
                          widget.onDeleteEntry(entry.id);
                          setState(() => _entries.removeAt(i));
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 56, color: Colors.grey[700]),
          const SizedBox(height: 12),
          Text(
            '\u6682\u65e0\u64ad\u653e\u5386\u53f2',
            style: TextStyle(fontSize: 15, color: Colors.grey[500]),
          ),
          const SizedBox(height: 4),
          Text(
            '\u64ad\u653e\u5267\u96c6\u540e\u4f1a\u81ea\u52a8\u8bb0\u5f55',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

/// 单条历史记录
class _HistoryTile extends StatelessWidget {
  final PlaybackHistoryEntry entry;
  final int? remainingEpisodes;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.entry,
    this.remainingEpisodes,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red[800],
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.dramaName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          entry.episodeName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '\u5df2\u770b ${entry.formattedPosition}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                        if (remainingEpisodes != null) ...[
                          const SizedBox(width: 6),
                          _RemainingBadge(remaining: remainingEpisodes!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[600],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== 剩余集数标签 =====

class _RemainingBadge extends StatelessWidget {
  final int remaining;
  const _RemainingBadge({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final text = remaining <= 5 ? '还有$remaining集未看' : '继续观看';
    final color = remaining <= 5 ? Colors.orange : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: (remaining <= 5 ? Colors.orange : Colors.grey).withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

// ===== 播放历史内联区块 =====

class _HistorySection extends StatefulWidget {
  final PlaybackHistoryService historyService;
  final HuangguoApi api;
  final HtmlParser htmlParser;
  final void Function(PlaybackHistoryEntry entry) onPlayEntry;
  final VoidCallback onViewAll;

  const _HistorySection({
    required this.historyService,
    required this.api,
    required this.htmlParser,
    required this.onPlayEntry,
    required this.onViewAll,
  });

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  List<PlaybackHistoryEntry> _entries = [];
  final Map<String, int> _remainingMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await widget.historyService.getEntries();
    if (mounted) {
      setState(() {
        _entries = entries.take(5).toList(); // 只显示最近5条
        _isLoading = false;
      });
    }
    // 后台拉取剩余集数
    final seenDramaIds = <String>{};
    for (final entry in _entries) {
      if (entry.dramaId == null || entry.dramaId!.isEmpty) continue;
      if (seenDramaIds.contains(entry.dramaId)) continue;
      seenDramaIds.add(entry.dramaId!);
      try {
        final html = await widget.api.fetchDetail(entry.dramaId!);
        final episodes = widget.htmlParser.parseEpisodes(html);
        final total = episodes.length;
        for (final e in _entries.where((e) => e.dramaId == entry.dramaId)) {
          final currentEp = e.parsedEp;
          if (currentEp != null && total > 0) {
            final remaining = total - currentEp;
            if (remaining >= 0) {
              _remainingMap[e.dedupKey] = remaining;
            }
          }
        }
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              const Text(
                '播放历史',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onViewAll,
                child: const Text(
                  '查看全部',
                  style: TextStyle(fontSize: 13, color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ..._entries.map(
          (entry) => _HistoryTile(
            entry: entry,
            remainingEpisodes: _remainingMap[entry.dedupKey],
            onTap: () => widget.onPlayEntry(entry),
            onDelete: () async {
              await widget.historyService.deleteEntry(entry.id);
              _load();
            },
          ),
        ),
        const Divider(
          color: Colors.white12,
          height: 1,
          indent: 16,
          endIndent: 16,
        ),
      ],
    );
  }
}
