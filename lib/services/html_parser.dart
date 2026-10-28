import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/drama.dart';
import '../models/episode.dart';
import '../models/source_config.dart';
import 'app_log.dart';
import 'site_address.dart';

const _log = AppLog('HtmlParser');

class HtmlParser {
  static final _dramaIdPattern = RegExp(r'/(?:video|detail)/(\d+)(?:/|$)');

  HtmlParser(String site) {
    SiteAddress.register(site);
  }

  void updateSite(String site) {
    SiteAddress.register(site);
    _log.i('site updated: $site');
  }

  // ---------- Utilities ----------

  String fix(String? url) {
    if (url == null || url.isEmpty) return '';
    return SiteAddress.relative(url);
  }

  String imgSrc(String? url) {
    final fixed = fix(url);
    return fixed;
  }

  String stripTags(String s) {
    return s.replaceAll(RegExp('<[^>]*>'), '').trim();
  }

  // ---------- Card Parsing ----------

  List<TabItem> parseChannelTabs(String html) {
    final document = html_parser.parse(html);
    final tabs = <TabItem>[];
    final seen = <String>{};

    for (final button in document.querySelectorAll(
      '.hg-channel-tabs__item[data-tab]',
    )) {
      final id = button.attributes['data-tab']?.trim() ?? '';
      final name = stripTags(button.text);
      if (id.isEmpty || name.isEmpty || !seen.add(id)) continue;
      tabs.add(TabItem(name: name, id: id));
    }

    _log.i('parseChannelTabs: ${tabs.length} channel tabs');
    return tabs;
  }

  List<Drama> parseCardList(
    String html,
    bool allGrids, {
    String? channelTabId,
  }) {
    final document = html_parser.parse(html);
    final grids = channelTabId == null
        ? document.querySelectorAll('.hg-card-grid')
        : document.querySelectorAll(
            '.hg-card-grid[data-channel-panel="$channelTabId"]',
          );
    if (grids.isEmpty) {
      _log.w(
        'parseCardList: no .hg-card-grid found'
        '${channelTabId == null ? '' : ' for channel=$channelTabId'}',
      );
      return [];
    }

    final seen = <String>{};
    final list = <Drama>[];

    final gridsToProcess = channelTabId != null
        ? grids
        : (allGrids ? grids : [grids.first]);
    for (final grid in gridsToProcess) {
      final cards = grid.querySelectorAll('.hg-drama-card');
      _log.d('parseCardList: found ${cards.length} cards in grid');
      for (final card in cards) {
        final drama = _parseCardBlock(card);
        if (drama != null && seen.add(drama.id)) {
          list.add(drama);
        }
      }
    }

    _log.i('parseCardList: ${list.length} unique dramas');
    return list;
  }

  Drama? _parseCardBlock(dom.Element card) {
    final link = _findDramaLink(card);
    if (link == null) return null;
    final href = link.attributes['href'] ?? '';
    final idMatch = _dramaIdPattern.firstMatch(href);
    if (idMatch == null) return null;
    final id = idMatch.group(1)!;

    String? pic;
    final img = card.querySelector('img');
    if (img != null) {
      pic = img.attributes['data-src'] ?? img.attributes['src'];
    }

    final titleEl = card.querySelector('.hg-drama-card__title');
    String? title = titleEl != null ? stripTags(titleEl.text) : null;
    title ??= stripTags(link.text);

    final epEl = card.querySelector('.hg-drama-card__episode');
    final scoreEl = card.querySelector('.hg-drama-card__score');
    final ep = epEl != null ? stripTags(epEl.text) : '';
    final score = scoreEl != null ? stripTags(scoreEl.text) : '';
    final remark = [ep, score].where((s) => s.isNotEmpty).join(' \u00b7 ');

    return Drama(id: id, name: title, pic: imgSrc(pic), remark: remark);
  }

  dom.Element? _findDramaLink(dom.Element element) {
    if (element.localName == 'a' &&
        (element.attributes['href']?.contains('/video/') == true ||
            element.attributes['href']?.contains('/detail/') == true)) {
      return element;
    }
    return element.querySelector('a[href*="/video/"]') ??
        element.querySelector('a[href*="/detail/"]');
  }

  // ---------- Rank List Parsing ----------

  List<Drama> parseRankList(String html) {
    final document = html_parser.parse(html);
    final rankList = document.querySelector('.hg-rank-list');
    if (rankList == null) {
      _log.w('parseRankList: no .hg-rank-list found');
      return [];
    }

    final items = rankList.querySelectorAll('.hg-rank-item');
    _log.d('parseRankList: found ${items.length} rank items');
    final seen = <String>{};
    final list = <Drama>[];

    for (final item in items) {
      final link = _findDramaLink(item);
      if (link == null) continue;
      final href = link.attributes['href'] ?? '';
      final idMatch = _dramaIdPattern.firstMatch(href);
      if (idMatch == null || !seen.add(idMatch.group(1)!)) continue;
      final id = idMatch.group(1)!;

      final titleEl = item.querySelector('.hg-rank-item__title');
      String? title = titleEl != null ? stripTags(titleEl.text) : null;
      title ??= stripTags(link.text);

      final img = item.querySelector('img');
      final pic = img?.attributes['data-src'] ?? img?.attributes['src'];

      final tagsEl = item.querySelector('.hg-rank-item__tags');
      final tags = tagsEl != null ? stripTags(tagsEl.text) : '';

      list.add(Drama(id: id, name: title, pic: imgSrc(pic), remark: tags));
    }

    _log.i('parseRankList: ${list.length} unique dramas');
    return list;
  }

  // ---------- Episode Parsing ----------

  List<Episode> parseEpisodes(String html) {
    final document = html_parser.parse(html);
    final episodes = <Episode>[];

    final epGrid =
        document.querySelector(
          '.hg-web-play__ep-grid, .hg-web-detail__ep-grid',
        ) ??
        document.querySelector('[data-web-play-ep-grid]');
    if (epGrid != null) {
      final links = epGrid.querySelectorAll('a');
      _log.d('parseEpisodes: found ${links.length} episode links');
      for (final link in links) {
        final href = link.attributes['href'];
        if (href == null) continue;
        final epId = link.attributes['data-ep-id'] ?? '';
        final text = stripTags(link.text);
        final parsedEp = epId.isNotEmpty
            ? epId
            : (RegExp(r'\d+').firstMatch(text)?.group(0) ?? '');
        final name = parsedEp.isNotEmpty
            ? '\u7b2c${int.parse(parsedEp)}\u96c6'
            : text;
        episodes.add(
          Episode(
            name: name,
            url: SiteAddress.relative(href, episode: true),
            ep: parsedEp.isNotEmpty ? '${int.parse(parsedEp)}' : '',
          ),
        );
      }
    }

    if (episodes.isEmpty) {
      final playLink = document.querySelector(
        '.hg-web-detail__play, .hg-web-play__play',
      );
      if (playLink != null) {
        final href = playLink.attributes['href'];
        if (href != null) {
          episodes.add(
            Episode(
              name: '\u7b2c1\u96c6',
              url: SiteAddress.relative(href, episode: true),
              ep: '1',
            ),
          );
        }
      }
    }

    if (episodes.isEmpty) {
      _log.w('parseEpisodes: no episodes found');
    } else {
      _log.i('parseEpisodes: ${episodes.length} episodes');
    }
    return episodes;
  }

  String parseDetailCover(String html) {
    final document = html_parser.parse(html);
    final meta = document.querySelector(
      'meta[property="og:image"], meta[name="twitter:image"]',
    );
    final metaUrl = meta?.attributes['content'];
    if (metaUrl != null && metaUrl.isNotEmpty) return imgSrc(metaUrl);

    final image = document.querySelector(
      '.hg-web-detail__cover img, '
      '.hg-web-detail__poster img, '
      '.hg-web-detail img, '
      '.hg-web-play__cover img, '
      '.hg-web-play img, '
      '[class*="detail"] img, '
      '[class*="play"] img',
    );
    if (image == null) return '';

    for (final attribute in [
      'data-src',
      'data-original',
      'data-lazy-src',
      'data-image',
      'src',
    ]) {
      final url = image.attributes[attribute];
      if (url != null && url.isNotEmpty) return imgSrc(url);
    }
    return '';
  }

  // ---------- Play URL Parsing ----------

  String parsePlayUrl(String html, {String ep = '1'}) {
    final scriptMatch = RegExp(
      '<script\\s+id="videoInitialData"[^>]*>([\\s\\S]*?)</script>',
    ).firstMatch(html);

    if (scriptMatch == null) {
      _log.e('parsePlayUrl: videoInitialData script not found');
      throw Exception('videoInitialData script not found');
    }

    final jsonStr = scriptMatch.group(1)!.trim();
    _log.d('parsePlayUrl: videoInitialData found, ${jsonStr.length} chars');

    String? play;
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final epPlaySrcs = data['epPlaySrcs'];
      if (epPlaySrcs is Map) {
        play =
            epPlaySrcs[ep]?.toString() ??
            epPlaySrcs[int.tryParse(ep)]?.toString();
        if (play != null && play.isNotEmpty) {
          _log.d('parsePlayUrl: found epPlaySrcs[$ep]');
        }
      }
      if (play == null || play.isEmpty) {
        play = data['videoSrc']?.toString();
        if (play != null && play.isNotEmpty) {
          _log.d('parsePlayUrl: found videoSrc');
        }
      }
    } catch (e) {
      _log.w('parsePlayUrl: invalid videoInitialData JSON: $e');
    }

    if (play == null || play.isEmpty) {
      _log.e('parsePlayUrl: no play URL found in json');
      throw Exception('Play URL not found');
    }

    play = play.replaceAll('\\u0026', '&');

    if (!play.startsWith('http')) {
      final urlMatch = RegExp('(https?://[^\\s"\\\']+)').firstMatch(play);
      if (urlMatch != null) {
        play = urlMatch.group(1)!;
      } else {
        _log.e('parsePlayUrl: invalid URL format: $play');
        throw Exception('Invalid play URL format: $play');
      }
    }

    _log.i('parsePlayUrl: $play');
    return play;
  }
}
