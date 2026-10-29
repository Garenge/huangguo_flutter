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
    expect(items.single.pic, '/cover.jpg');
    expect(items.single.remark, '更新至2集 · 8.8分');
  });

  test('parses channel tabs and selects the matching card panel', () {
    const html = '''
      <section data-channel-page data-active-tab="latest">
        <div class="hg-channel-tabs">
          <button class="hg-channel-tabs__item is-active" data-tab="latest">最新更新</button>
          <button class="hg-channel-tabs__item" data-tab="hot">当前热播</button>
          <button class="hg-channel-tabs__item" data-tab="original">独家原创</button>
          <button class="hg-channel-tabs__item" data-tab="random">随机推荐</button>
        </div>
        <div class="hg-card-grid" data-channel-panel="latest">
          <a class="hg-drama-card" href="/video/1001/">
            <img src="/latest.jpg">
            <h3 class="hg-drama-card__title">最新条目</h3>
          </a>
        </div>
        <div class="hg-card-grid" data-channel-panel="hot">
          <a class="hg-drama-card" href="/video/1002/">
            <img src="/hot.jpg">
            <h3 class="hg-drama-card__title">热门条目</h3>
          </a>
        </div>
      </section>
    ''';

    final tabs = parser.parseChannelTabs(html);
    final hotItems = parser.parseCardList(html, false, channelTabId: 'hot');

    expect(tabs.map((tab) => '${tab.id}:${tab.name}'), [
      'latest:最新更新',
      'hot:当前热播',
      'original:独家原创',
      'random:随机推荐',
    ]);
    expect(hotItems, hasLength(1));
    expect(hotItems.single.id, '1002');
    expect(hotItems.single.name, '热门条目');
  });

  test('parses channel panels identified by tab panel and nested section', () {
    const html = '''
      <button data-channel-tab="hot">当前热播</button>
      <section data-tab-panel="hot">
        <div class="hg-card-grid">
          <a class="hg-drama-card" href="/video/2002/">
            <h3 class="hg-drama-card__title">热播条目</h3>
          </a>
        </div>
      </section>
      <div class="hg-card-grid" id="original">
        <a class="hg-drama-card" href="/video/2003/">
          <h3 class="hg-drama-card__title">原创条目</h3>
        </a>
      </div>
    ''';

    expect(parser.parseChannelTabs(html).single.id, 'hot');
    expect(
      parser.parseCardList(html, false, channelTabId: 'hot').single.name,
      '热播条目',
    );
    expect(
      parser.parseCardList(html, false, channelTabId: 'original').single.name,
      '原创条目',
    );
  });

  test('parses lazy channel cards stored in an HTML template', () {
    const html = '''
      <div class="hg-card-grid is-active" data-channel-panel="latest">
        <a class="hg-drama-card" href="/video/1001/">
          <h3 class="hg-drama-card__title">最新条目</h3>
        </a>
      </div>
      <div class="hg-card-grid" data-channel-panel="hot" hidden></div>
      <template data-panel-cards="hot">
        <div class="hg-drama-card">
          <a href="/video/2833/">
            <h3 class="hg-drama-card__title">热播条目</h3>
          </a>
        </div>
      </template>
    ''';

    final hotItems = parser.parseCardList(html, false, channelTabId: 'hot');

    expect(hotItems, hasLength(1));
    expect(hotItems.single.id, '2833');
    expect(hotItems.single.name, '热播条目');
  });

  test('keeps the first-grid fallback when no channel tab is specified', () {
    const html = '''
      <div class="hg-card-grid">
        <a class="hg-drama-card" href="/video/1001/">
          <h3 class="hg-drama-card__title">第一组</h3>
        </a>
      </div>
      <div class="hg-card-grid">
        <a class="hg-drama-card" href="/video/1002/">
          <h3 class="hg-drama-card__title">第二组</h3>
        </a>
      </div>
    ''';

    final items = parser.parseCardList(html, false);

    expect(items, hasLength(1));
    expect(items.single.id, '1001');
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
    expect(episodes.single.url, '/play/9936/1/');
  });

  test('parses cover from video detail pages', () {
    const html = '''
      <div class="hg-web-detail">
        <img data-original="/detail-cover.jpg">
      </div>
    ''';

    expect(parser.parseDetailCover(html), '/detail-cover.jpg');
  });

  test('prefers the detail page cover over other images', () {
    const html = '''
      <div class="hg-web-detail__cover">
        <img data-lazy-src="/detail-cover.jpg">
      </div>
      <div class="hg-web-play">
        <img src="/episode-image.jpg">
      </div>
    ''';

    expect(parser.parseDetailCover(html), '/detail-cover.jpg');
  });
}
