import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/models/episode.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'helpers/online_local_playback_fixture.dart';

void main() {
  for (final extension in ['mp4', 'm3u8']) {
    testWidgets('missing drama ID finds local $extension by playback URL', (
      tester,
    ) async {
      final fixture = OnlineLocalFixture()
        ..addTask(name: 'playlist.$extension');
      await fixture.mount(tester, dramaId: null);

      expect(fixture.api.requests, isEmpty);
      expect(find.text('本地播放'), findsOneWidget);
      expect(
        fixture.platform.sources.single.sourceType,
        extension == 'mp4' ? DataSourceType.file : DataSourceType.network,
      );
    });

    testWidgets('untracked $extension is found by ID and episode directory', (
      tester,
    ) async {
      final fixture = OnlineLocalFixture();
      final file = File(
        '${fixture.directory.path}/旧剧名 (11969)/第01集/playlist.$extension',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('#EXTM3U');
      await fixture.mount(tester, dramaId: null);

      expect(fixture.downloads.items, isEmpty);
      expect(fixture.api.requests, isEmpty);
      expect(find.text('本地播放'), findsOneWidget);
    });
  }

  testWidgets('legacy play URL matches completed download without drama ID', (
    tester,
  ) async {
    final fixture = OnlineLocalFixture()..addTask(name: 'playlist.m3u8');
    await fixture.mount(
      tester,
      dramaId: null,
      episode: const Episode(
        name: '第1集',
        url: 'https://huangguoai.com/play/11969/1/',
        ep: '1',
      ),
    );
    expect(fixture.api.requests, isEmpty);
    expect(find.text('本地播放'), findsOneWidget);
  });

  testWidgets('task episode numbers with leading zeros match current episode', (
    tester,
  ) async {
    final fixture = OnlineLocalFixture()..addTask(ep: '01');
    await fixture.mount(tester);

    expect(fixture.api.requests, isEmpty);
    expect(find.text('本地播放'), findsOneWidget);
  });

  testWidgets('exact nonstandard episode URL matches task without drama ID', (
    tester,
  ) async {
    final fixture = OnlineLocalFixture();
    fixture.downloads.items.add(
      DownloadTask(
        id: 'custom',
        dramaId: 'custom',
        dramaName: '自定义剧',
        episodeName: '第1集',
        episodeUrl: '/watch?id=123',
        ep: '1',
        status: DownloadStatus.completed,
        filePath: (File(
          '${fixture.directory.path}/episode.mp4',
        )..writeAsBytesSync([0])).path,
      ),
    );
    await fixture.mount(
      tester,
      dramaId: null,
      episode: const Episode(name: '第1集', url: '/watch/?id=123', ep: '1'),
    );

    expect(fixture.api.requests, isEmpty);
    expect(find.text('本地播放'), findsOneWidget);
  });

  testWidgets('directory fallback does not play another drama or episode', (
    tester,
  ) async {
    final fixture = OnlineLocalFixture();
    for (final folder in ['同名剧 (11970)/第1集', '同名剧 (11969)/第2集']) {
      final file = File('${fixture.directory.path}/$folder/episode.mp4');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync([0]);
    }
    await fixture.mount(tester);

    expect(fixture.api.requests, ['11969:1']);
    expect(find.text('在线播放'), findsOneWidget);
  });

  testWidgets('directory fallback cannot bypass an unfinished task', (
    tester,
  ) async {
    final fixture = OnlineLocalFixture()
      ..addTask(status: DownloadStatus.downloading);
    final file = File(
      '${fixture.directory.path}/本地优先测试剧 (11969)/第1集/episode.mp4',
    );
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync([0]);
    await fixture.mount(tester, dramaId: null);

    expect(fixture.api.requests, ['11969:1']);
    expect(find.text('在线播放'), findsOneWidget);
  });
}
