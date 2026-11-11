import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/services/local_playback_source.dart';
import 'package:video_player/video_player.dart';

void main() {
  late Directory directory;
  late DownloadTask task;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('local_source_');
    task = DownloadTask(
      id: 'task',
      dramaId: 'drama',
      dramaName: '测试剧',
      episodeName: '第1集',
      episodeUrl: '/play/drama/1/',
      ep: '1',
      filePath: '${directory.path}/playlist.m3u8',
      status: DownloadStatus.completed,
    );
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('prefers existing exported MP4 over the downloaded playlist', () {
    File(task.filePath!).writeAsStringSync('#EXTM3U');
    task.mp4Path = '${directory.path}/exported.mp4';
    File(task.mp4Path!).writeAsBytesSync([0]);

    expect(LocalPlaybackSource.forTask(task)?.path, task.mp4Path);
  });

  test('discovers MP4 retained after the source playlist was deleted', () {
    final mp4 = File('${directory.path}/episode.mp4')..writeAsBytesSync([0]);

    expect(LocalPlaybackSource.forTask(task)?.path, mp4.path);
  });

  test('missing exported MP4 falls back to the existing local playlist', () {
    File(task.filePath!).writeAsStringSync('#EXTM3U');
    task.mp4Path = '${directory.path}/missing.mp4';

    expect(LocalPlaybackSource.forTask(task)?.path, task.filePath);
  });

  test('residual TS fragments do not count as a playable source', () {
    File('${directory.path}/00000.ts').writeAsBytesSync([0]);

    expect(LocalPlaybackSource.forTask(task), isNull);
  });

  test(
    'independent HLS sources keep serving local segments and keys',
    () async {
      File(task.filePath!).writeAsStringSync(
        '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key_0.bin"\n'
        '#EXTINF:1,\n00000.ts\n#EXT-X-ENDLIST\n',
      );
      File('${directory.path}/00000.ts').writeAsStringSync('local segment');
      File('${directory.path}/key_0.bin').writeAsStringSync('local key');
      final first = LocalPlaybackSource.forTask(task)!;
      final second = LocalPlaybackSource.forTask(task)!;
      final client = HttpClient();
      try {
        final firstController = await first.createController();
        final secondController = await second.createController();
        expect(firstController.dataSourceType, DataSourceType.network);
        final firstUri = Uri.parse(firstController.dataSource);
        final secondUri = Uri.parse(secondController.dataSource);
        expect(firstUri.host, '127.0.0.1');
        expect(firstUri.port, isNot(secondUri.port));
        first.dispose();
        for (final name in ['playlist.m3u8', '00000.ts', 'key_0.bin']) {
          final request = await client.getUrl(secondUri.resolve(name));
          final response = await request.close();
          expect(response.statusCode, HttpStatus.ok);
          expect(
            await response.fold<int>(0, (size, bytes) => size + bytes.length),
            greaterThan(0),
          );
        }
      } finally {
        client.close(force: true);
        first.dispose();
        second.dispose();
      }
    },
  );
}
