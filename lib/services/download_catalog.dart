import 'package:lpinyin/lpinyin.dart';

import '../models/download_task.dart';

enum DownloadSortMode {
  recent('最近下载'),
  name('剧名拼音'),
  count('剧集数量');

  final String label;

  const DownloadSortMode(this.label);
}

class DownloadCatalog {
  const DownloadCatalog._();

  static List<DownloadTask> filter(Iterable<DownloadTask> tasks, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return tasks.toList();

    return tasks.where((task) {
      final searchableText = [
        task.dramaName,
        task.episodeName,
        task.ep,
        _pinyin(task.dramaName),
        _shortPinyin(task.dramaName),
      ].join(' ').toLowerCase();
      return searchableText.contains(normalizedQuery);
    }).toList();
  }

  static Map<String, List<DownloadTask>> groupAndSort(
    Iterable<DownloadTask> tasks,
    DownloadSortMode mode,
  ) {
    final grouped = <String, List<DownloadTask>>{};
    for (final task in tasks) {
      final key = '${task.dramaName} (${task.dramaId})';
      grouped.putIfAbsent(key, () => []).add(task);
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) => _compareGroups(a, b, mode));
    return Map.fromEntries(entries);
  }

  static int _compareGroups(
    MapEntry<String, List<DownloadTask>> a,
    MapEntry<String, List<DownloadTask>> b,
    DownloadSortMode mode,
  ) {
    final aTask = a.value.first;
    final bTask = b.value.first;
    final nameComparison = _pinyin(
      aTask.dramaName,
    ).compareTo(_pinyin(bTask.dramaName));

    switch (mode) {
      case DownloadSortMode.recent:
        final dateComparison = _latest(a.value).compareTo(_latest(b.value));
        return dateComparison == 0 ? nameComparison : -dateComparison;
      case DownloadSortMode.name:
        return nameComparison == 0
            ? aTask.dramaId.compareTo(bTask.dramaId)
            : nameComparison;
      case DownloadSortMode.count:
        final countComparison = b.value.length.compareTo(a.value.length);
        return countComparison == 0 ? nameComparison : countComparison;
    }
  }

  static DateTime _latest(List<DownloadTask> tasks) {
    return tasks
        .map((task) => task.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  static String _pinyin(String value) {
    try {
      return PinyinHelper.getPinyin(value, separator: '').toLowerCase();
    } catch (_) {
      return value.toLowerCase();
    }
  }

  static String _shortPinyin(String value) {
    try {
      return PinyinHelper.getShortPinyin(value).toLowerCase();
    } catch (_) {
      return value.toLowerCase();
    }
  }
}
