import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/proxy_settings.dart';
import '../models/site_endpoint.dart';
import 'app_log.dart';
import 'proxy_dio.dart';

const _log = AppLog('SiteEndpointService');

class SiteEndpointService extends ChangeNotifier {
  static const String primaryUrl = 'https://huangguoai.com';
  static const List<String> urls = [
    primaryUrl,
    'https://l5f9m.rxzfszht.cc',
    'https://blolhh.rxzfszht.cc',
    'https://mxz58.rxzfszht.cc',
    'https://owfv.rxzfszht.cc',
    'https://zd43td.rxzfszht.cc',
    'https://qp0h.rxzfszht.cc',
    'https://olci.rxzfszht.cc',
    'https://j5rs.rxzfszht.cc',
    'https://lhsb.rxzfszht.cc',
  ];
  static const String _fileName = 'site_endpoint_settings.json';

  SiteEndpointService({ProxySettings proxySettings = const ProxySettings()})
    : _proxySettings = proxySettings,
      _selectedUrl = primaryUrl;

  ProxySettings _proxySettings;
  String _selectedUrl;
  List<SiteEndpoint> _results = const [];

  String get selectedUrl => _selectedUrl;
  List<SiteEndpoint> get results => _results;

  void updateProxy(ProxySettings settings) {
    _proxySettings = settings;
  }

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      if (!await file.exists()) return;
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final url = map['selectedUrl'] as String?;
      if (url != null && urls.contains(url)) {
        _selectedUrl = url;
      }
      _log.i('loaded selected site: $_selectedUrl');
    } catch (e) {
      _log.w('site settings load failed: $e');
    }
  }

  Future<void> select(String url) async {
    if (!urls.contains(url)) {
      throw ArgumentError.value(url, 'url', '站点不在内置列表中');
    }
    _selectedUrl = url;
    notifyListeners();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      await file.writeAsString(jsonEncode({'selectedUrl': url}));
      _log.i('saved selected site: $url');
    } catch (e) {
      _log.w('site settings save failed: $e');
    }
  }

  Future<List<SiteEndpoint>> testAll() async {
    final dio = createProxiedDio(proxySettings: _proxySettings);
    final results = await Future.wait(urls.map((url) => _testOne(dio, url)));
    _results = results;
    dio.close(force: true);
    notifyListeners();
    return results;
  }

  Future<SiteEndpoint> _testOne(Dio dio, String url) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await dio.get<String>(
        '$url/',
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      stopwatch.stop();
      final body = response.data ?? '';
      final valid =
          response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 400 &&
          body.length >= 100 &&
          (body.contains('<html') || body.contains('hg-card-grid'));
      if (!valid) {
        return SiteEndpoint(
          url: url,
          error: 'HTTP ${response.statusCode ?? 'unknown'} 或页面内容无效',
        );
      }
      return SiteEndpoint(url: url, latency: stopwatch.elapsed);
    } catch (e) {
      stopwatch.stop();
      _log.w('site test failed: $url');
      return SiteEndpoint(url: url, error: _describeError(e));
    }
  }

  Future<SiteEndpoint?> selectFastest() async {
    final results = await testAll();
    final available = results.where((item) => item.isAvailable).toList()
      ..sort((a, b) => a.latency!.compareTo(b.latency!));
    if (available.isEmpty) return null;
    await select(available.first.url);
    return available.first;
  }

  String _describeError(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return '连接超时';
      }
      if (error.response?.statusCode != null) {
        return 'HTTP ${error.response!.statusCode}';
      }
    }
    return '连接失败';
  }
}
