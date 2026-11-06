import '../models/episode.dart';
import 'huangguo_api.dart';
import 'html_parser.dart';
import 'app_log.dart';
import 'site_address.dart';

const _log = AppLog('StreamResolver');

class StreamResolver {
  final HuangguoApi _api;
  late final HtmlParser _parser;
  Map<String, String> _streamHeaders = const {};

  StreamResolver(this._api) {
    _parser = HtmlParser(_api.site);
  }

  Map<String, String> get streamHeaders => _streamHeaders;

  void updateSite(String site) {
    _parser = HtmlParser(site);
  }

  Future<List<Episode>> resolveEpisodes(String dramaId) async {
    _log.i('resolveEpisodes: dramaId=$dramaId');
    final html = await _api.fetchDetail(dramaId);
    return _parser.parseEpisodes(html);
  }

  Future<String> resolveStream(Episode episode) async {
    _log.i('resolveStream: ep=${episode.ep}, url=${episode.url}');
    final playback = await _resolvePlayback(episode.url, episode.ep);
    if (playback != null) return playback;
    final html = await _api.fetchPlayPage(episode.url);
    return _parser.parsePlayUrl(html, ep: episode.ep);
  }

  Future<String> resolveStreamFromUrl(String playUrl, {String ep = '1'}) async {
    _log.i('resolveStreamFromUrl: url=$playUrl, ep=$ep');
    final playback = await _resolvePlayback(playUrl, ep);
    if (playback != null) return playback;
    final html = await _api.fetchPlayPage(playUrl);
    return _parser.parsePlayUrl(html, ep: ep);
  }

  String resolveStreamFromHtml(String html, {String ep = '1'}) {
    _log.i('resolveStreamFromHtml: ep=$ep, htmlLen=${html.length}');
    return _parser.parsePlayUrl(html, ep: ep);
  }

  Future<String?> _resolvePlayback(String url, String ep) async {
    final resolved = SiteAddress.resolve(_api.site, url, episode: true);
    final match = RegExp(
      r'/(?:video|detail)/(\d+)(?:/|$)',
    ).firstMatch(resolved);
    if (match == null) return null;

    final videoId = match.group(1)!;
    try {
      final payload = await _api.fetchPlayback(videoId, episode: ep);
      final streams = payload['streams'];
      final main = streams is Map<String, dynamic>
          ? streams['main']?.toString()
          : null;
      if (main == null || main.isEmpty) return null;
      final cdn = payload['cdn'];
      if (cdn is Map<String, dynamic>) {
        final authKey = cdn['authKey']?.toString() ?? '';
        final authValue = cdn['authValue']?.toString() ?? '';
        final app = cdn['app']?.toString() ?? '';
        _streamHeaders = {
          if (authKey.isNotEmpty && authValue.isNotEmpty) authKey: authValue,
          if (app.isNotEmpty) 'x-cdn-app': app,
        };
      } else {
        _streamHeaders = const {};
      }
      _log.i('resolvePlayback: video=$videoId, ep=$ep');
      return main;
    } catch (error, stack) {
      _log.w('resolvePlayback failed, falling back to HTML: video=$videoId');
      _log.d('$error\n$stack');
      return null;
    }
  }
}
