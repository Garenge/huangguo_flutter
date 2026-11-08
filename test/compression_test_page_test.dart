import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/pages/compression_test_page.dart';
import 'package:huangguo_flutter/widgets/app_video_player.dart';

import 'helpers/compression_page_fixture.dart';

void main() {
  testWidgets('select, compress, compare at the same position, then clean up', (
    tester,
  ) async {
    final fixture = await mountCompressionPage(tester);
    await selectCompressionEpisode(tester);
    expect(
      fixture.controller.sourceBytes,
      90,
      reason:
          'status=${fixture.controller.status}, '
          'busy=${fixture.controller.busy}, error=${fixture.controller.error}, '
          'source=${fixture.controller.sourcePath}',
    );
    await tester.ensureVisible(find.text('清晰优先'));
    await tester.tap(find.text('清晰优先'));
    await flushCompressionPage(tester);
    await tester.ensureVisible(find.text('预览压缩视频'));
    await tester.pump();
    expect(find.text('原片段：90 B'), findsOneWidget);
    expect(find.text('压缩片段：40 B'), findsOneWidget);
    expect(find.text('节省 55.6%'), findsOneWidget);
    expect(find.text('压缩完成 100%'), findsOneWidget);
    await tester.ensureVisible(find.text('预览原视频'));
    await tester.tap(find.text('预览原视频'));
    await flushCompressionPage(tester);
    var player = tester.widget<AppVideoPlayer>(find.byType(AppVideoPlayer));
    expect(player.title, '原片段 · 第1集');
    await player.controller!.seekTo(const Duration(seconds: 15));
    await tester.ensureVisible(find.text('预览压缩视频'));
    await tester.tap(find.text('预览压缩视频'));
    await flushCompressionPage(tester);
    player = tester.widget<AppVideoPlayer>(find.byType(AppVideoPlayer));
    expect(player.title, '压缩片段 · 第1集');
    expect(player.controller!.value.position, const Duration(seconds: 15));
    final session = fixture.controller.workspace.directory;
    await tester.tap(find.byType(BackButton).first);
    await flushCompressionPage(tester);
    await tester.pumpAndSettle();
    expect(find.byType(CompressionTestPage), findsNothing);
    expect(session.existsSync(), isFalse);
    expect(fixture.source.lengthSync(), 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back during compression cancels and deletes partial files', (
    tester,
  ) async {
    final fixture = await mountCompressionPage(tester);
    await selectCompressionEpisode(tester);
    fixture.engine.compression = Completer<void>();
    await tester.ensureVisible(find.text('清晰优先'));
    await tester.tap(find.text('清晰优先'));
    await flushCompressionPage(tester);
    expect(fixture.controller.busy, isTrue);
    final session = fixture.controller.workspace.directory;
    await tester.pageBack();
    await flushCompressionPage(tester);
    await tester.pumpAndSettle();
    expect(find.byType(CompressionTestPage), findsNothing);
    expect(fixture.engine.cancelled, isTrue);
    expect(session.existsSync(), isFalse);
    expect(fixture.source.existsSync(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selecting a previous result previews its file at the same position',
    (tester) async {
      final fixture = await mountCompressionPage(tester);
      await selectCompressionEpisode(tester);
      await tester.ensureVisible(find.text('清晰优先'));
      await tester.tap(find.text('清晰优先'));
      await flushCompressionPage(tester);
      final first = fixture.controller.result!;
      fixture.engine.outputBytes = 30;
      await tester.ensureVisible(find.text('清晰优先'));
      await tester.tap(find.text('清晰优先'));
      await flushCompressionPage(tester);
      await tester.ensureVisible(find.text('预览压缩视频'));
      await tester.tap(find.text('预览压缩视频'));
      await flushCompressionPage(tester);
      final player = tester.widget<AppVideoPlayer>(find.byType(AppVideoPlayer));
      await player.controller!.seekTo(const Duration(seconds: 10));
      final chip = find.byWidgetPredicate(
        (widget) =>
            widget is ChoiceChip &&
            (widget.label as Text).data!.startsWith('1.'),
      );
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await flushCompressionPage(tester);
      expect(fixture.controller.result, same(first));
      final preview = tester.widget<AppVideoPlayer>(
        find.byType(AppVideoPlayer),
      );
      expect(preview.controller!.dataSource, contains(first.path));
      expect(preview.controller!.value.position, const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow screens display selectors without overflow', (
    tester,
  ) async {
    await mountCompressionPage(tester);
    tester.view.physicalSize = const Size(320, 900);
    await tester.pump();
    expect(find.text('选择剧名'), findsOneWidget);
    expect(find.text('选择集数'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
