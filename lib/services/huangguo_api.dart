import 'dart:io' show InternetAddress;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/source_config.dart';
import '../models/proxy_settings.dart';
import 'app_log.dart';
import 'proxy_dio.dart';
import 'network_failure.dart';
import 'source_loader.dart';
import 'site_address.dart';

const _log = AppLog('HuangguoApi');

class HuangguoApi extends ChangeNotifier {
  Dio _dio;
  SourceConfig? _config;
  ProxySettings _proxySettings;
  String? _siteOverride;

  HuangguoApi({ProxySettings proxySettings = const ProxySettings()})
    : _proxySettings = proxySettings,
      _dio = createProxiedDio(proxySettings: proxySettings);

  /// 运行时切换代理，立即生效，无需重启。
  void updateProxy(ProxySettings proxySettings) {
    _proxySettings = proxySettings;
    _dio = createProxiedDio(proxySettings: proxySettings);
    _log.i(
      'proxy updated: ${proxySettings.enabled ? "ON ${proxySettings.host}:${proxySettings.port}" : "OFF (system default)"}',
    );
  }

  void updateConfig(SourceConfig config) {
    SiteAddress.register(config.site);
    _config = config;
    _log.i('config updated: site=${config.site}, tabs=${config.tabs.length}');
  }

  void updateSite(String site) {
    SiteAddress.register(site);
    if (site == this.site) return;
    _siteOverride = site;
    _log.i('site updated: $site');
    notifyListeners();
  }

  Map<String, String> _headers({String? referer}) {
    final ua = _config?.ua ?? 'Mozilla/5.0';
    return {
      'User-Agent': ua,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9',
      if (referer != null) 'Referer': referer,
    };
  }

  String get site => _siteOverride ?? _config?.site ?? 'https://huangguoai.com';

  /// 诊断用：检测设备能否访问外网
  Future<String> testConnectivity() async {
    _log.i('=== connectivity test start ===');
    final tests = <String, String Function()>{};

    // 测试 1: baidu（国内）
    tests['baidu'] = () => 'https://www.baidu.com';
    // 测试 2: apple（国际）
    tests['apple'] = () => 'https://www.apple.com';
    // 测试 3: huangguoai（目标站）
    tests['huangguoai'] = () => site;
    tests['规则源'] = () => SourceLoader.defaultUrl;

    final results = <String>[
      _proxySettings.enabled
          ? 'App 内代理：${_proxySettings.host}:${_proxySettings.port}'
          : 'App 内代理：关闭（VPN 分流由设备配置决定）',
      '目标站：$site',
    ];
    for (final entry in tests.entries) {
      try {
        _log.i('testing: ${entry.key} -> ${entry.value()}');
        final resp = await _dio.get(
          entry.value(),
          options: Options(
            headers: _headers(),
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        results.add(
          '${entry.key}: OK ${resp.statusCode} (${(resp.data as String).length} chars)',
        );
        _log.i('test ${entry.key}: OK ${resp.statusCode}');
      } catch (e) {
        results.add(
          '${entry.key}: ${describeNetworkFailure(e, entry.value(), _proxySettings)}',
        );
        _log.w('test ${entry.key}: FAIL — $e');
      }
    }

    // 测试 4: DNS 解析
    try {
      final addrs = await InternetAddress.lookup(
        Uri.parse(site).host,
      ).timeout(const Duration(seconds: 5));
      results.add(
        'DNS huangguoai.com: ${addrs.map((a) => a.address).join(", ")}',
      );
      _log.i('DNS huangguoai.com: ${addrs.map((a) => a.address).join(", ")}');
    } catch (e) {
      results.add('DNS huangguoai.com: FAIL — $e');
      _log.w('DNS huangguoai.com: FAIL — $e');
    }

    try {
      final addrs = await InternetAddress.lookup(
        'raw.githubusercontent.com',
      ).timeout(const Duration(seconds: 5));
      results.add(
        'DNS raw.githubusercontent.com: ${addrs.map((a) => a.address).join(", ")}',
      );
      _log.i(
        'DNS raw.githubusercontent.com: ${addrs.map((a) => a.address).join(", ")}',
      );
    } catch (e) {
      results.add('DNS raw.githubusercontent.com: FAIL — $e');
      _log.w('DNS raw.githubusercontent.com: FAIL — $e');
    }

    _log.i('=== connectivity test results ===\n${results.join("\n")}');
    return results.join('\n');
  }

  Future<String> _get(String url, {String? referer}) async {
    _log.d('GET $url');
    Object? lastError;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final resp = await _dio.get(
          url,
          options: Options(headers: _headers(referer: referer)),
        );
        final html = resp.data as String;
        _log.i('GET ${resp.statusCode} ${html.length} chars <- $url');
        return html;
      } catch (e) {
        lastError = e;
        if (attempt == 1) {
          _log.w('GET retry 1/1 after transient failure: $url');
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    }
    _log.e('GET failed: $url', lastError);
    throw Exception(describeNetworkFailure(lastError!, url, _proxySettings));
  }

  Future<String> fetchHome() => _get(site);

  Future<String> fetchCategory(String tabId, int page) {
    String url;
    if (tabId == 'home') {
      // 首页本身没有分页路径，后续页使用站点的“最近上新”分页。
      url = page > 1 ? '$site/newest/$page/' : site;
    } else {
      final cleanId = tabId.replaceFirst(RegExp(r'^/'), '');
      url = '$site/$cleanId/${page > 1 ? '$page/' : ''}';
    }
    return _get(url);
  }

  Future<String> fetchDetail(String dramaId) => _get('$site/video/$dramaId/');

  Future<String> fetchPlayPage(String url) =>
      _get(SiteAddress.resolve(site, url, episode: true), referer: site);

  Future<String> search(String keyword) =>
      _get('$site/search/video/${Uri.encodeComponent(keyword)}/');

  Future<List<int>> fetchImageBytes(String url) async {
    url = SiteAddress.resolve(site, url);
    _log.d('fetchImageBytes: $url');
    try {
      final resp = await _dio.get(
        url,
        options: Options(
          headers: _headers(),
          responseType: ResponseType.bytes,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final bytes = resp.data as List<int>;
      _log.d('fetchImageBytes: ${bytes.length} bytes');
      return bytes;
    } catch (e) {
      _log.e('fetchImageBytes failed: $url', e);
      rethrow;
    }
  }
}
