import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'app_log.dart';

class PlaybackSettingsService extends ChangeNotifier {
  PlaybackSettingsService({this.directory});

  final Directory? directory;
  static const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];
  double speed = 1;
  bool pauseOnLeave = true;
  Future<void>? _loading;
  Future<void> _saving = Future.value();
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() => _loading ??= _load();

  Future<File> _file() async {
    final dir = directory ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/playback_settings.json');
  }

  Future<void> _load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final savedSpeed = json['speed'];
      if (savedSpeed is num && speeds.contains(savedSpeed.toDouble())) {
        speed = savedSpeed.toDouble();
      }
      if (json['pauseOnLeave'] is bool) {
        pauseOnLeave = json['pauseOnLeave'] as bool;
      }
      if (!_disposed) notifyListeners();
    } catch (error, stack) {
      const AppLog(
        'playback_settings_service.dart',
      ).e('_load: 读取播放设置失败，使用默认值', error, stack);
    }
  }

  Future<void> setSpeed(double value) async {
    await load();
    if (!speeds.contains(value) || speed == value) return;
    speed = value;
    await _save();
  }

  Future<void> setPauseOnLeave(bool value) async {
    await load();
    if (pauseOnLeave == value) return;
    pauseOnLeave = value;
    await _save();
  }

  Future<void> _save() {
    final data = jsonEncode({'speed': speed, 'pauseOnLeave': pauseOnLeave});
    if (!_disposed) notifyListeners();
    return _saving = _saving.then((_) async {
      try {
        await (await _file()).writeAsString(data, flush: true);
      } catch (error, stack) {
        const AppLog(
          'playback_settings_service.dart',
        ).e('_save: 保存播放设置失败', error, stack);
      }
    });
  }
}
