import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/download_page_fixture.dart';

void main() {
  testWidgets('global toggle collapses and expands every album', (
    tester,
  ) async {
    await mountDownloads(tester);
    await jumpDownloads(tester, 1200);
    await tester.tap(find.text('全部折叠'));
    await tester.pumpAndSettle();
    expect(find.text('全部展开'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    for (final id in ['A', 'B', 'C']) {
      expect(albumHeader(id).hitTestable(), findsOneWidget);
    }
    await tester.tap(find.text('全部展开'));
    await tester.pumpAndSettle();
    await jumpDownloads(tester, 0);
    expect(find.text('全部折叠'), findsOneWidget);
    expect(find.text('A 第1集').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('individual album changes update the global toggle', (
    tester,
  ) async {
    await mountDownloads(tester);
    for (final id in ['A', 'B', 'C']) {
      await tester.tap(albumHeader(id));
      await tester.pumpAndSettle();
    }
    expect(find.text('全部展开'), findsOneWidget);
    await tester.tap(albumHeader('B'));
    await tester.pumpAndSettle();
    expect(find.text('全部折叠'), findsOneWidget);
    expect(find.text('B 第1集').hitTestable(), findsOneWidget);
    await tester.tap(find.text('全部折叠'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('全部展开'), findsOneWidget);
  });

  testWidgets('global toggle follows the active tab including swipes', (
    tester,
  ) async {
    await mountDownloads(tester);
    await tester.tap(find.text('下载中 (0)'));
    await tester.pumpAndSettle();
    expect(find.text('全部折叠'), findsNothing);
    await tester.drag(find.byType(TabBarView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('全部折叠'), findsOneWidget);
  });

  testWidgets('global toggle disappears when completed downloads are empty', (
    tester,
  ) async {
    final service = await mountDownloads(tester);
    for (final id in ['A', 'B', 'C']) {
      service.removeAlbum(id);
    }
    await tester.pumpAndSettle();
    expect(find.text('暂无已完成下载'), findsOneWidget);
    expect(find.text('全部折叠'), findsNothing);
    expect(find.text('全部展开'), findsNothing);
  });
}
