import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'helpers/local_download_player_fixture.dart';
import 'helpers/online_local_playback_fixture.dart';

void main() {
  testWidgets('downloaded MP4 skips stream resolution and restores progress', (
    tester,
  ) async {
    final fixture = OnlineLocalFixture()..addTask();
    await fixture.mount(tester);

    expect(fixture.api.requests, isEmpty);
    expect(fixture.platform.sources.single.sourceType, DataSourceType.file);
    expect(find.text('本地播放'), findsOneWidget);
    expect(localPlayer(tester).controller!.value.position.inSeconds, 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local HLS uses loopback without requesting remote stream', (
    tester,
  ) async {
    final fixture = OnlineLocalFixture()..addTask(name: 'playlist.m3u8');
    await fixture.mount(tester);

    expect(fixture.api.requests, isEmpty);
    final source = fixture.platform.sources.single;
    expect(source.sourceType, DataSourceType.network);
    expect(Uri.parse(source.uri!).host, '127.0.0.1');
    expect(find.text('本地播放'), findsOneWidget);
  });

  for (final status in [
    DownloadStatus.pending,
    DownloadStatus.downloading,
    DownloadStatus.paused,
  ]) {
    testWidgets('unfinished $status resource stays online', (tester) async {
      final fixture = OnlineLocalFixture()..addTask(status: status);
      await fixture.mount(tester);

      expect(fixture.api.requests, ['11969:1']);
      expect(find.text('在线播放'), findsOneWidget);
    });
  }

  testWidgets('missing download falls back to online with CDN headers', (
    tester,
  ) async {
    final fixture = OnlineLocalFixture();
    final task = fixture.addTask();
    File(task.filePath!).deleteSync();
    await fixture.mount(tester);

    expect(fixture.api.requests, ['11969:1']);
    expect(fixture.platform.sources.single.httpHeaders['x-cdn-auth'], 'signed');
    expect(find.text('在线播放'), findsOneWidget);
  });

  testWidgets('other drama downloads cannot replace the current episode', (
    tester,
  ) async {
    final fixture = OnlineLocalFixture()..addTask(dramaId: 'another');
    await fixture.mount(tester);

    expect(fixture.api.requests, ['11969:1']);
    expect(find.text('在线播放'), findsOneWidget);
  });

  testWidgets('local initialization failure waits for explicit online action', (
    tester,
  ) async {
    final fixture = OnlineLocalFixture()..addTask();
    fixture.platform.failLocal = true;
    await fixture.mount(tester);

    expect(fixture.api.requests, isEmpty);
    expect(localPlayer(tester).error, contains('模拟本地解码失败'));
    await tester.tap(find.text('改用在线播放（将消耗流量）'));
    await pumpLocalPlayer(tester);

    expect(fixture.api.requests, ['11969:1']);
    expect(find.text('在线播放'), findsOneWidget);
    expect(localPlayer(tester).controller!.value.position.inSeconds, 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('autoplay checks each episode and previous returns to local', (
    tester,
  ) async {
    final fixture = OnlineLocalFixture()..addTask();
    await fixture.mount(tester);
    final first = localPlayer(tester).controller!;
    await first.pause();
    first.value = first.value.copyWith(position: first.value.duration);
    await pumpLocalPlayer(tester);

    expect(fixture.api.requests, ['11969:2']);
    expect(localPlayer(tester).title, '第2集');
    expect(find.text('在线播放'), findsOneWidget);
    localPlayer(tester).onPrevious!();
    await pumpLocalPlayer(tester);

    expect(fixture.api.requests, ['11969:2']);
    expect(localPlayer(tester).title, '第1集');
    expect(find.text('本地播放'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'runtime local failure exposes online action and keeps position',
    (tester) async {
      final fixture = OnlineLocalFixture()..addTask();
      await fixture.mount(tester);
      final controller = localPlayer(tester).controller!;
      await controller.pause();
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 70),
        errorDescription: '本地文件读取失败',
      );
      await tester.pump();

      expect(fixture.api.requests, isEmpty);
      await tester.tap(find.text('改用在线播放（将消耗流量）'));
      await pumpLocalPlayer(tester);

      expect(fixture.api.requests, ['11969:1']);
      expect(localPlayer(tester).controller!.value.position.inSeconds, 70);
    },
  );
}
