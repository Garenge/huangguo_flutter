import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/album_update_checker.dart';
import 'package:huangguo_flutter/services/huangguo_api.dart';
import 'package:huangguo_flutter/services/html_parser.dart';

void main() {
  test(
    'checker reports online episodes missing locally by episode id',
    () async {
      final api = HuangguoApi();
      final checker = AlbumUpdateChecker(
        api: api,
        parser: HtmlParser(api.site),
        fetchDetail: (_) async => '''
        <div class="hg-web-play__ep-grid">
          <img data-src="/detail-cover.jpg">
          <a href="/play/1/1/" data-ep-id="1">第1集</a>
          <a href="/play/1/2/" data-ep-id="2">第2集</a>
          <a href="/play/1/3/" data-ep-id="3">第3集</a>
        </div>
      ''',
      );

      final result = await checker.check(
        dramaId: '1',
        downloadedEpisodeIds: {'1', '3'},
      );

      expect(result.onlineEpisodeCount, 3);
      expect(result.newEpisodes, hasLength(1));
      expect(result.newEpisodes.single.ep, '2');
      expect(result.coverUrl, '/detail-cover.jpg');
      api.dispose();
    },
  );
}
