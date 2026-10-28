import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/widgets/app_video_player.dart';
import 'package:huangguo_flutter/widgets/local_download_player.dart';
// Restore the native platform after each isolated player test.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'local_video_platform.dart';

Future<void> mountLocalDownloads(WidgetTester tester) async {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (_) async => null,
  );
  final previousPlatform = VideoPlayerPlatform.instance;
  VideoPlayerPlatform.instance = LocalVideoPlatform();
  final directory = await tester.runAsync(
    () => Directory.systemTemp.createTemp('local_download_player_test_'),
  );
  final path = '${directory!.path}/episode.mp4';
  File(path).writeAsBytesSync([0]);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    VideoPlayerPlatform.instance = previousPlatform;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    await tester.runAsync(() => directory.delete(recursive: true));
  });
  final tasks = List.generate(40, (index) => _localTask(index, path));
  await tester.pumpWidget(
    MaterialApp(
      home: LocalDownloadPlayer(tasks: tasks, initialTask: tasks.first),
    ),
  );
  await pumpLocalPlayer(tester);
}

Future<void> pumpLocalPlayer(WidgetTester tester) async {
  // Native controller teardown may complete outside Flutter's fake clock.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  // Playing controllers update every 100 ms, so frames never fully settle.
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

DownloadTask _localTask(int index, String path) => DownloadTask(
  id: 'task-$index',
  dramaId: 'local-drama',
  dramaName: '本地测试剧',
  episodeName: '本地第${index + 1}集',
  episodeUrl: '/episode/$index',
  ep: '${index + 1}',
  filePath: path,
  status: DownloadStatus.completed,
);

AppVideoPlayer localPlayer(WidgetTester tester) =>
    tester.widget<AppVideoPlayer>(find.byType(AppVideoPlayer));

Finder localEpisode(String name) => find.descendant(
  of: find.byType(ListView),
  matching: find.widgetWithText(ListTile, name),
);
