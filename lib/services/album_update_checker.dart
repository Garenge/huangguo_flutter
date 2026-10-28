import '../models/episode.dart';
import 'app_log.dart';
import 'huangguo_api.dart';
import 'html_parser.dart';

const _log = AppLog('AlbumUpdateChecker');

class AlbumUpdateResult {
  final List<Episode> newEpisodes;
  final int onlineEpisodeCount;

  const AlbumUpdateResult({
    required this.newEpisodes,
    required this.onlineEpisodeCount,
  });

  bool get hasUpdates => newEpisodes.isNotEmpty;
}

class AlbumUpdateChecker {
  final Future<String> Function(String dramaId) _fetchDetail;
  final HtmlParser _parser;

  AlbumUpdateChecker({
    required HuangguoApi api,
    required HtmlParser parser,
    Future<String> Function(String dramaId)? fetchDetail,
  }) : _fetchDetail = fetchDetail ?? api.fetchDetail,
       _parser = parser;

  Future<AlbumUpdateResult> check({
    required String dramaId,
    required Set<String> downloadedEpisodeIds,
  }) async {
    _log.i('check: dramaId=$dramaId');
    final html = await _fetchDetail(dramaId);
    final episodes = _parser.parseEpisodes(html);
    final newEpisodes = episodes
        .where(
          (episode) =>
              episode.ep.isNotEmpty &&
              !downloadedEpisodeIds.contains(episode.ep),
        )
        .toList();
    _log.i(
      'check: dramaId=$dramaId, online=${episodes.length}, '
      'new=${newEpisodes.length}',
    );
    return AlbumUpdateResult(
      newEpisodes: newEpisodes,
      onlineEpisodeCount: episodes.length,
    );
  }
}
