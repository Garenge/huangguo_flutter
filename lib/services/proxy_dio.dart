import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../models/proxy_settings.dart';
import 'app_log.dart';

const _log = AppLog('ProxyDio');

/// Create a Dio instance. If [proxySettings] is enabled, route traffic through
/// the configured proxy; otherwise connections follow the device network/VPN route.
Dio createProxiedDio({
  ProxySettings proxySettings = const ProxySettings(),
  Duration? connectTimeout,
  Duration? receiveTimeout,
}) {
  final connectTo = connectTimeout ?? const Duration(seconds: 8);
  final receiveTo = receiveTimeout ?? const Duration(seconds: 8);

  _log.i(
    'creating Dio: proxy=${proxySettings.enabled ? "ON ${proxySettings.host}:${proxySettings.port}" : "OFF (device network/VPN)"}, '
    'connectTimeout=${connectTo.inSeconds}s, receiveTimeout=${receiveTo.inSeconds}s',
  );

  final dio = Dio(
    BaseOptions(
      connectTimeout: connectTo,
      receiveTimeout: receiveTo,
      // 不设 followRedirects 等，保持默认
    ),
  );

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      if (proxySettings.enabled) {
        client.findProxy = (uri) {
          final proxy = 'PROXY ${proxySettings.host}:${proxySettings.port}';
          _log.d('findProxy($uri) -> $proxy');
          return proxy;
        };
        // Local MITM proxies may issue certificates that are not trusted by
        // Dart's HttpClient, while the proxy itself is explicitly selected.
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      }
      return client;
    },
  );
  if (!proxySettings.enabled) {
    _log.d('custom adapter enabled without proxy');
  }

  return dio;
}
