import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/drama.dart';
import '../models/download_task.dart';
import '../models/storage_usage.dart';
import '../services/album_update_checker.dart';
import '../services/download_service.dart';
import '../services/download_file_service.dart';
import '../services/download_catalog.dart';
import '../services/download_settings_service.dart';
import '../services/download_storage_controller.dart';
import '../services/storage_usage_service.dart';
import '../services/app_log.dart';
import '../services/huangguo_api.dart';
import '../services/html_parser.dart';
import '../services/video_conversion_service.dart';
import '../widgets/download_task_tile.dart';
import '../widgets/download_storage_panel.dart';
import '../widgets/local_download_player.dart';
import '../widgets/library_scope.dart';
import '../widgets/share_origin.dart';
import '../widgets/app_notice.dart';

const _log = AppLog('DownloadPage');
const _automaticCheckInterval = Duration(minutes: 30);

enum _AlbumAction { check, detail, favorite, delete }

/// 下载管理页
class DownloadPage extends StatefulWidget {
  final DownloadService downloadService;
  final HuangguoApi api;
  final HtmlParser htmlParser;
  final void Function(Drama drama) onOpenDetail;
  final DownloadSettingsService? downloadSettings;
  final DateTime Function() now;
  final StorageUsageService? storageUsageService;

  const DownloadPage({
    super.key,
    required this.downloadService,
    required this.api,
    required this.htmlParser,
    required this.onOpenDetail,
    this.downloadSettings,
    this.now = DateTime.now,
    this.storageUsageService,
  });

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late final VideoConversionService _conversionService;
  late final AlbumUpdateChecker _updateChecker;
  late final DownloadStorageController _storageController;
  Timer? _automaticCheckTimer;

  final Set<String> _convertingGroups = {};
  final Set<String> _checkingAlbums = {};
  final Map<String, int> _albumUpdates = {};
  final Map<String, String> _albumCoverUrls = {};
  final Map<String, DateTime> _lastAlbumCheckAt = {};
  final Map<String, String> _conversionStatus = {};
  final Map<String, int> _conversionCompleted = {};
  final Set<String> _collapsedAlbums = {};
  final ScrollController _completedScrollController = ScrollController();
  final TextEditingController _completedSearchController = TextEditingController();
  late final DownloadSettingsService _downloadSettings;
  DownloadSortMode _completedSortMode = DownloadSortMode.recent;
  bool _sortModeSelected = false;
  bool _isAppInForeground = true;
  bool _isAutomaticCheckRunning = false;

  bool get _isMobile => DownloadFileService.isMobile;

  bool _hasValidMp4(DownloadTask task) {
    if (task.hasMp4 && File(task.mp4Path!).existsSync()) return true;

    final sourcePath = task.filePath;
    return sourcePath != null &&
        sourcePath.toLowerCase().endsWith('.mp4') &&
        File(sourcePath).existsSync();
  }

  @override
  void initState() {
    super.initState();
    _downloadSettings = widget.downloadSettings ?? DownloadSettingsService();
    _storageController = DownloadStorageController(
      widget.downloadService,
      widget.storageUsageService ?? StorageUsageService(),
    );
    unawaited(_loadSortMode());
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _conversionService = VideoConversionService(widget.downloadService);
    _updateChecker = AlbumUpdateChecker(api: widget.api, parser: widget.htmlParser);
    WidgetsBinding.instance.addObserver(this);
    _automaticCheckTimer = Timer.periodic(_automaticCheckInterval, (_) => _runAutomaticCheck());
    widget.downloadService.addListener(_onServiceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_runAutomaticCheck());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _automaticCheckTimer?.cancel();
    _storageController.dispose();
    widget.downloadService.removeListener(_onServiceChanged);
    _completedScrollController.dispose();
    _completedSearchController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadSortMode() async {
    await _downloadSettings.load();
    if (!mounted || _sortModeSelected) return;
    setState(() => _completedSortMode = _downloadSettings.sortMode);
  }

  void _selectSortMode(DownloadSortMode mode) {
    setState(() {
      _sortModeSelected = true;
      _completedSortMode = mode;
    });
    unawaited(_downloadSettings.setSortMode(mode));
  }

  void _onTabChanged() {
    _updateStorageActivity();
    if (mounted) setState(() {});
  }

  void _updateStorageActivity() {
    _storageController.setActive(_isAppInForeground && _tabController.index == 1);
  }

  DownloadService get _ds => widget.downloadService;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;
    _updateStorageActivity();
    if (_isAppInForeground) unawaited(_runAutomaticCheck());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('下载管理'),
        backgroundColor: const Color(0xFF0D0D0D),
        actions: [
          if (_tabController.index == 1 && _ds.completedTasks.isNotEmpty) _buildAlbumToggleButton(),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: '下载中 (${_ds.downloadingTasks.length + _ds.pendingTasks.length})'),
            Tab(text: '已完成 (${_completedAlbums().length} 套)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildDownloadingTab(), _buildCompletedTab()],
      ),
    );
  }

  Widget _buildAlbumToggleButton() {
    final albumKeys = _completedAlbums().keys.toSet();
    final allCollapsed = albumKeys.every(_collapsedAlbums.contains);
    return TextButton.icon(
      onPressed: () => _toggleAllAlbums(albumKeys, allCollapsed),
      icon: Icon(allCollapsed ? Icons.unfold_more_rounded : Icons.unfold_less_rounded),
      label: Text(allCollapsed ? '全部展开' : '全部折叠'),
      style: TextButton.styleFrom(foregroundColor: Colors.orange),
    );
  }

  void _toggleAllAlbums(Set<String> albumKeys, bool allCollapsed) {
    setState(() {
      if (allCollapsed) {
        _collapsedAlbums.removeAll(albumKeys);
      } else {
        _collapsedAlbums.addAll(albumKeys);
      }
    });
  }

  Widget _buildDownloadingTab() {
    final tasks = [
      ..._ds.downloadingTasks,
      ..._ds.pendingTasks,
      ..._ds.tasks.where((t) => t.status == DownloadStatus.failed),
    ];

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_outlined, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text('暂无下载任务', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            const SizedBox(height: 4),
            Text('在详情页点击剧集旁的下载按钮', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: tasks.length,
      itemBuilder: (_, index) {
        final task = tasks[index];
        return DownloadTaskTile(
          task: task,
          onPause: () => _ds.pauseTask(task.id),
          onResume: () => _ds.resumeTask(task.id),
          onDelete: () => _confirmDelete(task),
          onPlay: task.status == DownloadStatus.completed ? () => _playLocalFile(task) : null,
        );
      },
    );
  }

  Widget _buildCompletedTab() {
    final completed = DownloadCatalog.filter(_ds.completedTasks, _completedSearchController.text);

    final grouped = DownloadCatalog.groupAndSort(completed, _completedSortMode);
    _pruneAlbumCheckState(grouped.keys.toSet());

    return Column(
      children: [
        _buildCompletedToolbar(),
        Expanded(
          child: CustomScrollView(
            controller: _completedScrollController,
            slivers: [
              if (completed.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _buildCompletedEmptyState()),
              for (final entry in grouped.entries)
                SliverMainAxisGroup(
                  key: ValueKey(entry.key),
                  slivers: _buildAlbumSlivers(entry.key, entry.value),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
        DownloadStoragePanel(controller: _storageController),
      ],
    );
  }

  Widget _buildCompletedToolbar() {
    final totalCount = _ds.completedTasks.length;
    final resultCount = DownloadCatalog.filter(
      _ds.completedTasks,
      _completedSearchController.text,
    ).length;
    final hasQuery = _completedSearchController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        children: [
          TextField(
            controller: _completedSearchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: '搜索剧名、剧集或拼音',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              suffixIcon: hasQuery
                  ? IconButton(
                      tooltip: '清除搜索',
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _completedSearchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF242424),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                hasQuery ? '找到 $resultCount / $totalCount 集' : '$totalCount 集',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const Spacer(),
              PopupMenuButton<DownloadSortMode>(
                tooltip: '排序方式',
                initialValue: _completedSortMode,
                onSelected: _selectSortMode,
                itemBuilder: (_) => [
                  for (final mode in DownloadSortMode.values)
                    PopupMenuItem(value: mode, child: Text(mode.label)),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sort_rounded, size: 17, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      _completedSortMode.label,
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedEmptyState() {
    final hasQuery = _completedSearchController.text.trim().isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQuery ? Icons.search_off_rounded : Icons.check_circle_outline,
            size: 64,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery ? '没有匹配的已下载资源' : '暂无已完成下载',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          if (hasQuery) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _completedSearchController.clear();
                setState(() {});
              },
              child: const Text('清除搜索'),
            ),
          ],
        ],
      ),
    );
  }

  void _pruneAlbumCheckState(Set<String> activeKeys) {
    _albumUpdates.removeWhere((key, _) => !activeKeys.contains(key));
    _albumCoverUrls.removeWhere((key, _) => !activeKeys.contains(key));
    _lastAlbumCheckAt.removeWhere((key, _) => !activeKeys.contains(key));
    _checkingAlbums.removeWhere((key) => !activeKeys.contains(key));
  }

  List<Widget> _buildAlbumSlivers(String dramaKey, List<DownloadTask> tasks) {
    final orderedTasks = _conversionService.sortTasks(tasks);
    return [
      PinnedHeaderSliver(child: _buildAlbumHeaderContent(dramaKey, orderedTasks)),
      if (!_collapsedAlbums.contains(dramaKey))
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, index) => _buildCompletedTaskTile(orderedTasks[index]),
              childCount: orderedTasks.length,
            ),
          ),
        ),
    ];
  }

  Widget _buildAlbumHeaderContent(String dramaKey, List<DownloadTask> tasks) {
    final orderedTasks = _conversionService.sortTasks(tasks);
    final updateCount = _albumUpdates[dramaKey] ?? 0;
    final isChecking = _checkingAlbums.contains(dramaKey);
    return SizedBox(
      height: 66,
      child: Material(
        color: const Color(0xFF242424),
        child: InkWell(
          onTap: () => setState(() {
            if (!_collapsedAlbums.add(dramaKey)) {
              _collapsedAlbums.remove(dramaKey);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.folder_rounded, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dramaKey,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _conversionStatus[dramaKey] ?? _watchSummary(tasks),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (orderedTasks.any((task) => !_hasValidMp4(task)))
                  _buildGroupConvertButton(dramaKey, orderedTasks),
                _buildAlbumMoreButton(dramaKey, orderedTasks, updateCount, isChecking),
                Icon(
                  _collapsedAlbums.contains(dramaKey)
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _watchSummary(List<DownloadTask> tasks) {
    final library = LibraryScope.maybeOf(context);
    final count = tasks
        .where((task) => library?.hasWatched(task.dramaId, task.dramaName, ep: task.ep) ?? false)
        .length;
    return '看过 $count / 已下载 ${tasks.length} 集';
  }

  Widget _buildAlbumMoreButton(
    String dramaKey,
    List<DownloadTask> tasks,
    int updateCount,
    bool isChecking,
  ) {
    return PopupMenuButton<_AlbumAction>(
      tooltip: '更多',
      onSelected: (action) => _handleAlbumAction(action, dramaKey, tasks),
      itemBuilder: (_) => [
        PopupMenuItem<_AlbumAction>(
          enabled: false,
          child: ListenableBuilder(
            listenable: _storageController,
            builder: (_, _) {
              final usage = _storageController.usage;
              final size = usage == null && _storageController.refreshing
                  ? '统计中…'
                  : formatStorageBytes(usage?.albumBytes[dramaKey]);
              return Text('本套占用：$size', style: const TextStyle(color: Colors.grey));
            },
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _AlbumAction.check,
          enabled: !isChecking,
          child: Text(isChecking ? '检测中' : '检测更新'),
        ),
        PopupMenuItem(value: _AlbumAction.detail, child: const Text('查看详情')),
        PopupMenuItem(
          value: _AlbumAction.favorite,
          child: Text(_isAlbumFavorite(tasks) ? '取消收藏' : '收藏'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _AlbumAction.delete,
          child: Text('删除整套', style: TextStyle(color: Colors.red)),
        ),
      ],
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.more_vert_rounded),
          if (updateCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.lightBlueAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isAlbumFavorite(List<DownloadTask> tasks) {
    if (tasks.isEmpty) return false;
    return LibraryScope.maybeOf(context)?.isFavorite(tasks.first.dramaId) ?? false;
  }

  void _handleAlbumAction(_AlbumAction action, String dramaKey, List<DownloadTask> tasks) {
    switch (action) {
      case _AlbumAction.check:
        unawaited(_checkAlbum(dramaKey, tasks));
      case _AlbumAction.detail:
        _openAlbumDetail(tasks);
      case _AlbumAction.favorite:
        _toggleAlbumFavorite(tasks);
      case _AlbumAction.delete:
        _confirmDeleteAlbum(tasks);
    }
  }

  Future<void> _toggleAlbumFavorite(List<DownloadTask> tasks) async {
    if (tasks.isEmpty) return;
    final library = LibraryScope.maybeOf(context);
    if (library == null) return;
    final task = tasks.first;
    final drama = Drama(id: task.dramaId, name: task.dramaName, pic: task.dramaPic, remark: '');
    await library.toggleFavorite(drama);
    if (mounted) setState(() {});
  }

  void _confirmDeleteAlbum(List<DownloadTask> tasks) {
    if (tasks.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('删除整套文件', style: TextStyle(color: Colors.white)),
        content: _buildStorageText(
          (usage) =>
              '确定删除「${tasks.first.dramaName}」的 ${tasks.length} 集已下载文件吗？\n'
              '文件占用：${_storageSize(_tasksBytes(usage, tasks))}\n'
              '文件将被永久删除。',
          color: Colors.grey[300],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              unawaited(_ds.deleteCompletedFiles(tasks.map((task) => task.id)));
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedTaskTile(DownloadTask task) {
    final hasMp4 = _hasValidMp4(task);
    final watched =
        LibraryScope.maybeOf(context)?.hasWatched(task.dramaId, task.dramaName, ep: task.ep) ??
        false;
    return Material(
      color: Colors.grey[900],
      child: ListTile(
        dense: true,
        onTap: () => _playLocalFile(task),
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        minLeadingWidth: 20,
        horizontalTitleGap: 8,
        subtitle: _buildStorageText(
          (usage) =>
              '${watched ? '看过 · ' : ''}${_storageSize(usage?.taskBytes[task.id])}',
        ),
        leading: Icon(
          hasMp4 ? Icons.video_file : Icons.play_circle_outline,
          color: Colors.green,
          size: 20,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                task.episodeName,
                style: TextStyle(color: watched ? Colors.white38 : Colors.white70, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _FormatBadge(
              label: hasMp4 ? 'MP4' : '源文件',
              color: hasMp4 ? Colors.green : Colors.orange,
            ),
          ],
        ),
        trailing: _buildCompletedTaskActions(task, hasMp4),
      ),
    );
  }

  String _storageSize(int? bytes) {
    if (_storageController.usage == null && _storageController.refreshing) {
      return '统计中…';
    }
    return formatStorageBytes(bytes);
  }

  int? _tasksBytes(StorageUsage? usage, List<DownloadTask> tasks) {
    var total = 0;
    for (final task in tasks) {
      final bytes = usage?.taskBytes[task.id];
      if (bytes == null) return null;
      total += bytes;
    }
    return total;
  }

  Widget _buildStorageText(
    String Function(StorageUsage? usage) text, {
    Color? color,
  }) {
    return ListenableBuilder(
      listenable: _storageController,
      builder: (_, _) => Text(
        text(_storageController.usage),
        style: TextStyle(color: color ?? Colors.white38),
      ),
    );
  }

  Widget _buildCompletedTaskActions(DownloadTask task, bool hasMp4) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _completedActionButton(
          icon: Icons.play_arrow_rounded,
          tooltip: '播放',
          color: Colors.orange,
          onPressed: () => _playLocalFile(task),
        ),
        _completedActionButton(
          icon: _isMobile ? Icons.share_rounded : Icons.folder_open,
          tooltip: hasMp4
              ? (_isMobile ? '分享 MP4' : '定位 MP4')
              : (_isMobile ? '分享原始资源 ZIP' : '查看文件夹'),
          onPressed: () => _openTaskResource(task),
        ),
        if (!hasMp4)
          _completedActionButton(
            icon: Icons.transform_rounded,
            tooltip: '转换为 MP4',
            onPressed: () => _exportAndShare(task),
          ),
        _completedActionButton(
          icon: Icons.delete_outline,
          tooltip: '删除文件',
          color: Colors.grey,
          onPressed: () => _confirmDeleteCompleted(task),
        ),
      ],
    );
  }

  Widget _completedActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color color = Colors.blueGrey,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      color: color,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      visualDensity: VisualDensity.standard,
      onPressed: onPressed,
    );
  }

  Widget _buildGroupConvertButton(String dramaKey, List<DownloadTask> tasks) {
    final isConverting = _convertingGroups.contains(dramaKey);
    final completedCount = _conversionCompleted[dramaKey] ?? 0;
    final label = isConverting ? '转换 $completedCount/${tasks.length}' : '一键转 MP4';

    return TextButton.icon(
      onPressed: isConverting ? null : () => _convertGroup(dramaKey, tasks),
      icon: isConverting
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.transform_rounded, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: Colors.orange,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Future<void> _convertGroup(String dramaKey, List<DownloadTask> tasks) async {
    if (_convertingGroups.contains(dramaKey)) return;

    setState(() {
      _convertingGroups.add(dramaKey);
      _conversionCompleted[dramaKey] = 0;
      _conversionStatus[dramaKey] = '准备转换';
    });

    final result = await _conversionService.convertTasks(
      tasks,
      onProgress: (completedCount, status) {
        _updateConversionProgress(dramaKey, completedCount, status);
      },
    );

    if (!mounted) return;
    setState(() {
      _convertingGroups.remove(dramaKey);
      _conversionStatus.remove(dramaKey);
      _conversionCompleted.remove(dramaKey);
    });
    _showSnack(
      '转换完成：新增 ${result.convertedCount} 集，'
      '已存在 ${result.skippedCount} 集，失败 ${result.failedCount} 集',
    );
  }

  void _updateConversionProgress(String dramaKey, int completedCount, String status) {
    if (!mounted) return;
    setState(() {
      _conversionCompleted[dramaKey] = completedCount;
      _conversionStatus[dramaKey] = status;
    });
  }

  // ---------- 转换、分享和查看原始文件 ----------

  Future<void> _exportAndShare(DownloadTask task) async {
    if (_hasValidMp4(task)) {
      await _openMp4(task);
      return;
    }

    if (_isMobile) {
      await _exportMobile(task);
    } else {
      await _exportDesktop(task);
    }
  }

  Future<void> _exportMobile(DownloadTask task) async {
    _showSnack('正在转换为 MP4...');
    final result = await _conversionService.exportTask(task);

    if (!mounted) return;

    if (result.success && result.outputPath != null) {
      final deleteSource = await _confirmDeleteSource(task);
      if (!mounted) return;
      if (deleteSource) {
        await _deleteSourceFiles(task);
      }
      if (!mounted) return;
      try {
        await DownloadFileService.openOrShareFile(
          filePath: result.outputPath!,
          shareTitle: '${task.dramaName} - ${task.episodeName}.mp4',
          sharePositionOrigin: shareOriginFor(context),
        );
      } catch (e) {
        _showSnack('分享失败: $e');
      }
    } else {
      _showSnack('转换失败: ${result.error}');
    }
  }

  Future<void> _exportDesktop(DownloadTask task) async {
    final outputPath = _conversionService.expectedMp4Path(task);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ExportProgressDialog(
        stream: _runExport(task),
        outputPath: outputPath,
        isDesktop: true,
        onSuccess: () => _confirmDeleteSourceAndDelete(task),
      ),
    );
  }

  Future<bool> _confirmDeleteSource(DownloadTask task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('删除源文件？', style: TextStyle(color: Colors.white)),
        content: const Text(
          'MP4 已转换成功，是否删除原始 m3u8、TS 和密钥文件？',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('保留源文件')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除源文件', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return shouldDelete == true;
  }

  Future<void> _deleteSourceFiles(DownloadTask task) async {
    try {
      await _ds.deleteSourceFiles(task.id);
      _showSnack('源文件已删除，已保留 MP4');
    } catch (e, stack) {
      _log.e('_deleteSourceFiles: failed episode=${task.episodeName}', e, stack);
      _showSnack('删除源文件失败：$e');
    }
  }

  Future<void> _confirmDeleteSourceAndDelete(DownloadTask task) async {
    if (!mounted) return;
    final shouldDelete = await _confirmDeleteSource(task);
    if (shouldDelete) {
      await _deleteSourceFiles(task);
    }
  }

  Stream<String> _runExport(DownloadTask task) async* {
    yield '正在转换为 MP4...';
    final result = await _conversionService.exportTask(task);
    if (result.success) {
      yield '转换完成';
    } else {
      yield '转换失败: ${result.error}';
    }
  }

  Future<void> _openTaskResource(DownloadTask task) async {
    try {
      if (_hasValidMp4(task)) {
        await _openMp4(task);
      } else {
        final folderPath = _ds.episodeDirectoryFor(task);
        await DownloadFileService.openOrShareFolder(
          folderPath: folderPath,
          shareTitle: '${task.dramaName} - ${task.episodeName} 原始资源',
          sharePositionOrigin: shareOriginFor(context),
        );
      }
    } catch (e, stack) {
      _log.e('_openTaskResource: failed episode=${task.episodeName}', e, stack);
      _showSnack('操作失败：$e');
    }
  }

  Future<void> _openMp4(DownloadTask task) async {
    final mp4Path = task.mp4Path != null && File(task.mp4Path!).existsSync()
        ? task.mp4Path
        : task.filePath;
    if (mp4Path == null || mp4Path.isEmpty) {
      _showSnack('MP4 文件路径不存在');
      return;
    }

    try {
      await DownloadFileService.openOrShareFile(
        filePath: mp4Path,
        shareTitle: '${task.dramaName} - ${task.episodeName}.mp4',
        sharePositionOrigin: shareOriginFor(context),
      );
    } catch (e, stack) {
      _log.e('_openMp4: failed episode=${task.episodeName}', e, stack);
      _showSnack('MP4 操作失败：$e');
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      showAppNotice(context, msg);
    }
  }

  Future<void> _checkAlbum(
    String dramaKey,
    List<DownloadTask> tasks, {
    bool automatic = false,
  }) async {
    if (_checkingAlbums.contains(dramaKey) || tasks.isEmpty) return;

    final downloadedEpisodes = tasks
        .where(_ds.isEpisodeDownloadedForTask)
        .map((task) => task.ep)
        .where((ep) => ep.isNotEmpty)
        .toSet();
    if (mounted) {
      setState(() => _checkingAlbums.add(dramaKey));
    }

    try {
      final result = await _updateChecker.check(
        dramaId: tasks.first.dramaId,
        downloadedEpisodeIds: downloadedEpisodes,
      );
      final previousCount = _albumUpdates[dramaKey];
      if (!mounted) return;
      setState(() {
        _albumUpdates[dramaKey] = result.newEpisodes.length;
        if (result.coverUrl.isNotEmpty) {
          _albumCoverUrls[dramaKey] = result.coverUrl;
        }
        _lastAlbumCheckAt[dramaKey] = widget.now();
        _checkingAlbums.remove(dramaKey);
      });

      final shouldNotifyAutomatically =
          automatic &&
          result.hasUpdates &&
          (previousCount == null || result.newEpisodes.length > previousCount);
      if (result.hasUpdates && (!automatic || shouldNotifyAutomatically)) {
        _showUpdateSnack(tasks, result.newEpisodes.length);
      }
    } catch (e, stack) {
      _log.e('_checkAlbum: failed dramaId=${tasks.first.dramaId}', e, stack);
      if (!mounted) return;
      setState(() {
        _checkingAlbums.remove(dramaKey);
        _lastAlbumCheckAt[dramaKey] = widget.now();
      });
      if (!automatic) _showSnack('检测更新失败：$e');
    }
  }

  void _showUpdateSnack(List<DownloadTask> tasks, int updateCount) {
    final message = updateCount == 0
        ? '暂无更新：${tasks.first.dramaName}'
        : '发现 $updateCount 集更新：${tasks.first.dramaName}';
    showAppNotice(
      context,
      message,
      action: SnackBarAction(label: '查看', onPressed: () => _openAlbumDetail(tasks)),
    );
  }

  void _openAlbumDetail(List<DownloadTask> tasks) {
    if (tasks.isEmpty) return;
    final task = tasks.first;
    final dramaKey = '${task.dramaName} (${task.dramaId})';
    final coverUrl =
        _albumCoverUrls[dramaKey] ??
        tasks.firstWhere((item) => item.dramaPic.isNotEmpty, orElse: () => task).dramaPic;
    widget.onOpenDetail(Drama(id: task.dramaId, name: task.dramaName, pic: coverUrl, remark: ''));
  }

  bool get _canAutomaticallyCheck =>
      mounted &&
      _isAppInForeground &&
      _checkingAlbums.isEmpty &&
      _convertingGroups.isEmpty &&
      _ds.downloadingTasks.isEmpty &&
      _ds.pendingTasks.isEmpty;

  Future<void> _runAutomaticCheck() async {
    if (_isAutomaticCheckRunning || !_canAutomaticallyCheck) return;
    _isAutomaticCheckRunning = true;
    try {
      final grouped = _completedAlbums();
      for (final entry in grouped.entries) {
        if (!_canAutomaticallyCheck) break;
        final currentTasks = _completedAlbums()[entry.key];
        if (currentTasks == null) continue;
        final lastCheck = _lastAlbumCheckAt[entry.key];
        if (lastCheck != null && widget.now().difference(lastCheck) < _automaticCheckInterval) {
          continue;
        }
        await _checkAlbum(entry.key, currentTasks, automatic: true);
      }
    } finally {
      _isAutomaticCheckRunning = false;
    }
  }

  Map<String, List<DownloadTask>> _completedAlbums() {
    final grouped = <String, List<DownloadTask>>{};
    for (final task in _ds.completedTasks) {
      final key = '${task.dramaName} (${task.dramaId})';
      grouped.putIfAbsent(key, () => []).add(task);
    }
    return grouped;
  }

  // ---------- 删除 ----------

  void _confirmDelete(DownloadTask task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('删除任务', style: TextStyle(color: Colors.white)),
        content: Text(
          '确定要删除「${task.dramaName} - ${task.episodeName}」吗？',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _ds.deleteTask(task.id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCompleted(DownloadTask task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('删除文件', style: TextStyle(color: Colors.white)),
        content: _buildStorageText(
          (usage) =>
              '确定要删除「${task.dramaName} - ${task.episodeName}」吗？\n'
              '文件占用：${_storageSize(usage?.taskBytes[task.id])}\n'
              '文件将被永久删除。',
          color: Colors.grey[300],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _ds.deleteCompletedFile(task.id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ---------- 播放 ----------

  void _playLocalFile(DownloadTask task) {
    final tasks = _conversionService
        .sortTasks(
          _ds.completedTasks.where((candidate) => candidate.dramaId == task.dramaId).toList(),
        )
        .where(_hasPlayableResource)
        .toList();
    if (tasks.isEmpty) {
      _showSnack('文件已丢失，请重新下载');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocalDownloadPlayer(
          tasks: tasks,
          initialTask: task,
          onDelete: (task) => _ds.deleteCompletedFile(task.id),
        ),
      ),
    );
  }

  bool _hasPlayableResource(DownloadTask task) {
    if (_hasValidMp4(task)) return true;
    return task.filePath != null && File(task.filePath!).existsSync();
  }
}

class _FormatBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _FormatBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ============================================================
//  导出进度弹窗（桌面端）
// ============================================================

class _ExportProgressDialog extends StatefulWidget {
  final Stream<String> stream;
  final String outputPath;
  final bool isDesktop;
  final Future<void> Function()? onSuccess;

  const _ExportProgressDialog({
    required this.stream,
    required this.outputPath,
    this.isDesktop = false,
    this.onSuccess,
  });

  @override
  State<_ExportProgressDialog> createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<_ExportProgressDialog> {
  String _status = '准备中...';
  bool _done = false;
  String? _error;
  bool _successHandled = false;

  @override
  void initState() {
    super.initState();
    widget.stream.listen(
      (msg) {
        if (mounted) {
          setState(() {
            _status = msg;
            if (msg == '转换完成' || msg == '导出完成') {
              _done = true;
              _handleSuccess();
            } else if (msg.startsWith('转换失败') || msg.startsWith('导出失败')) {
              _done = true;
              _error = msg;
            }
          });
        }
      },
      onDone: () {
        if (mounted) setState(() => _done = true);
      },
    );
  }

  Future<void> _handleSuccess() async {
    if (_successHandled || widget.onSuccess == null) return;
    _successHandled = true;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    Navigator.of(context).pop();
    await widget.onSuccess!.call();
  }

  void _copyPath() {
    Clipboard.setData(ClipboardData(text: widget.outputPath));
    if (mounted) {
      showAppNotice(context, '路径已复制', duration: const Duration(seconds: 1));
    }
  }

  Future<void> _openFolder() async {
    try {
      final path = widget.outputPath;
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', path]);
      } else if (Platform.isLinux) {
        final dir = File(path).parent.path;
        await Process.run('xdg-open', [dir]);
      }
    } catch (e) {
      if (mounted) {
        showAppNotice(context, '打开失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool success = _done && _error == null;

    return AlertDialog(
      backgroundColor: Colors.grey[850],
      title: const Text('转换 MP4', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_done)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.orange),
              ),
            ),
          Text(
            _status,
            style: TextStyle(
              color: _error != null ? Colors.red : (_done ? Colors.green : Colors.white70),
              fontSize: 14,
            ),
          ),
          if (success) ...[
            const SizedBox(height: 12),
            // 可选中+滚动的路径
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                widget.outputPath,
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
                maxLines: 3,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (success && widget.isDesktop) ...[
          TextButton.icon(
            onPressed: _openFolder,
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('定位 MP4'),
          ),
          TextButton.icon(
            onPressed: _copyPath,
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('复制路径'),
          ),
        ],
        if (_done) TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
      ],
    );
  }
}
