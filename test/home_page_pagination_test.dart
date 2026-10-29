import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/home_pagination_fixture.dart';

void main() {
  testWidgets(
    'hot pagination loads new items, preserves tabs and caches pages',
    (tester) async {
      final api = await mountPaginationHome(tester);
      await selectLabel(tester, '短剧');
      await selectLabel(tester, '当前热播');
      expect(find.text('ai-duanju:hot:1'), findsOneWidget);
      await nextPage(tester);
      expect(api.requests.last, 'ai-duanju:hot:2');
      expect(find.text('ai-duanju:hot:2'), findsOneWidget);
      expect(find.text('ai-duanju:hot:1'), findsNothing);
      expect(find.text('当前热播'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(find.text('ai-duanju:hot:1'), findsOneWidget);
      await nextPage(tester);
      expect(api.requests.where((r) => r == 'ai-duanju:hot:2'), hasLength(1));
      await nextPage(tester);
      expect(find.text('ai-duanju:hot:3'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('switching channels resets page and isolates caches', (
    tester,
  ) async {
    final api = await mountPaginationHome(tester);
    await selectLabel(tester, '短剧');
    await selectLabel(tester, '当前热播');
    await nextPage(tester);
    await selectLabel(tester, '独家原创');
    expect(find.text('第 1 页'), findsOneWidget);
    expect(find.text('ai-duanju:original:1'), findsOneWidget);
    await nextPage(tester);
    expect(api.requests.last, 'ai-duanju:original:2');
    expect(find.text('ai-duanju:original:2'), findsOneWidget);
    await selectLabel(tester, '最新更新');
    await nextPage(tester);
    expect(api.requests.last, 'ai-duanju:latest:2');
    expect(find.text('ai-duanju:latest:2'), findsOneWidget);
    await selectLabel(tester, '漫剧');
    expect(find.text('第 1 页'), findsOneWidget);
    await selectLabel(tester, '当前热播');
    await nextPage(tester);
    expect(api.requests.last, 'ai-manju:hot:2');
    expect(find.text('ai-manju:hot:2'), findsOneWidget);
  });

  testWidgets('failed channel page can be retried', (tester) async {
    final api = await mountPaginationHome(tester);
    await selectLabel(tester, '短剧');
    await selectLabel(tester, '当前热播');
    api.failNext = true;
    await nextPage(tester);
    expect(find.text('重试'), findsOneWidget);
    await selectLabel(tester, '重试');
    expect(find.text('ai-duanju:hot:2'), findsOneWidget);
    expect(api.requests.where((r) => r == 'ai-duanju:hot:2'), hasLength(2));
  });

  testWidgets(
    'home HTML pagination remains unchanged and random has no pager',
    (tester) async {
      final api = await mountPaginationHome(tester);
      await nextPage(tester);
      expect(api.requests.last, 'home:latest:2');
      expect(find.text('home:latest:2'), findsOneWidget);
      await selectLabel(tester, '短剧');
      await selectLabel(tester, '随机推荐');
      expect(find.text('第 1 页'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
            )
            .onPressed,
        isNull,
      );
    },
  );
}
