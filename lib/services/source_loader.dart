import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/source_config.dart';
import '../models/proxy_settings.dart';
import 'app_log.dart';
import 'proxy_dio.dart';

const _log = AppLog('SourceLoader');
const _networkTimeoutSec = 15;
const _fallbackAssetPath = 'assets/huangguo_fallback.js';

class SourceLoader extends ChangeNotifier {
  SourceConfig? updatedConfig;
  static const String defaultUrl =
      'https://raw.githubusercontent.com/Yswag/xptv-extensions/refs/heads/main/js/huangguo.js';
  static const String _cacheFileName = 'huangguo_source_cache.json';

  Dio _dio;

  SourceLoader({ProxySettings proxySettings = const ProxySettings()})
    : _dio = createProxiedDio(proxySettings: proxySettings);

  /// 运行时切换代理，立即生效，无需重启。
  void updateProxy(ProxySettings proxySettings) {
    _dio = createProxiedDio(proxySettings: proxySettings);
    _log.i(
      'proxy updated: ${proxySettings.enabled ? "ON ${proxySettings.host}:${proxySettings.port}" : "OFF"}',
    );
  }

  /// 启动只读取经过校验的缓存或内置规则，更新由设置页显式触发。
  Future<SourceConfig> loadSource() async {
    return await _loadCache() ?? await _loadBundledFallback();
  }

  Future<SourceConfig?> _fetchWithTimeout(String url) async {
    _log.d('fetchWithTimeout: $url');
    final response = await _dio.get(
      url,
      options: Options(
        connectTimeout: const Duration(seconds: _networkTimeoutSec),
        receiveTimeout: const Duration(seconds: _networkTimeoutSec),
      ),
    );
    final code = response.data as String;
    _log.i('network fetch ok: ${code.length} chars');
    return _parseSource(code);
  }

  /// 读取内置 assets 兜底规则并解析
  Future<SourceConfig> _loadBundledFallback() async {
    try {
      final code = await rootBundle.loadString(_fallbackAssetPath);
      _log.i('bundled fallback loaded: ${code.length} chars');
      final config = _parseSource(code);
      await _saveCache(config);
      return config;
    } catch (e) {
      _log.e('bundled fallback failed: $e');
      rethrow;
    }
  }

  /// 更新成功后通知页面；下载或格式校验失败时保留现有缓存。
  Future<SourceConfig> forceReload({String? url}) async {
    final sourceUrl = url ?? defaultUrl;
    _log.i('forceReload from: $sourceUrl');
    final config = await _fetchWithTimeout(sourceUrl);
    if (config != null) {
      await _saveCache(config);
      updatedConfig = config;
      notifyListeners();
      return config;
    }
    throw Exception('forceReload: fetch returned null');
  }

  Future<SourceConfig?> _loadCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_cacheFileName');
      if (!await file.exists()) {
        _log.d('no cache file found');
        return null;
      }
      final json = await file.readAsString();
      final map = jsonDecode(json) as Map<String, dynamic>;
      final source = _parseSource(map['rawSource'] as String);
      _log.d('cache loaded: ${source.site}, ${source.tabs.length} tabs');
      return source;
    } catch (e) {
      _log.w('source_loader.dart::_loadCache: cache rejected: $e');
      return null;
    }
  }

  Future<void> _saveCache(SourceConfig config) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_cacheFileName');
      final json = jsonEncode({
        'site': config.site,
        'ua': config.ua,
        'tabs': config.tabs.map((t) => {'name': t.name, 'id': t.id}).toList(),
        'rawSource': config.rawSource,
      });
      await file.writeAsString(json);
      _log.d('cache saved');
    } catch (e) {
      _log.w('cache save failed: $e');
    }
  }

  SourceConfig _parseSource(String code) {
    _log.d('parsing source config...');

    final siteMatch = RegExp(
      "const\\s+SITE\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]",
    ).firstMatch(code);
    if (siteMatch == null) {
      throw const FormatException('解析规则格式不受支持，已保留现有规则');
    }
    final site = siteMatch.group(1)!;
    _log.d('site: $site');

    final uaMatch = RegExp(
      "const\\s+UA\\s*=\\s*['\\\"]([\\s\\S]*?)['\\\"]",
    ).firstMatch(code);
    final ua = uaMatch?.group(1)?.replaceAll(RegExp('\\s+'), ' ').trim() ?? '';
    if (ua.isEmpty) {
      throw const FormatException('解析规则缺少 User-Agent，已保留现有规则');
    }
    _log.d('ua: ${ua.length > 60 ? '${ua.substring(0, 60)}...' : ua}');

    final tabsBlock = RegExp(
      "const\\s+TABS\\s*=\\s*\\[([\\s\\S]*?)\\]",
    ).firstMatch(code);
    final tabs = <TabItem>[];
    if (tabsBlock != null) {
      final tabRe = RegExp(
        "\\{\\s*name:\\s*['\\\"]([^'\\\"]+)['\\\"]\\s*,\\s*id:\\s*['\\\"]([^'\\\"]+)['\\\"]\\s*\\}",
      );
      for (final match in tabRe.allMatches(tabsBlock.group(1)!)) {
        tabs.add(TabItem(name: match.group(1)!, id: match.group(2)!));
      }
    }
    if (tabs.isEmpty) {
      throw const FormatException('解析规则缺少分类，已保留现有规则');
    }
    _log.i('parsed ${tabs.length} tabs: ${tabs.map((t) => t.name).join(', ')}');

    return SourceConfig(site: site, ua: ua, tabs: tabs, rawSource: code);
  }
}
