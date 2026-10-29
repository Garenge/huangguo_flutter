import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/source_config.dart';
import 'package:huangguo_flutter/pages/home_page.dart';
import 'package:huangguo_flutter/services/download_service.dart';
import 'package:huangguo_flutter/services/huangguo_api.dart';
import 'package:huangguo_flutter/services/source_loader.dart';

class PaginationApi extends HuangguoApi {
  final requests = <String>[];
  bool failNext = false;

  @override
  Future<String> fetchCategory(String tabId, int page) async {
    requests.add('$tabId:latest:$page');
    return tabId == 'home'
        ? '<div class="hg-card-grid">${_card('home', 'latest', page)}</div>'
        : _channelHtml(tabId, page);
  }

  String _channelHtml(String tab, int page) =>
      '''
    <button data-tab="latest">最新更新</button>
    <button data-tab="hot">当前热播</button>
    <button data-tab="original">独家原创</button>
    <button data-tab="random">随机推荐</button>
    <div class="hg-card-grid" data-channel-panel="latest">${_card(tab, 'latest', page)}</div>
    <div class="hg-card-grid" data-channel-panel="hot" hidden></div>
    <template data-panel-cards="hot">${_card(tab, 'hot', 1)}</template>
    <div class="hg-card-grid" data-channel-panel="original" hidden></div>
    <template data-panel-cards="original">${_card(tab, 'original', 1)}</template>
    <div class="hg-card-grid" data-channel-panel="random">${_card(tab, 'random', 1)}</div>
  ''';

  String _card(String tab, String channel, int page) =>
      '''
    <a class="hg-drama-card" href="/video/1001/">
      <h3 class="hg-drama-card__title">$tab:$channel:$page</h3>
    </a>
  ''';

  @override
  Future<String> fetchChannelPage(
    String tabId,
    String channelTab,
    int page,
  ) async {
    requests.add('$tabId:$channelTab:$page');
    if (failNext) {
      failNext = false;
      throw Exception('测试分页请求失败');
    }
    return jsonEncode({
      'data': {
        'items': [
          {'id': 2000 + page, 'title': '$tabId:$channelTab:$page'},
        ],
        'pagination': {'page': page, 'pages': 3, 'size': 21, 'total': 43},
      },
    });
  }
}

class _PaginationSource extends SourceLoader {
  @override
  Future<SourceConfig> loadSource() async => const SourceConfig(
    site: 'https://huangguoai.com',
    ua: 'pagination-test',
    tabs: [
      TabItem(name: '首页', id: 'home'),
      TabItem(name: '短剧', id: 'ai-duanju'),
      TabItem(name: '漫剧', id: 'ai-manju'),
    ],
    rawSource: '',
  );
}

Future<PaginationApi> mountPaginationHome(WidgetTester tester) async {
  final api = PaginationApi();
  final source = _PaginationSource();
  final downloads = DownloadService(api);
  addTearDown(() {
    downloads.dispose();
    source.dispose();
    api.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HomePage(
          api: api,
          sourceLoader: source,
          downloadService: downloads,
          onOpenDetail: (_) {},
          onPlayEpisode: (_, _, _) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Future<void> selectLabel(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> nextPage(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.chevron_right_rounded));
  await tester.pumpAndSettle();
}
