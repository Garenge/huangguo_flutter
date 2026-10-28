import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/drama.dart';
import '../models/episode.dart';
import '../models/download_task.dart';
import 'huangguo_api.dart';
import 'stream_resolver.dart';
import 'app_log.dart';
import 'site_address.dart';

const _log = AppLog('DownloadService');
const _maxConcurrent = 2;
const _metaFileName = '.download_tasks.json';

/// 批量加入下载任务的结果。
class DownloadBatchResult {
  final int addedCount;
  final int skippedCount;

  const DownloadBatchResult({
    required this.addedCount,
    required this.skippedCount,
  });
}

/// HLS 加密密钥信息
class _HlsKeyInfo {
  final String method; // AES-128, NONE
  final String? uri; // 密钥 URL
  final String? iv; // IV（可选，十六进制字符串如 0x...）
  const _HlsKeyInfo({required this.method, this.uri, this.iv});
  bool get isEncrypted => method != 'NONE' && uri != null && uri!.isNotEmpty;
}

/// 描述 m3u8 中单个 TS 分片
class _TsSegmentInfo {
  final String url;
  final double duration; // 秒，来自 #EXTINF
  final _HlsKeyInfo? keyInfo; // 当前分片的加密密钥
  const _TsSegmentInfo({
    required this.url,
    required this.duration,
    this.keyInfo,
  });
}

/// 下载引擎：m3u8 解析 + TS 分片下载 + 下载密钥 + 生成本地 m3u8 播放列表
/// 播放时通过本地 HTTP 服务器以 HLS 方式播放，iOS/Android/macOS 均原生支持。
class DownloadService extends ChangeNotifier {
  final HuangguoApi _api;
  late final StreamResolver _resolver;
  final Dio _downloadDio;

  final List<DownloadTask> _tasks = [];
  final Queue<DownloadTask> _pendingQueue = Queue();
  int _activeCount = 0;

  String? _downloadRoot;
  bool _initialized = false;
  Future<void>? _initializing;

  DownloadService(this._api) : _downloadDio = Dio() {
    _resolver = StreamResolver(_api);
    _downloadDio.options.connectTimeout = const Duration(seconds: 15);
    _downloadDio.options.receiveTimeout = const Duration(seconds: 30);
  }

  @override
  void dispose() {
    _downloadDio.close(force: true);
    super.dispose();
  }

  String get downloadRoot => _downloadRoot ?? '';
  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  List<DownloadTask> get downloadingTasks =>
      _tasks.where((t) => t.status == DownloadStatus.downloading).toList();
  List<DownloadTask> get completedTasks =>
      _tasks.where((t) => t.status == DownloadStatus.completed).toList();
  List<DownloadTask> get pendingTasks => _tasks
      .where(
        (t) =>
            t.status == DownloadStatus.pending ||
            t.status == DownloadStatus.paused,
      )
      .toList();

  DownloadTask? taskForEpisode(String dramaId, String ep) {
    for (final task in _tasks) {
      if (task.dramaId == dramaId && task.ep == ep) return task;
    }
    return null;
  }

  bool isEpisodeDownloaded(String dramaId, String ep) {
    final task = taskForEpisode(dramaId, ep);
    return task?.status == DownloadStatus.completed &&
        task != null &&
        _hasEpisodeResource(task);
  }

  bool isEpisodeDownloadedForTask(DownloadTask task) {
    return task.status == DownloadStatus.completed && _hasEpisodeResource(task);
  }

  bool _hasEpisodeResource(DownloadTask task) {
    if (_fileExists(task.mp4Path) || _fileExists(task.filePath)) return true;

    final episodeDirectory = Directory(episodeDirectoryFor(task));
    if (!episodeDirectory.existsSync()) return false;

    return episodeDirectory
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .any((file) {
          final fileName = file.path.toLowerCase();
          return fileName.endsWith('.mp4') ||
              fileName.endsWith('.m3u8') ||
              fileName.endsWith('.ts');
        });
  }

  bool _fileExists(String? path) {
    return path != null && path.isNotEmpty && File(path).existsSync();
  }

  String episodeDirectoryFor(DownloadTask task) {
    if (task.filePath != null && task.filePath!.isNotEmpty) {
      return File(task.filePath!).parent.path;
    }
    return _episodeDir(task.dramaName, task.dramaId, task.episodeName);
  }

  Future<void> init() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    if (_initialized) return;
    final appDir = await getApplicationDocumentsDirectory();
    _downloadRoot = '${appDir.path}/huangguo_downloads';
    await Directory(_downloadRoot!).create(recursive: true);
    await _loadFromDisk();
    _initialized = true;
    _log.i('init: downloadRoot=$_downloadRoot, tasks=${_tasks.length}');
    _resumePending();
  }

  Future<void> _ensureInit() async {
    if (!_initialized) await init();
  }

  // ---------- 目录管理 ----------

  String _dramaDir(String dramaName, String dramaId) {
    final safeName = dramaName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return '$_downloadRoot/$safeName ($dramaId)';
  }

  String _episodeDir(String dramaName, String dramaId, String episodeName) {
    final safeEpName = episodeName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    return '${_dramaDir(dramaName, dramaId)}/$safeEpName';
  }

  String _episodePath(String dramaName, String dramaId, String episodeName) {
    return '${_episodeDir(dramaName, dramaId, episodeName)}/playlist.m3u8';
  }

  String _tmpDir(String taskId) => '$_downloadRoot/.tmp/$taskId';

  // ---------- 任务管理 ----------

  Future<DownloadTask?> addTask(Drama drama, Episode episode) async {
    await _ensureInit();

    final exists = _taskExists(drama.id, episode.ep);
    if (exists) {
      _log.w('addTask: already exists, dramaId=${drama.id}, ep=${episode.ep}');
      return null;
    }

    final taskId =
        '${drama.id}_${episode.ep}_${DateTime.now().millisecondsSinceEpoch}';
    final task = DownloadTask(
      id: taskId,
      dramaId: drama.id,
      dramaName: drama.name,
      dramaPic: drama.pic,
      episodeName: episode.name,
      episodeUrl: SiteAddress.relative(episode.url, episode: true),
      ep: episode.ep,
    );

    _tasks.insert(0, task);
    _log.i('addTask: id=$taskId, drama=${drama.name}, ep=${episode.name}');
    notifyListeners();
    await _persist();

    _pendingQueue.add(task);
    _processQueue();

    return task;
  }

  Future<DownloadBatchResult> addTasks(
    Drama drama,
    List<Episode> episodes,
  ) async {
    await _ensureInit();

    final newTasks = <DownloadTask>[];
    final seenEpisodes = <String>{};
    var skippedCount = 0;
    for (final episode in episodes) {
      if (!_isNewEpisode(drama.id, episode.ep, seenEpisodes)) {
        skippedCount++;
        continue;
      }
      seenEpisodes.add(episode.ep);

      final taskId =
          '${drama.id}_${episode.ep}_${DateTime.now().microsecondsSinceEpoch}';
      newTasks.add(
        DownloadTask(
          id: taskId,
          dramaId: drama.id,
          dramaName: drama.name,
          dramaPic: drama.pic,
          episodeName: episode.name,
          episodeUrl: SiteAddress.relative(episode.url, episode: true),
          ep: episode.ep,
        ),
      );
    }

    if (newTasks.isEmpty) {
      _log.i(
        'addTasks: no new tasks, dramaId=${drama.id}, skipped=$skippedCount',
      );
      return DownloadBatchResult(addedCount: 0, skippedCount: skippedCount);
    }

    _tasks.insertAll(0, newTasks);
    _pendingQueue.addAll(newTasks);
    _log.i(
      'addTasks: added=${newTasks.length}, skipped=$skippedCount, '
      'dramaId=${drama.id}',
    );
    notifyListeners();
    await _persist();
    _processQueue();

    return DownloadBatchResult(
      addedCount: newTasks.length,
      skippedCount: skippedCount,
    );
  }

  Future<void> updateMp4Path(String taskId, String path) async {
    final task = _findTask(taskId);
    if (task == null) return;

    task.mp4Path = path;
    _log.i('updateMp4Path: taskId=$taskId, path=$path');
    notifyListeners();
    await _persist();
  }

  /// 删除指定剧集的源 m3u8、TS 分片和密钥文件，保留 MP4。
  Future<bool> deleteSourceFiles(String taskId) async {
    final task = _findTask(taskId);
    if (task == null) return false;

    final episodeDir = Directory(episodeDirectoryFor(task));
    if (!await episodeDir.exists()) {
      task.filePath = null;
      await _persist();
      return true;
    }

    var deletedCount = 0;
    await for (final entity in episodeDir.list(recursive: true)) {
      if (entity is! File || !_isSourceFile(entity.path)) continue;
      await entity.delete();
      deletedCount++;
    }

    task.filePath = null;
    _log.i(
      'deleteSourceFiles: taskId=$taskId, deleted=$deletedCount, '
      'directory=${episodeDir.path}',
    );
    notifyListeners();
    await _persist();
    return true;
  }

  bool _isSourceFile(String path) {
    final fileName = path.split(Platform.pathSeparator).last.toLowerCase();
    return fileName == 'playlist.m3u8' ||
        fileName.endsWith('.ts') ||
        (fileName.startsWith('key_') && fileName.endsWith('.bin'));
  }

  Future<void> pauseTask(String taskId) async {
    final task = _findTask(taskId);
    if (task == null) return;
    if (task.status == DownloadStatus.downloading) {
      task.status = DownloadStatus.paused;
      _activeCount--;
      _log.i('pauseTask: $taskId');
      notifyListeners();
      await _persist();
      _processQueue();
    }
  }

  Future<void> resumeTask(String taskId) async {
    final task = _findTask(taskId);
    if (task == null) return;
    if (task.status == DownloadStatus.paused ||
        task.status == DownloadStatus.failed) {
      task.status = DownloadStatus.pending;
      task.errorMessage = null;
      _log.i('resumeTask: $taskId');
      notifyListeners();
      await _persist();
      _pendingQueue.add(task);
      _processQueue();
    }
  }

  Future<void> deleteTask(String taskId) async {
    final task = _findTask(taskId);
    if (task == null) return;

    if (task.status == DownloadStatus.downloading) {
      _activeCount--;
    }

    final tmpDir = Directory(_tmpDir(taskId));
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }

    if (task.filePath != null) {
      final epDir = Directory(
        _episodeDir(task.dramaName, task.dramaId, task.episodeName),
      );
      if (await epDir.exists()) {
        await epDir.delete(recursive: true);
      }
    }

    _tasks.remove(task);
    _pendingQueue.remove(task);
    _log.i('deleteTask: $taskId');
    notifyListeners();
    await _persist();
    _processQueue();
    _cleanupEmptyDirs();
  }

  Future<void> deleteCompletedFile(String taskId) async {
    final task = _findTask(taskId);
    if (task == null || task.status != DownloadStatus.completed) return;

    final epDir = Directory(
      _episodeDir(task.dramaName, task.dramaId, task.episodeName),
    );
    if (await epDir.exists()) {
      await epDir.delete(recursive: true);
    }

    _tasks.remove(task);
    _log.i('deleteCompletedFile: $taskId');
    notifyListeners();
    await _persist();
    _cleanupEmptyDirs();
  }

  DownloadTask? _findTask(String taskId) {
    try {
      return _tasks.firstWhere((t) => t.id == taskId);
    } catch (_) {
      return null;
    }
  }

  bool _taskExists(String dramaId, String ep) {
    return _tasks.any(
      (t) =>
          t.dramaId == dramaId &&
          t.ep == ep &&
          (t.status == DownloadStatus.pending ||
              t.status == DownloadStatus.downloading ||
              t.status == DownloadStatus.completed),
    );
  }

  bool _isNewEpisode(String dramaId, String ep, Set<String> seenEpisodes) {
    return !seenEpisodes.contains(ep) && !_taskExists(dramaId, ep);
  }

  // ---------- 队列处理 ----------

  void _processQueue() {
    while (_activeCount < _maxConcurrent && _pendingQueue.isNotEmpty) {
      final task = _pendingQueue.removeFirst();
      if (task.status == DownloadStatus.pending) {
        _activeCount++;
        _downloadTask(task);
      }
    }
  }

  void _resumePending() {
    for (final task in _tasks) {
      if (task.status == DownloadStatus.pending) {
        _pendingQueue.add(task);
      } else if (task.status == DownloadStatus.downloading) {
        task.status = DownloadStatus.pending;
        task.progress = 0.0;
        _pendingQueue.add(task);
      }
    }
    _processQueue();
  }

  // ---------- 核心下载逻辑 ----------

  Future<void> _downloadTask(DownloadTask task) async {
    _log.i('_downloadTask: start id=${task.id}, ep=${task.episodeName}');

    try {
      task.status = DownloadStatus.downloading;
      notifyListeners();

      // 1. 解析 m3u8 地址
      String m3u8Url;
      {
        _log.d('_downloadTask: resolving m3u8, epUrl=${task.episodeUrl}');
        m3u8Url = await _resolver.resolveStream(
          Episode(name: task.episodeName, url: task.episodeUrl, ep: task.ep),
        );
        task.m3u8Url = m3u8Url;
      }
      _log.d('_downloadTask: m3u8Url=$m3u8Url');

      // 2. 下载并解析 m3u8 播放列表，获取 TS 分片及加密信息
      final segments = await _resolveM3u8(m3u8Url);
      if (segments.isEmpty) {
        throw Exception('m3u8 解析失败：未找到 TS 分片');
      }
      _log.i('_downloadTask: ${segments.length} TS segments');

      // 3. 准备目录
      final tmpDir = Directory(_tmpDir(task.id));
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
      await tmpDir.create(recursive: true);

      final epDir = Directory(
        _episodeDir(task.dramaName, task.dramaId, task.episodeName),
      );
      if (await epDir.exists()) {
        await epDir.delete(recursive: true);
      }
      await epDir.create(recursive: true);

      // 4. 下载加密密钥（如有）
      final downloadedKeys = <String, String>{}; // originalUri -> localFilename
      for (final seg in segments) {
        if (seg.keyInfo != null && seg.keyInfo!.isEncrypted) {
          final uri = seg.keyInfo!.uri!;
          if (!downloadedKeys.containsKey(uri)) {
            final keyName = 'key_${downloadedKeys.length}.bin';
            final keyPath = '${epDir.path}/$keyName';
            _log.i('_downloadTask: downloading key $uri -> $keyName');
            await _downloadKeyFile(uri, keyPath);
            downloadedKeys[uri] = keyName;
          }
        }
      }
      if (downloadedKeys.isNotEmpty) {
        _log.i('_downloadTask: downloaded ${downloadedKeys.length} key(s)');
      }

      // 5. 下载 TS 分片到临时目录
      final tsFiles = <String>[];
      for (int i = 0; i < segments.length; i++) {
        if (task.status == DownloadStatus.paused) {
          _log.i('_downloadTask: paused at segment $i/${segments.length}');
          await _persist();
          return;
        }

        final tsName = '${i.toString().padLeft(5, '0')}.ts';
        final tsPath = '${tmpDir.path}/$tsName';
        await _downloadSegment(
          segments[i].url,
          tsPath,
          task,
          i,
          segments.length,
        );
        tsFiles.add(tsPath);
      }

      // 6. 移动 TS 分片到剧集目录
      for (int i = 0; i < tsFiles.length; i++) {
        final tsName = '${i.toString().padLeft(5, '0')}.ts';
        final destPath = '${epDir.path}/$tsName';
        await File(tsFiles[i]).rename(destPath);
      }
      _log.i('_downloadTask: moved ${tsFiles.length} TS segments to $epDir');

      // 7. 生成本地 m3u8 播放列表（含密钥引用）
      final m3u8Path = _episodePath(
        task.dramaName,
        task.dramaId,
        task.episodeName,
      );
      final m3u8Content = _buildLocalM3u8(segments, downloadedKeys);
      await File(m3u8Path).writeAsString(m3u8Content);
      _log.i('_downloadTask: m3u8 written to $m3u8Path');

      // 8. 清理临时目录
      await tmpDir.delete(recursive: true);

      // 9. 完成
      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      task.filePath = m3u8Path;
      task.downloadedBytes = task.totalBytes;
      _activeCount--;
      _log.i('_downloadTask: completed id=${task.id}, m3u8=$m3u8Path');
      notifyListeners();
      await _persist();
      _processQueue();
    } catch (e, stack) {
      _log.e('_downloadTask: failed id=${task.id}', e, stack);
      task.status = DownloadStatus.failed;
      task.errorMessage = e.toString();
      _activeCount--;
      notifyListeners();
      await _persist();
      _processQueue();

      try {
        final tmpDir = Directory(_tmpDir(task.id));
        if (await tmpDir.exists()) {
          await tmpDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// 下载密钥文件（二进制，通常 16 字节）
  Future<void> _downloadKeyFile(String url, String savePath) async {
    final resp = await _downloadDio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = resp.data as List<int>;
    await File(savePath).writeAsBytes(bytes);
    _log.d('_downloadKeyFile: $url -> $savePath (${bytes.length} bytes)');
  }

  /// 解析 m3u8：支持主播放列表和媒体播放列表
  Future<List<_TsSegmentInfo>> _resolveM3u8(String m3u8Url) async {
    final resp = await _downloadDio.get(
      m3u8Url,
      options: Options(responseType: ResponseType.plain),
    );
    final content = resp.data as String;

    if (content.contains('#EXT-X-STREAM-INF')) {
      _log.d('_resolveM3u8: master playlist detected');
      final variantMatch = RegExp(
        r'#EXT-X-STREAM-INF[^\n]*\n([^\n#]+)',
      ).firstMatch(content);
      if (variantMatch != null) {
        final variantUrl = _resolveUrl(m3u8Url, variantMatch.group(1)!.trim());
        _log.d('_resolveM3u8: variant=$variantUrl');
        final subResp = await _downloadDio.get(
          variantUrl,
          options: Options(responseType: ResponseType.plain),
        );
        return _parseMediaPlaylist(subResp.data as String, variantUrl);
      }
    }

    return _parseMediaPlaylist(content, m3u8Url);
  }

  /// 解析媒体播放列表，提取 TS 分片 URL、时长、加密信息
  List<_TsSegmentInfo> _parseMediaPlaylist(String content, String baseUrl) {
    final segments = <_TsSegmentInfo>[];
    final lines = content.split('\n');
    double currentDuration = 0;
    _HlsKeyInfo? currentKey;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('#EXT-X-KEY:')) {
        currentKey = _parseKeyTag(trimmed);
        _log.d(
          '_parseMediaPlaylist: key method=${currentKey?.method}, uri=${currentKey?.uri}',
        );
      } else if (trimmed.startsWith('#EXTINF:')) {
        // 格式: #EXTINF:<duration>,<title>
        final durationStr = trimmed.substring(8).split(',').first;
        currentDuration = double.tryParse(durationStr) ?? 0;
      } else if (!trimmed.startsWith('#')) {
        final url = _resolveUrl(baseUrl, trimmed);
        segments.add(
          _TsSegmentInfo(
            url: url,
            duration: currentDuration,
            keyInfo: currentKey,
          ),
        );
        currentDuration = 0;
      }
    }
    return segments;
  }

  /// 解析 #EXT-X-KEY 标签
  _HlsKeyInfo? _parseKeyTag(String line) {
    final method = _extractAttribute(line, 'METHOD');
    if (method == null || method == 'NONE') {
      return _HlsKeyInfo(method: method ?? 'NONE');
    }
    final uri = _extractAttribute(line, 'URI');
    final iv = _extractAttribute(line, 'IV');
    return _HlsKeyInfo(method: method, uri: uri, iv: iv);
  }

  /// 从属性字符串中提取值，支持 METHOD=AES-128 和 URI="https://..." 格式
  String? _extractAttribute(String line, String name) {
    // 匹配 NAME="value" 或 NAME=value
    final pattern = RegExp('$name="([^"]*)"');
    final match = pattern.firstMatch(line);
    if (match != null) return match.group(1);

    // 匹配 NAME=value (无引号)
    final unquoted = RegExp('$name=([^,]+)');
    final m2 = unquoted.firstMatch(line);
    if (m2 != null) return m2.group(1)?.trim();

    return null;
  }

  /// 生成本地 m3u8 播放列表，引用本地 TS 文件和密钥
  String _buildLocalM3u8(
    List<_TsSegmentInfo> segments,
    Map<String, String> downloadedKeys,
  ) {
    final buf = StringBuffer();
    buf.writeln('#EXTM3U');
    buf.writeln('#EXT-X-VERSION:3');

    // 计算目标时长
    double maxDuration = 0;
    for (final s in segments) {
      if (s.duration > maxDuration) maxDuration = s.duration;
    }
    if (maxDuration <= 0) maxDuration = 10;
    buf.writeln('#EXT-X-TARGETDURATION:${maxDuration.ceil()}');
    buf.writeln('#EXT-X-MEDIA-SEQUENCE:0');

    // 跟踪当前密钥，避免重复输出
    String? lastKeyUri;

    for (int i = 0; i < segments.length; i++) {
      final s = segments[i];
      final tsName = '${i.toString().padLeft(5, '0')}.ts';

      // 输出 #EXT-X-KEY（仅在密钥变化时）
      if (s.keyInfo != null && s.keyInfo!.isEncrypted) {
        final keyUri = s.keyInfo!.uri!;
        if (keyUri != lastKeyUri) {
          final localKeyName = downloadedKeys[keyUri] ?? 'key_0.bin';
          buf.write(
            '#EXT-X-KEY:METHOD=${s.keyInfo!.method},URI="$localKeyName"',
          );
          if (s.keyInfo!.iv != null) {
            buf.write(',IV=${s.keyInfo!.iv}');
          }
          buf.writeln();
          lastKeyUri = keyUri;
        }
      } else if (s.keyInfo != null && !s.keyInfo!.isEncrypted) {
        if (lastKeyUri != null) {
          buf.writeln('#EXT-X-KEY:METHOD=NONE');
          lastKeyUri = null;
        }
      }

      buf.writeln('#EXTINF:${s.duration.toStringAsFixed(3)},');
      buf.writeln(tsName);
    }

    buf.writeln('#EXT-X-ENDLIST');
    return buf.toString();
  }

  String _resolveUrl(String baseUrl, String segmentUrl) {
    if (segmentUrl.startsWith('http://') || segmentUrl.startsWith('https://')) {
      return segmentUrl;
    }
    final baseUri = Uri.parse(baseUrl);
    if (segmentUrl.startsWith('/')) {
      return '${baseUri.origin}$segmentUrl';
    }
    final basePath = baseUri.pathSegments.isNotEmpty
        ? baseUri.pathSegments
              .sublist(0, baseUri.pathSegments.length - 1)
              .join('/')
        : '';
    return '${baseUri.origin}/$basePath/$segmentUrl';
  }

  Future<void> _downloadSegment(
    String url,
    String savePath,
    DownloadTask task,
    int index,
    int total,
  ) async {
    int retries = 3;
    while (retries > 0) {
      try {
        await _downloadDio.download(url, savePath);
        final file = File(savePath);
        if (await file.exists()) {
          task.downloadedBytes += await file.length();
        }
        task.progress = (index + 1) / total;
        notifyListeners();
        return;
      } catch (e) {
        retries--;
        if (retries == 0) rethrow;
        _log.w('_downloadSegment: retry ${3 - retries}/3 for segment $index');
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _cleanupEmptyDirs() async {
    if (_downloadRoot == null) return;
    final root = Directory(_downloadRoot!);
    if (!await root.exists()) return;

    await for (final entity in root.list()) {
      if (entity is Directory) {
        final isEmpty = await entity.list().isEmpty;
        if (isEmpty) {
          await entity.delete();
        }
      }
    }
  }

  // ---------- 持久化 ----------

  Future<void> _persist() async {
    if (_downloadRoot == null) return;
    final metaFile = File('$_downloadRoot/$_metaFileName');
    final json = _tasks
        .map((t) => t.toJson(downloadRoot: _downloadRoot!))
        .toList();
    await metaFile.writeAsString(jsonEncode(json));
  }

  Future<void> _loadFromDisk() async {
    if (_downloadRoot == null) return;
    final metaFile = File('$_downloadRoot/$_metaFileName');
    if (!await metaFile.exists()) return;

    try {
      final content = await metaFile.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      _tasks.clear();
      for (final item in list) {
        final task = DownloadTask.fromJson(
          item as Map<String, dynamic>,
          downloadRoot: _downloadRoot!,
        );
        if (task.status == DownloadStatus.completed && task.filePath != null) {
          if (!await File(task.filePath!).exists()) {
            task.status = DownloadStatus.failed;
            task.errorMessage = '文件已丢失';
          }
        }
        if (task.mp4Path != null && !await File(task.mp4Path!).exists()) {
          task.mp4Path = null;
        }

        _tasks.add(task);
      }
      _log.i('_loadFromDisk: loaded ${_tasks.length} tasks');
    } catch (e, stack) {
      _log.e('_loadFromDisk: failed', e, stack);
    }
  }
}
