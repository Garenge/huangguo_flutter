import 'dart:io';

import '../models/download_task.dart';

/// MP4 按剧集中存放；HLS 源文件按剧和集数隔离。
class DownloadLayout {
  const DownloadLayout(this.root);

  final String root;
  static const ownerFile = '.drama_id';

  static String safeName(String value, {String fallback = '未命名'}) {
    final name = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return name.isEmpty || name == '.' || name == '..' ? fallback : name;
  }

  static String episodeNumber(String value) =>
      int.tryParse(value.trim())?.toString() ?? safeName(value);

  String sourceDirectory(DownloadTask task) =>
      sourceDirectoryFor(task.dramaId, task.ep);

  String sourceDirectoryFor(String dramaId, String ep) =>
      '$root/.sources/${safeName(dramaId)}/${episodeNumber(ep)}';

  String legacyDirectory(DownloadTask task) =>
      '$root/${safeName(task.dramaName)} (${safeName(task.dramaId)})/'
      '${safeName(task.episodeName)}';

  String albumDirectory(DownloadTask task) {
    for (final directory in ownedAlbums(task.dramaId)) {
      return directory;
    }
    final base = '$root/${safeName(task.dramaName)}';
    final owner = albumOwner(base);
    return owner == null || owner == task.dramaId
        ? base
        : '$base (${safeName(task.dramaId)})';
  }

  String mp4Path(DownloadTask task) =>
      '${albumDirectory(task)}/${safeName(task.dramaName)}-'
      '${episodeNumber(task.ep)}.mp4';

  String albumName(DownloadTask task) {
    if (root.isEmpty) return safeName(task.dramaName);
    return Directory(
      albumDirectory(task),
    ).uri.pathSegments.where((part) => part.isNotEmpty).last;
  }

  String? albumOwner(String path) {
    final marker = File('$path/$ownerFile');
    return marker.existsSync() ? marker.readAsStringSync().trim() : null;
  }

  Iterable<String> ownedAlbums(String dramaId) sync* {
    final directory = Directory(root);
    if (!directory.existsSync()) return;
    for (final album
        in directory.listSync(followLinks: false).whereType<Directory>()) {
      if (albumOwner(album.path) == dramaId) yield album.path;
    }
  }

  Future<void> prepareAlbum(DownloadTask task) => Future.sync(() {
    final directory = Directory(albumDirectory(task));
    // 同一 isolate 内一次完成归属登记，避免并发转换同名剧抢占目录。
    directory.createSync(recursive: true);
    final marker = File('${directory.path}/$ownerFile');
    if (!marker.existsSync()) {
      marker.writeAsStringSync(task.dramaId, flush: true);
    }
  });

  Iterable<String> mp4Candidates(String dramaId, String ep) sync* {
    final suffix = '-${episodeNumber(ep)}.mp4';
    for (final album in ownedAlbums(dramaId)) {
      for (final file in Directory(
        album,
      ).listSync(followLinks: false).whereType<File>()) {
        if (file.path.endsWith(suffix)) yield file.path;
      }
    }
  }
}
