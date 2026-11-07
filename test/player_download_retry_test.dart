import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';

import 'helpers/player_download_fixture.dart';

void main() {
  testWidgets('failed add clears loading and allows another attempt', (
    tester,
  ) async {
    final service = await setupDownloadButton(tester);
    service.failAdd = true;
    await tester.tap(find.byTooltip('下载当前剧集'));
    await tester.pump();
    expect(find.byTooltip('下载当前剧集'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('加入下载失败，请重试'), findsOneWidget);
    service.failAdd = false;
    await tester.tap(find.byTooltip('下载当前剧集'));
    await tester.pump();
    expect(find.byTooltip('等待下载'), findsOneWidget);
    expect(service.adds, 2);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('paused and failed tasks resume without creating duplicates', (
    tester,
  ) async {
    final service = await setupDownloadButton(tester);
    await service.addTask(buttonDrama, buttonEpisode);
    for (final status in [DownloadStatus.paused, DownloadStatus.failed]) {
      service.items.single.status = status;
      service.changed();
      await tester.pump();
      final tooltip = status == DownloadStatus.paused
          ? '下载已暂停，点击继续'
          : '下载失败，点击重试';
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump();
      expect(find.byTooltip('等待下载'), findsOneWidget);
    }
    expect(service.resumes, 2);
    expect(service.adds, 1);
    await tester.pump(const Duration(seconds: 3));
  });
}
