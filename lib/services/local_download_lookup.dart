import 'dart:io';

import '../models/download_task.dart';
import '../models/episode.dart';
import 'download_service.dart';
import 'site_address.dart';

/// 使用剧集身份定位任务和目录，避免仅凭剧名误播同名资源。
class LocalDownloadLookup {
  LocalDownloadLookup(this.downloads, this.episode, {String? dramaId})
    : dramaId = dramaId?.trim().isNotEmpty == true
          ? dramaId!.trim()
          : _idFromUrl(episode.url);

  final DownloadService downloads;
  final Episode episode;
  final String? dramaId;

  List<DownloadTask> get tasks => downloads.tasks.where(_matches).toList();

  bool _matches(DownloadTask task) {
    if (_episodeNumber(task.ep) != _episodeNumber(episode.ep)) return false;
    if (dramaId != null) return task.dramaId == dramaId;
    final url = _canonicalUrl(episode.url);
    return url.isNotEmpty && _canonicalUrl(task.episodeUrl) == url;
  }

  Iterable<String> get directories sync* {
    final root = downloads.downloadRoot;
    if (dramaId == null || root.isEmpty || !Directory(root).existsSync()) {
      return;
    }
    for (final album in _subdirectories(root)) {
      if (!_directoryName(album).endsWith(' ($dramaId)')) continue;
      yield* _episodeDirectories(album);
    }
  }

  Iterable<String> _episodeDirectories(Directory album) sync* {
    for (final folder in _subdirectories(album.path)) {
      final name = _directoryName(folder);
      if (name == _safeName(episode.name) || _matchesEpisodeFolder(name)) {
        yield folder.path;
      }
    }
  }

  static Iterable<Directory> _subdirectories(String root) =>
      Directory(root).listSync(followLinks: false).whereType<Directory>();

  static String _directoryName(Directory directory) =>
      directory.uri.pathSegments.where((part) => part.isNotEmpty).last;

  bool _matchesEpisodeFolder(String name) {
    final match = RegExp(r'^第\s*(\d+)\s*集$').firstMatch(name);
    return match != null &&
        _episodeNumber(match.group(1)!) == _episodeNumber(episode.ep);
  }

  static String _episodeNumber(String value) =>
      int.tryParse(value.trim())?.toString() ?? value.trim();

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  static String _canonicalUrl(String url) {
    final uri = Uri.tryParse(SiteAddress.relative(url, episode: true));
    if (uri == null) return '';
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return '${uri.hasAuthority ? '${uri.scheme}://${uri.authority}' : ''}'
        '$path${uri.hasQuery ? '?${uri.query}' : ''}';
  }

  static String? _idFromUrl(String url) {
    final uri = Uri.tryParse(SiteAddress.relative(url, episode: true));
    if (uri == null || uri.hasAuthority) return null;
    return RegExp(
      r'^/(?:video|detail|play)/(\d+)(?:/|$)',
    ).firstMatch(uri.path)?.group(1);
  }
}
