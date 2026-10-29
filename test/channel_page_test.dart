import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/channel_page.dart';

void main() {
  String response(
    List<Map<String, dynamic>> items, {
    int page = 2,
    int pages = 3,
  }) => jsonEncode({
    'data': {
      'items': items,
      'pagination': {'page': page, 'pages': pages},
    },
  });

  test('parses JSON cards, deduplicates IDs and keeps pagination metadata', () {
    final page = ChannelPage.fromResponse(
      response([
        {
          'id': 42,
          'title': '第二页条目',
          'cover': 'https://huangguoai.com/cover.jpg',
          'episode_count': 7,
          'score': 8.1,
        },
        {'id': 42, 'title': '重复条目'},
        {'id': 43, 'title': '完结条目', 'is_finished': true, 'total_episodes': 12},
      ]),
    );
    expect(page.items, hasLength(2));
    expect(page.items.first.id, '42');
    expect(page.items.first.pic, '/cover.jpg');
    expect(page.items.first.remark, '更新至7集 · 8.1分');
    expect(page.items.last.remark, '全12集');
    expect(page.page, 2);
    expect(page.hasNextPage, isTrue);
  });

  test('last and empty pages do not have a next page', () {
    expect(
      ChannelPage.fromResponse(response([], page: 3)).hasNextPage,
      isFalse,
    );
    expect(
      ChannelPage.fromResponse(response([], page: 1, pages: 0)).items,
      isEmpty,
    );
  });

  test('invalid responses fail instead of caching an empty success', () {
    expect(
      () => ChannelPage.fromResponse('<html>error</html>'),
      throwsFormatException,
    );
    expect(
      () => ChannelPage.fromResponse('{"data":null}'),
      throwsA(isA<TypeError>()),
    );
  });
}
