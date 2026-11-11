import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/local_playback_source.dart';

import 'helpers/online_local_playback_fixture.dart';

void main() {
  late OnlineLocalFixture fixture;

  setUp(() => fixture = OnlineLocalFixture());
  tearDown(() {
    fixture.downloads.dispose();
    fixture.settings.dispose();
    fixture.api.dispose();
    fixture.directory.deleteSync(recursive: true);
  });

  test('query parameters keep different videos from sharing a task match', () {
    fixture.addTask(episodeUrl: '/watch?id=123');

    expect(
      LocalPlaybackSource.forEpisode(
        fixture.downloads,
        null,
        '1',
        episodeUrl: '/watch?id=456',
      ),
      isNull,
    );
  });

  test('unknown external hosts cannot match a local ID by path alone', () {
    fixture.addTask();

    expect(
      LocalPlaybackSource.forEpisode(
        fixture.downloads,
        null,
        '1',
        episodeUrl: 'https://unrelated.example/video/11969/',
      ),
      isNull,
    );
  });

  test('explicit drama ID cannot be overridden by a different URL ID', () {
    fixture.addTask();

    expect(
      LocalPlaybackSource.forEpisode(
        fixture.downloads,
        'another',
        '1',
        episodeUrl: '/video/11969/',
      ),
      isNull,
    );
  });

  test(
    'stale task paths fall back to the directory with the same drama ID',
    () {
      final task = fixture.addTask(name: 'playlist.m3u8');
      File(task.filePath!).deleteSync();
      final file = File(
        '${fixture.directory.path}/重命名后的剧 (11969)/第1集/video.mp4',
      );
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync([0]);

      expect(
        LocalPlaybackSource.forEpisode(
          fixture.downloads,
          '11969',
          '1',
          episodeName: '第1集',
        )?.path,
        file.path,
      );
    },
  );

  test('only residual segments without a playlist stay unavailable', () {
    final file = File('${fixture.directory.path}/测试剧 (11969)/第1集/00000.ts');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync([0]);

    expect(
      LocalPlaybackSource.forEpisode(
        fixture.downloads,
        '11969',
        '1',
        episodeName: '第1集',
      ),
      isNull,
    );
  });
}
