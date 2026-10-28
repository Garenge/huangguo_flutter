import 'dart:io';

class ProxySettings {
  final bool enabled;
  final String host;
  final int port;

  const ProxySettings({
    this.enabled = false,
    this.host = '127.0.0.1',
    this.port = 7897,
  });

  /// 平台自适应默认值：桌面端默认启用代理，手机端默认关闭。
  /// 手机端小火箭/VPN 已接管系统流量，无需 App 内部代理。
  static ProxySettings get platformDefault {
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;
    return ProxySettings(
      enabled: isDesktop,
      host: '127.0.0.1',
      port: 7897,
    );
  }

  ProxySettings copyWith({bool? enabled, String? host, int? port}) {
    return ProxySettings(
      enabled: enabled ?? this.enabled,
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'host': host,
        'port': port,
      };

  factory ProxySettings.fromJson(Map<String, dynamic> json) {
    return ProxySettings(
      enabled: json['enabled'] as bool? ?? false,
      host: json['host'] as String? ?? '127.0.0.1',
      port: json['port'] as int? ?? 7897,
    );
  }

  @override
  String toString() =>
      'ProxySettings(enabled: $enabled, host: $host, port: $port)';
}
