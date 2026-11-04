import 'package:flutter/foundation.dart';

import '../models/drama.dart';
import '../models/playback_history.dart';
import 'app_log.dart';
import 'library_storage.dart';

class LibraryService extends ChangeNotifier {
  LibraryService({LibraryStorage? storage})
    : _storage = storage ?? LibraryStorage();

  final LibraryStorage _storage;
  final Map<String, Drama> _favorites = {};
  final Map<String, Set<String>> _watched = {};
  Future<void>? _loading;
  bool _disposed = false;
  bool ready = false;
  String? errorMessage;

  List<Drama> get favorites => _favorites.values.toList().reversed.toList();

  String _key(String? id, String name) =>
      id != null && id.isNotEmpty ? 'id:$id' : 'name:$name';

  bool isFavorite(String id) => _favorites.containsKey(id);

  bool hasWatched(String? id, String name, {String? ep}) {
    final episodes = {...?_watched[_key(id, name)], ...?_watched['name:$name']};
    return ep == null ? episodes.isNotEmpty : episodes.contains(ep.trim());
  }

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final data = await _storage.read();
      _readFavorites(data['favorites'] as List? ?? []);
      _readWatched(data['watched'] as Map? ?? {});
      ready = true;
    } catch (error, stack) {
      errorMessage = '收藏与观看状态读取失败，请重启后重试';
      const AppLog('library_service.dart').e('_load: 读取媒体库失败', error, stack);
    }
    _notify();
  }

  void _readFavorites(List records) {
    for (final record in records) {
      final item = Map<String, dynamic>.from(record as Map);
      final drama = Drama(
        id: item['id'] as String,
        name: item['name'] as String,
        pic: item['pic'] as String,
        remark: item['remark'] as String,
      );
      _favorites[drama.id] = drama;
    }
  }

  void _readWatched(Map records) {
    for (final entry in records.entries) {
      _watched[entry.key as String] = (entry.value as List)
          .cast<String>()
          .toSet();
    }
  }

  Future<bool> toggleFavorite(Drama drama) async {
    await load();
    if (!ready || _disposed) return false;
    if (_favorites.containsKey(drama.id)) {
      _favorites.remove(drama.id);
    } else {
      _favorites[drama.id] = drama;
    }
    return _save();
  }

  Future<bool> markWatched(String? id, String name, String ep) async {
    await load();
    if (!ready || _disposed || ep.trim().isEmpty) return false;
    final episodes = _watched.putIfAbsent(_key(id, name), () => {});
    if (!episodes.add(ep.trim())) return true;
    return _save();
  }

  Future<void> importHistory(List<PlaybackHistoryEntry> entries) async {
    await load();
    if (!ready || _disposed) return;
    var changed = false;
    for (final entry in entries.where((entry) => entry.positionMs > 0)) {
      final episodes = _watched.putIfAbsent(
        _key(entry.dramaId, entry.dramaName),
        () => {},
      );
      changed = episodes.add(entry.ep.trim()) || changed;
    }
    if (changed) await _save();
  }

  Map<String, dynamic> _toJson() => {
    'favorites': _favorites.values
        .map(
          (drama) => {
            'id': drama.id,
            'name': drama.name,
            'pic': drama.pic,
            'remark': drama.remark,
          },
        )
        .toList(),
    'watched': _watched.map(
      (key, episodes) => MapEntry(key, episodes.toList()),
    ),
  };

  Future<bool> _save() async {
    final data = _toJson();
    _notify();
    try {
      await _storage.write(data);
      errorMessage = null;
      _notify();
      return true;
    } catch (error, stack) {
      errorMessage = '媒体库保存失败，当前变更可能在重启后丢失';
      const AppLog('library_service.dart').e('_save: 保存媒体库失败', error, stack);
      _notify();
      return false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
