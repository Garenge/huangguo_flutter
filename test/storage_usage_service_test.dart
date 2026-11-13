import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/storage_usage_service.dart';

import 'helpers/download_page_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final flat in [false, true]) {
    test(
      'native statistics and per-episode file sizes with flat=$flat',
      () async {
        final root = Directory.systemTemp.createTempSync('storage_usage');
        final api = TestAlbumApi();
        final tasks = albumTasks('A', 2);
        final downloads = TestDownloadService(api, tasks);
        addTearDown(() {
          downloads.dispose();
          api.dispose();
          root.deleteSync(recursive: true);
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(StorageUsageService.channel, null);
        });
        for (var index = 0; index < tasks.length; index++) {
          final path = flat
              ? '${root.path}/album/video-$index.mp4'
              : '${root.path}/album/ep$index/video.mp4';
          File(path).parent.createSync(recursive: true);
          File(path).writeAsBytesSync(List.filled(100, 1));
          tasks[index].filePath = path;
          tasks[index].mp4Path = flat ? null : path;
        }
        File('${root.path}/cache').writeAsBytesSync(List.filled(50, 1));
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              StorageUsageService.channel,
              (MethodCall call) async => {
                'totalBytes': 1000,
                'availableBytes': 600,
                'includesApplication': true,
                'appRoots': [root.path],
              },
            );
        final service = StorageUsageService();
        final usage = await service.read(downloads);
        expect(usage.appBytes, 250);
        expect(usage.usedBytes, 400);
        expect(usage.albumBytes['测试剧A (A)'], 200);
        expect(usage.taskBytes, {'A-0': 100, 'A-1': 100});
        expect(usage.includesApplication, isTrue);
        final downloadUsage = await service.readDownloadUsage(downloads);
        expect(downloadUsage.appBytes, isNull);
        expect(downloadUsage.usedBytes, 400);
        expect(downloadUsage.albumBytes['测试剧A (A)'], 200);
        expect(downloadUsage.taskBytes, {'A-0': 100, 'A-1': 100});
        File(tasks.first.filePath!).deleteSync();
        final updated = await service.read(downloads);
        expect(updated.albumBytes['测试剧A (A)'], 100);
        expect(updated.appBytes, 150);
        expect(updated.taskBytes, {'A-0': 0, 'A-1': 100});
      },
    );
  }
}
