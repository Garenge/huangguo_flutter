import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/html_parser.dart';

void main() {
  final parser = HtmlParser('https://huangguoai.com');

  test('parses video links used by the current site', () {
    const html = '''
      <div class="hg-card-grid">
        <a class="hg-drama-card" href="/video/9936/">
          <img data-src="/cover.jpg">
          <h3 class="hg-drama-card__title">示例视频</h3>
          <span class="hg-drama-card__episode">更新至2集</span>
          <span class="hg-drama-card__score">8.8分</span>
        </a>
      </div>
    ''';

    final items = parser.parseCardList(html, false);

    expect(items, hasLength(1));
    expect(items.single.id, '9936');
    expect(items.single.name, '示例视频');
    expect(items.single.pic, 'https://huangguoai.com/cover.jpg');
    expect(items.single.remark, '更新至2集 · 8.8分');
  });

  test('parses video links in rank items', () {
    const html = '''
      <div class="hg-rank-list">
        <div class="hg-rank-item">
          <a href="/video/9936/">
            <img src="/rank-cover.jpg">
            <h2 class="hg-rank-item__title">排行榜视频</h2>
          </a>
          <div class="hg-rank-item__tags">热门 · 原创</div>
        </div>
      </div>
    ''';

    final items = parser.parseRankList(html);

    expect(items, hasLength(1));
    expect(items.single.id, '9936');
    expect(items.single.name, '排行榜视频');
    expect(items.single.remark, '热门 · 原创');
  });

  test('falls back to a single play link on video pages', () {
    const html = '''
      <a class="hg-web-play__play" href="/play/9936/1/">立即播放</a>
    ''';

    final episodes = parser.parseEpisodes(html);

    expect(episodes, hasLength(1));
    expect(episodes.single.ep, '1');
    expect(episodes.single.url, 'https://huangguoai.com/play/9936/1/');
  });
}
