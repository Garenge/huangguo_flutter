import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/storage_usage.dart';
import 'package:huangguo_flutter/services/download_service.dart';
import 'package:huangguo_flutter/services/storage_usage_service.dart';
import 'package:huangguo_flutter/widgets/download_storage_panel.dart';

import 'helpers/download_page_fixture.dart';

class _StorageService extends StorageUsageService {
  int reads = 0;

  @override
  Future<StorageUsage> read(DownloadService downloads) async {
    reads++;
    return StorageUsage(
      totalBytes: 256 * 1024 * 1024 * 1024,
      availableBytes: 64 * 1024 * 1024 * 1024,
      appBytes: 4 * 1024 * 1024 * 1024,
      includesApplication: true,
      albumBytes: {
        for (final task in downloads.completedTasks)
          '${task.dramaName} (${task.dramaId})': 2 * 1024 * 1024 * 1024,
      },
    );
  }
}

void main() {
  testWidgets(
    'storage remains fixed while scrolling and when search is empty',
    (tester) async {
      await mountDownloads(tester, storageUsageService: _StorageService());
      final panel = find.byType(DownloadStoragePanel);
      final top = tester.getTopLeft(panel);
      expect(find.text('256.00 GB'), findsOneWidget);
      expect(find.text('192.00 GB'), findsOneWidget);
      expect(find.text('4.00 GB'), findsOneWidget);
      await jumpDownloads(tester, 400);
      expect(tester.getTopLeft(panel), top);
      await tester.enterText(find.byType(TextField), '不存在');
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的已下载资源'), findsOneWidget);
      expect(tester.getTopLeft(panel), top);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'album size uses whole album even when searching a single episode',
    (tester) async {
      await mountDownloads(tester, storageUsageService: _StorageService());
      await tester.enterText(find.byType(TextField), 'A 第1集');
      await tester.pumpAndSettle();
      expect(find.text('找到 1 / 75 集'), findsOneWidget);
      await tester.tap(find.byTooltip('更多').first);
      await tester.pumpAndSettle();
      expect(find.text('本套占用：2.00 GB'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('refreshes after deletion and on foreground resume', (
    tester,
  ) async {
    final storage = _StorageService();
    final downloads = await mountDownloads(
      tester,
      storageUsageService: storage,
    );
    final initial = storage.reads;
    downloads.removeAlbum('A');
    downloads.removeAlbum('B');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(storage.reads, initial + 1);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(storage.reads, initial + 2);
    await tester.tap(find.byTooltip('刷新空间统计'));
    await tester.pumpAndSettle();
    expect(storage.reads, initial + 3);
  });

  testWidgets(
    'empty downloads and narrow screen retain readable storage panel',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mountDownloads(
        tester,
        tasks: [],
        storageUsageService: _StorageService(),
      );
      expect(find.text('暂无已完成下载'), findsOneWidget);
      expect(find.text('存储管理'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
