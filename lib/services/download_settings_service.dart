import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_log.dart';
import 'download_catalog.dart';

class DownloadSettingsService {
  DownloadSettingsService({this.directory});

  final Directory? directory;
  DownloadSortMode sortMode = DownloadSortMode.recent;
  Future<void>? _loading;
  Future<void> _saving = Future.value();

  Future<void> load() => _loading ??= _load();

  Future<File> _file() async {
    final dir = directory ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/download_settings.json');
  }

  Future<void> _load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      for (final mode in DownloadSortMode.values) {
        if (mode.name == json['sortMode']) {
          sortMode = mode;
          break;
        }
      }
    } catch (error, stack) {
      const AppLog(
        'download_settings_service.dart',
      ).e('_load: 读取下载排序设置失败，使用最近下载', error, stack);
    }
  }

  Future<void> setSortMode(DownloadSortMode mode) async {
    await load();
    sortMode = mode;
    final data = jsonEncode({'sortMode': mode.name});
    await (_saving = _saving.then((_) => _save(data)));
  }

  Future<void> _save(String data) async {
    try {
      await (await _file()).writeAsString(data, flush: true);
    } catch (error, stack) {
      const AppLog(
        'download_settings_service.dart',
      ).e('_save: 保存下载排序设置失败', error, stack);
    }
  }
}
