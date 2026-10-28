import '../models/episode.dart';
import 'huangguo_api.dart';
import 'html_parser.dart';
import 'app_log.dart';

const _log = AppLog('StreamResolver');

class StreamResolver {
  final HuangguoApi _api;
  late final HtmlParser _parser;

  StreamResolver(this._api) {
    _parser = HtmlParser(_api.site);
  }

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
    final html = await _api.fetchPlayPage(episode.url);
    return _parser.parsePlayUrl(html, ep: episode.ep);
  }

  Future<String> resolveStreamFromUrl(String playUrl, {String ep = '1'}) async {
    _log.i('resolveStreamFromUrl: url=$playUrl, ep=$ep');
    final html = await _api.fetchPlayPage(playUrl);
    return _parser.parsePlayUrl(html, ep: ep);
  }

  String resolveStreamFromHtml(String html, {String ep = '1'}) {
    _log.i('resolveStreamFromHtml: ep=$ep, htmlLen=${html.length}');
    return _parser.parsePlayUrl(html, ep: ep);
  }
}
