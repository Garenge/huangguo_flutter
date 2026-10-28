import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/download_page_fixture.dart';

void main() {
  testWidgets('each album has only one header', (tester) async {
    await mountDownloads(tester);
    expect(albumHeader('A'), findsOneWidget);
    expect(
      find.byType(PinnedHeaderSliver, skipOffstage: false),
      findsNWidgets(3),
    );
    expect(find.text('一键转 MP4').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging the pinned header scrolls the list', (tester) async {
    await mountDownloads(tester);
    await jumpDownloads(tester, 200);
    final before = completedPosition(tester).pixels;
    await tester.drag(albumHeader('A'), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(completedPosition(tester).pixels, greaterThan(before));
    expect(albumHeader('A').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pinned header collapses and expands its album', (tester) async {
    await mountDownloads(tester);
    await jumpDownloads(tester, 200);
    await tester.tap(albumHeader('A'));
    await tester.pumpAndSettle();
    expect(find.text('A 第1集'), findsNothing);
    expect(find.text('A 第5集'), findsNothing);
    await jumpDownloads(tester, 0);
    expect(albumHeader('A'), findsOneWidget);
    await tester.tap(albumHeader('A'));
    await tester.pumpAndSettle();
    expect(find.text('A 第1集').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('next album replaces the previous pinned header', (tester) async {
    await mountDownloads(tester);
    await tester.scrollUntilVisible(
      find.text('B 第5集'),
      250,
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(albumHeader('A').hitTestable(), findsNothing);
    expect(albumHeader('B').hitTestable(), findsOneWidget);
    final headerTop = tester.getTopLeft(albumHeader('B')).dy;
    final viewportTop = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    expect(headerTop - viewportTop, inInclusiveRange(0, 66));
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsed albums do not leave stacked pinned headers', (
    tester,
  ) async {
    await mountDownloads(tester);
    await tester.tap(albumHeader('A'));
    await tester.pumpAndSettle();
    await tester.tap(albumHeader('B'));
    await tester.pumpAndSettle();
    await jumpDownloads(tester, 200);
    expect(albumHeader('A').hitTestable(), findsNothing);
    expect(albumHeader('B').hitTestable(), findsNothing);
    expect(albumHeader('C').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing the pinned album does not leave a stale header', (
    tester,
  ) async {
    final service = await mountDownloads(tester);
    await jumpDownloads(tester, 200);
    service.removeAlbum('A');
    await tester.pumpAndSettle();
    expect(albumHeader('A'), findsNothing);
    expect(albumHeader('B').hitTestable(), findsOneWidget);
    service.removeAlbum('B');
    service.removeAlbum('C');
    await tester.pumpAndSettle();
    expect(find.text('暂无已完成下载'), findsOneWidget);
    expect(find.byType(PinnedHeaderSliver), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
