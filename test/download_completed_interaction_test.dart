import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/download_page_fixture.dart';

void main() {
  testWidgets('search and sort stay fixed while episodes scroll', (
    tester,
  ) async {
    await mountDownloads(tester);
    final searchTop = tester.getTopLeft(find.byType(TextField));
    final sortTop = tester.getTopLeft(find.byTooltip('排序方式'));
    await jumpDownloads(tester, 800);
    expect(tester.getTopLeft(find.byType(TextField)), searchTop);
    expect(tester.getTopLeft(find.byTooltip('排序方式')), sortTop);
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('episode title plays and delete does not also play', (
    tester,
  ) async {
    await mountDownloads(tester);
    await tester.tap(find.text('A 第1集'));
    await tester.pumpAndSettle();
    // The fixture has no local files, so playback reports a missing resource.
    expect(find.text('文件已丢失，请重新下载'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final tile = find.ancestor(
      of: find.text('A 第1集'),
      matching: find.byType(ListTile),
    );
    final button = find.descendant(of: tile, matching: find.byTooltip('删除文件'));
    await tester.tapAt(tester.getTopLeft(button) + const Offset(3, 3));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('文件已丢失，请重新下载'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow screens keep actions at least 48 pixels without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mountDownloads(tester);
      final tile = find.ancestor(
        of: find.text('A 第1集'),
        matching: find.byType(ListTile),
      );
      final buttons = find.descendant(
        of: tile,
        matching: find.byType(IconButton),
      );
      expect(buttons, findsNWidgets(4));
      for (final element in buttons.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    },
  );
}
