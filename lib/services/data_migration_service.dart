import 'dart:convert';
import 'dart:io';

import 'app_log.dart';
import 'data_migration_validator.dart';
import 'download_paths.dart';
import 'migration_storage.dart';
import 'site_address.dart';

const _log = AppLog('data_migration_service.dart');

class DataMigrationService {
  final MigrationFiles files;
  DataMigrationService(Directory documents) : files = MigrationFiles(documents);

  Future<void> run() async {
    try {
      await _registerCachedSite();
      // 每次启动都检查并修复遗留数据，不仅依赖版本标记。
      for (final file in files.records) {
        await _migrate(file);
      }
      final report = await DataMigrationValidator(files).verify();
      await writeMigrationJson(files.report, report);
      if (report['verified'] != true) {
        throw StateError('迁移校验未通过：${report['errors']}');
      }
      await writeMigrationJson(files.marker, {'version': 1, ...report});
      _log.i(
        'run: 迁移校验通过，记录数=${report['checkedRecords']}，'
        '资源提示=${(report['warnings'] as List).length}',
      );
    } catch (error, stack) {
      _log.e('run: 迁移或校验失败，保留备份等待重试', error, stack);
      rethrow;
    }
  }

  Future<void> _registerCachedSite() async {
    for (final name in [
      'huangguo_source_cache.json',
      'site_endpoint_settings.json',
    ]) {
      final file = File('${files.documents.path}/$name');
      if (!await file.exists()) continue;
      final data = jsonDecode(await file.readAsString()) as Map;
      final site = data['site'] ?? data['selectedUrl'];
      if (site is String) SiteAddress.register(site);
    }
  }

  Future<void> _migrate(File file) async {
    if (!await file.exists()) return;
    final records = await readMigrationRecords(file);
    final before = jsonEncode(records);
    final download = file.path == files.downloads.path;
    for (final record in records) {
      _normalize(record, download);
    }
    if (before == jsonEncode(records)) return;
    final backup = File('${file.path}.relative_v1.bak');
    if (!await backup.exists()) await file.copy(backup.path);
    await writeMigrationJson(file, records);
    _log.i('_migrate: 已转换 ${file.path}，记录数=${records.length}');
  }

  void _normalize(Map<String, dynamic> record, bool download) {
    final field = download ? 'episodeUrl' : 'url';
    record[field] = SiteAddress.relative(
      record[field] as String,
      episode: true,
    );
    if (!download) return;
    for (final key in ['filePath', 'mp4Path']) {
      record[key] = DownloadPaths.relative(record[key] as String?, files.root);
    }
    // 带签名的 CDN URL 是临时结果，恢复任务时重新解析。
    record['m3u8Url'] = null;
  }
}
