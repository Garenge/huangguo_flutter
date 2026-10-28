import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/proxy_settings.dart';
import 'app_log.dart';

const _log = AppLog('ProxySettingsService');

class ProxySettingsService extends ChangeNotifier {
  static const String _fileName = 'proxy_settings.json';

  ProxySettingsService._();

  /// 同步构造：用平台默认值，不读磁盘，适合 initState 中调用。
  /// 调用方应在构造后调用 load() 异步加载持久化设置。
  ProxySettingsService();

  /// 异步工厂：先读磁盘再返回，保证拿到的是已持久化的真实设置。
  static Future<ProxySettingsService> create() async {
    final svc = ProxySettingsService._();
    await svc._doLoad();
    return svc;
  }

  ProxySettings _settings = ProxySettings.platformDefault;
  ProxySettings get settings => _settings;

  Future<void> load() async => _doLoad();

  Future<void> _doLoad() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      if (!await file.exists()) {
        _log.i('no saved settings, using default: $_settings');
        return;
      }
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _settings = ProxySettings.fromJson(json);
      _log.i('loaded: $_settings');
      notifyListeners();
    } catch (e) {
      _log.w('load failed: $e');
      _settings = ProxySettings.platformDefault;
    }
  }

  Future<void> save(ProxySettings settings) async {
    _settings = settings;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      await file.writeAsString(jsonEncode(settings.toJson()));
      _log.i('saved: $_settings');
      notifyListeners();
    } catch (e) {
      _log.w('save failed: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    await save(_settings.copyWith(enabled: enabled));
  }

  Future<void> setHost(String host) async {
    await save(_settings.copyWith(host: host));
  }

  Future<void> setPort(int port) async {
    await save(_settings.copyWith(port: port));
  }
}
