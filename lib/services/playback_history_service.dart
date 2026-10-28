import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/playback_history.dart';
import 'app_log.dart';

const _log = AppLog('PlaybackHistoryService');

class PlaybackHistoryService {
  static const _fileName = 'playback_history.json';
  static const int _maxEntries = 50;

  List<PlaybackHistoryEntry> _entries = [];
  bool _loaded = false;

  Future<String> get _filePath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_fileName';
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await _load();
  }

  Future<void> _load() async {
    try {
      final path = await _filePath;
      final file = File(path);
      if (!await file.exists()) {
        _entries = [];
        _loaded = true;
        _log.i('_load: no history file, empty');
        return;
      }
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      _entries = list
          .map((e) => PlaybackHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      _loaded = true;
      _log.i('_load: loaded ${_entries.length} entries');
    } catch (e, stack) {
      _log.e('_load: failed', e, stack);
      _entries = [];
      _loaded = true;
    }
  }

  Future<void> _save() async {
    try {
      final path = await _filePath;
      final file = File(path);
      final list = _entries.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(list));
      _log.d('_save: saved ${_entries.length} entries');
    } catch (e, stack) {
      _log.e('_save: failed', e, stack);
    }
  }

  /// 保存或更新播放记录（同剧同集覆盖）
  Future<void> saveEntry({
    required String dramaName,
    required String episodeName,
    required String ep,
    required String url,
    required int positionMs,
    String? dramaId,
  }) async {
    await _ensureLoaded();
    final dedupKey = '$dramaName||$ep';
    final existingIndex = _entries.indexWhere((e) => e.dedupKey == dedupKey);

    final entry = PlaybackHistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dramaName: dramaName,
      episodeName: episodeName,
      ep: ep,
      url: url,
      positionMs: positionMs,
      savedAt: DateTime.now(),
      dramaId: dramaId,
    );

    if (existingIndex >= 0) {
      _entries[existingIndex] = entry;
      _log.d('saveEntry: updated existing $dedupKey');
    } else {
      _entries.insert(0, entry);
      _log.d('saveEntry: inserted new $dedupKey');
    }

    // 超出上限时移除最旧的
    while (_entries.length > _maxEntries) {
      _entries.removeLast();
    }

    await _save();
  }

  /// 获取所有历史记录（最新的在前）
  Future<List<PlaybackHistoryEntry>> getEntries() async {
    await _ensureLoaded();
    return List.unmodifiable(_entries);
  }

  /// 删除单条记录
  Future<void> deleteEntry(String id) async {
    await _ensureLoaded();
    _entries.removeWhere((e) => e.id == id);
    await _save();
    _log.d('deleteEntry: removed $id');
  }

  /// 清空所有记录
  Future<void> clearAll() async {
    await _ensureLoaded();
    _entries.clear();
    await _save();
    _log.i('clearAll: all entries removed');
  }
}
