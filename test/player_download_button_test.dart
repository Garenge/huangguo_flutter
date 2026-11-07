import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/models/episode.dart';

import 'helpers/player_download_fixture.dart';

void main() {
  testWidgets(
    'download updates from adding through progress to existing file',
    (tester) async {
      final service = await setupDownloadButton(tester);
      service.adding = Completer<void>();
      await tester.tap(find.byTooltip('下载当前剧集'));
      await tester.pump();
      expect(find.byTooltip('正在加入下载队列'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      expect(service.adds, 1);
      service.adding!.complete();
      await tester.pump();
      expect(find.byTooltip('等待下载'), findsOneWidget);
      final task = service.items.single;
      task.status = DownloadStatus.downloading;
      task.progress = 0.35;
      service.changed();
      await tester.pump();
      expect(find.byTooltip('下载中 35%'), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        0.35,
      );
      final file = completedButtonFile();
      task.status = DownloadStatus.completed;
      task.filePath = file.path;
      service.changed();
      await tester.pump();
      expect(find.byTooltip('当前剧集已下载'), findsOneWidget);
      expect(find.byIcon(Icons.download_done_rounded), findsOneWidget);
      file.deleteSync();
      service.changed();
      await tester.pump();
      expect(find.byTooltip('下载当前剧集'), findsOneWidget);
      expect(find.byIcon(Icons.download_done_rounded), findsNothing);
      await tester.tap(find.byTooltip('下载当前剧集'));
      await tester.pump();
      expect(service.resumes, 1);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('switching episodes isolates an outstanding add operation', (
    tester,
  ) async {
    final service = await setupDownloadButton(tester);
    service.adding = Completer<void>();
    await tester.tap(find.byTooltip('下载当前剧集'));
    await tester.pump();
    const next = Episode(name: '第2集', url: '/video/2', ep: '2');
    await mountDownloadButton(tester, service, episode: next);
    expect(find.byTooltip('下载当前剧集'), findsOneWidget);
    service.adding!.complete();
    await tester.pump();
    expect(find.byTooltip('下载当前剧集'), findsOneWidget);
    expect(find.text('已加入下载队列：第1集'), findsNothing);
    await mountDownloadButton(tester, service);
    expect(find.byTooltip('等待下载'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
