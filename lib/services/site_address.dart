import 'site_endpoint_service.dart';

/// 站内地址只存路径；外部图片、CDN 和手动解析地址保留来源。
class SiteAddress {
  static final Set<String> _hosts = {
    for (final site in SiteEndpointService.urls) Uri.parse(site).host,
  };

  static void register(String site) {
    final host = Uri.parse(site).host;
    if (host.isNotEmpty) _hosts.add(host);
  }

  static String relative(String value, {bool episode = false}) {
    if (value.isEmpty) return value;
    final uri = Uri.parse(value);
    final historicalEpisode =
        episode && RegExp(r'^/play/\d+(?:/|$)').hasMatch(uri.path);
    if (uri.hasAuthority && !_hosts.contains(uri.host) && !historicalEpisode) {
      return value.startsWith('//') ? 'https:$value' : value;
    }
    if (uri.hasScheme && uri.scheme != 'http' && uri.scheme != 'https') {
      return value;
    }
    final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
    return '$path${uri.hasQuery ? '?${uri.query}' : ''}'
        '${uri.hasFragment ? '#${uri.fragment}' : ''}';
  }

  static String resolve(String site, String value, {bool episode = false}) {
    final path = relative(value, episode: episode);
    return Uri.parse('$site/').resolve(path).toString();
  }
}
