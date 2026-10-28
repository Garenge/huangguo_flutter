import 'dart:convert';
import 'dart:io';

import '../models/download_task.dart';
import '../models/playback_history.dart';
import 'download_paths.dart';
import 'migration_storage.dart';
import 'site_address.dart';

/// 不信任迁移的内存结果，独立从磁盘检查格式、内容及本地资源引用。
class DataMigrationValidator {
  final MigrationFiles files;
  const DataMigrationValidator(this.files);

  Future<Map<String, Object>> verify() async {
    final errors = <String>[];
    final warnings = <String>[];
    var count = 0;
    for (final file in files.records) {
      try {
        final records = await readMigrationRecords(file);
        count += records.length;
        for (final record in records) {
          await _verifyRecord(file, record, errors, warnings);
        }
        await _verifyBackup(file, records, errors);
      } catch (error) {
        errors.add('${file.path}: $error');
      }
    }
    return {
      'verified': errors.isEmpty,
      'checkedRecords': count,
      'errors': errors,
      'warnings': warnings,
      'checkedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _verifyRecord(
    File file,
    Map<String, dynamic> record,
    List<String> errors,
    List<String> warnings,
  ) async {
    final download = file.path == files.downloads.path;
    final field = download ? 'episodeUrl' : 'url';
    if (download) {
      DownloadTask.fromJson(record, downloadRoot: files.root);
    } else {
      PlaybackHistoryEntry.fromJson(record);
    }
    final url = record[field] as String;
    if (SiteAddress.relative(url, episode: true) != url) {
      errors.add('${record['id']}: $field 仍包含站点域名');
    }
    if (!download) return;
    if (record['m3u8Url'] != null) {
      errors.add('${record['id']}: 仍保存临时片源地址');
    }
    for (final key in ['filePath', 'mp4Path']) {
      final path = record[key] as String?;
      if (DownloadPaths.relative(path, files.root) != path) {
        errors.add('${record['id']}: $key 不是相对路径');
      }
      final resolved = DownloadPaths.resolve(path, files.root);
      if (resolved == null || resolved.isEmpty) continue;
      if (!await File(resolved).exists()) {
        warnings.add('${record['id']}: 本地文件不存在 $path');
      } else if (resolved.endsWith('.m3u8')) {
        await _verifyPlaylist(File(resolved), warnings);
      }
    }
  }

  Future<void> _verifyPlaylist(File playlist, List<String> warnings) async {
    for (final line in await playlist.readAsLines()) {
      final text = line.trim();
      final references = text.startsWith('#')
          ? RegExp(r'URI="([^"]+)"').allMatches(text).map((m) => m[1]!)
          : [if (text.isNotEmpty) text];
      for (final reference in references) {
        final uri = Uri.parse(reference);
        if (uri.hasScheme || uri.hasAuthority || reference.startsWith('/')) {
          warnings.add('${playlist.path}: 播放列表含非本地相对引用 $reference');
        } else if (!await File('${playlist.parent.path}/$reference').exists()) {
          warnings.add('${playlist.path}: 缺少分片或密钥 $reference');
        }
      }
    }
  }

  Future<void> _verifyBackup(
    File file,
    List<Map<String, dynamic>> records,
    List<String> errors,
  ) async {
    final backup = File('${file.path}.relative_v1.bak');
    if (!await backup.exists()) return;
    // 首次迁移逐条比对；后续启动的数据可合法增加、删除或更新。
    if (await files.marker.exists()) return;
    final before = await readMigrationRecords(backup);
    if (before.length != records.length) {
      errors.add('${file.path}: 迁移前后记录数不同');
      return;
    }
    for (var index = 0; index < before.length; index++) {
      final expected = Map<String, dynamic>.from(before[index]);
      final download = file.path == files.downloads.path;
      final field = download ? 'episodeUrl' : 'url';
      expected[field] = SiteAddress.relative(
        expected[field] as String,
        episode: true,
      );
      if (download) {
        for (final key in ['filePath', 'mp4Path']) {
          expected[key] = DownloadPaths.relative(
            expected[key] as String?,
            files.root,
          );
        }
        expected['m3u8Url'] = null;
      }
      if (jsonEncode(expected) != jsonEncode(records[index])) {
        errors.add('${file.path}: 第 $index 条记录与迁移前数据不一致');
      }
    }
  }
}
