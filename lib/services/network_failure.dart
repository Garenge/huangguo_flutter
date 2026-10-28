import 'dart:io';
import 'package:dio/dio.dart';
import '../models/proxy_settings.dart';

String describeNetworkFailure(Object error, String url, ProxySettings proxy) {
  final host = Uri.tryParse(url)?.host ?? url;
  final route = proxy.enabled
      ? '代理 ${proxy.host}:${proxy.port}'
      : '当前网络（未指定 App 内代理）';
  if (error is! DioException) return '$host 加载失败：$error';
  final cause = error.error;
  final detail = cause?.toString() ?? error.message ?? '';
  if (detail.contains('Proxy failed to establish tunnel')) {
    return '$route 无法连接 $host：$detail。请检查代理节点和分流规则。';
  }
  if (cause is HandshakeException) {
    return '$host 的 HTTPS 握手失败，路径：$route。'
        '请在同一设备的浏览器验证该站点，并检查 VPN 分流规则。';
  }
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout) {
    return '连接 $host 超时，路径：$route。请检查网络后重试。';
  }
  if (error.response != null) {
    return '$host 返回 HTTP ${error.response!.statusCode}，路径：$route。';
  }
  return '$host 连接失败，路径：$route。$detail';
}
