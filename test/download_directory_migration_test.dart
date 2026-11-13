import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/services/download_directory_migration.dart';
import 'package:huangguo_flutter/services/download_layout.dart';
import 'package:huangguo_flutter/services/download_resource_deletion.dart';
import 'package:huangguo_flutter/services/local_playback_source.dart';

DownloadTask _task({String id = '8675', String ep = '9'}) => DownloadTask(
  id: '$id-$ep',
  dramaId: id,
  dramaName: '测试剧',
  episodeName: '第$ep集',
  episodeUrl: '/play/$id/$ep/',
  ep: ep,
  status: DownloadStatus.completed,
);

File _write(String path, String content) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  return file..writeAsStringSync(content);
}

void main() {
  late Directory root;
  late DownloadLayout layout;
  setUp(() {
    root = Directory.systemTemp.createTempSync('download_layout_');
    layout = DownloadLayout(root.path);
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<void> migrate(List<DownloadTask> tasks) =>
      DownloadDirectoryMigration(layout, tasks, () async {}).run();

  test('MP4 uses drama name and numeric episode; sources stay isolated', () {
    final task = _task(ep: '09');
    expect(layout.mp4Path(task), '${root.path}/测试剧/测试剧-9.mp4');
    expect(layout.sourceDirectory(task), '${root.path}/.sources/8675/9');
  });

  test(
    'migration moves MP4 and HLS, updates paths and is repeatable',
    () async {
      final task = _task();
      final legacy = layout.legacyDirectory(task);
      task.filePath = _write('$legacy/playlist.m3u8', '#EXTM3U').path;
      task.mp4Path = _write('$legacy/第9集.mp4', 'video').path;
      _write('$legacy/00000.ts', 'segment');
      _write('$legacy/key_0.bin', 'key');
      await migrate([task]);
      expect(task.mp4Path, layout.mp4Path(task));
      expect(File(task.mp4Path!).readAsStringSync(), 'video');
      expect(task.filePath, '${layout.sourceDirectory(task)}/playlist.m3u8');
      expect(
        File('${layout.sourceDirectory(task)}/00000.ts').existsSync(),
        isTrue,
      );
      expect(Directory(legacy).existsSync(), isFalse);
      final modified = File(task.mp4Path!).lastModifiedSync();
      await migrate([task]);
      expect(File(task.mp4Path!).lastModifiedSync(), modified);
      expect(File(task.filePath!).readAsStringSync(), '#EXTM3U');
    },
  );

  test('MP4 stored as filePath is repaired after a restart', () async {
    final task = _task();
    task.filePath = '${layout.legacyDirectory(task)}/第9集.mp4';
    _write(layout.mp4Path(task), 'moved before metadata was saved');
    await migrate([task]);
    expect(task.mp4Path, layout.mp4Path(task));
    expect(
      File(task.mp4Path!).readAsStringSync(),
      'moved before metadata was saved',
    );
    expect(task.filePath, layout.mp4Path(task));
  });

  test(
    'source move interrupted before save recovers from new directory',
    () async {
      final task = _task();
      task.filePath = '${layout.legacyDirectory(task)}/playlist.m3u8';
      final playlist = '${layout.sourceDirectory(task)}/playlist.m3u8';
      _write(playlist, '#EXTM3U');
      await migrate([task]);
      expect(task.filePath, playlist);
    },
  );

  test('target collision preserves both files and recorded paths', () async {
    final task = _task();
    final old = _write('${layout.legacyDirectory(task)}/第9集.mp4', 'old');
    task.mp4Path = old.path;
    final target = _write(layout.mp4Path(task), 'existing');
    await migrate([task]);
    expect(old.readAsStringSync(), 'old');
    expect(target.readAsStringSync(), 'existing');
    expect(task.mp4Path, old.path);
  });

  test('same-name dramas receive separate owned directories', () async {
    final first = _task();
    final second = _task(id: '10000');
    first.mp4Path = _write(
      '${layout.legacyDirectory(first)}/第9集.mp4',
      'first',
    ).path;
    second.mp4Path = _write(
      '${layout.legacyDirectory(second)}/第9集.mp4',
      'second',
    ).path;
    await migrate([first, second]);
    expect(File(first.mp4Path!).parent.path, '${root.path}/测试剧');
    expect(File(second.mp4Path!).parent.path, '${root.path}/测试剧 (10000)');
    expect(layout.mp4Candidates(first.dramaId, '9').single, first.mp4Path);
    expect(layout.mp4Candidates(second.dramaId, '9').single, second.mp4Path);
  });

  test(
    'legacy MP4 without metadata is moved and remains discoverable',
    () async {
      final task = _task();
      final old = _write('${layout.legacyDirectory(task)}/第9集.mp4', 'orphan');
      _write('${layout.legacyDirectory(task)}/playlist.m3u8', '#EXTM3U');
      await migrate([]);
      expect(old.existsSync(), isFalse);
      expect(
        File(
          layout.mp4Candidates(task.dramaId, task.ep).single,
        ).readAsStringSync(),
        'orphan',
      );
      await migrate([]);
      expect(layout.mp4Candidates(task.dramaId, task.ep), hasLength(1));
      expect(
        File('${layout.sourceDirectory(task)}/playlist.m3u8').existsSync(),
        isTrue,
      );
    },
  );

  test(
    'deleting one episode leaves its siblings and their sources intact',
    () async {
      final first = _task();
      final second = _task(ep: '10');
      for (final task in [first, second]) {
        task.mp4Path = _write(
          '${layout.legacyDirectory(task)}/${task.episodeName}.mp4',
          task.ep,
        ).path;
        task.filePath = _write(
          '${layout.legacyDirectory(task)}/playlist.m3u8',
          '#EXTM3U',
        ).path;
      }
      await migrate([first, second]);
      final deletion = DownloadResourceDeletion(layout);
      await deletion.delete(first);
      expect(File(first.mp4Path!).existsSync(), isFalse);
      expect(Directory(layout.sourceDirectory(first)).existsSync(), isFalse);
      expect(File(second.mp4Path!).readAsStringSync(), '10');
      expect(File(second.filePath!).existsSync(), isTrue);
      await deletion.delete(second);
      expect(Directory('${root.path}/测试剧').existsSync(), isFalse);
    },
  );

  test(
    'missing MP4 does not fall back to another episode in shared album',
    () async {
      final missing = _task();
      await layout.prepareAlbum(missing);
      missing.mp4Path = layout.mp4Path(missing);
      missing.filePath = missing.mp4Path;
      _write(layout.mp4Path(_task(ep: '10')), 'sibling');
      expect(LocalPlaybackSource.forTask(missing), isNull);
    },
  );

  test(
    'concurrent conversion reserves separate directories for same-name dramas',
    () async {
      final first = _task();
      final second = _task(id: '10000');
      await Future.wait([
        layout.prepareAlbum(first),
        layout.prepareAlbum(second),
      ]);
      expect(
        layout.albumDirectory(first),
        isNot(layout.albumDirectory(second)),
      );
      expect(layout.albumOwner(layout.albumDirectory(first)), first.dramaId);
      expect(layout.albumOwner(layout.albumDirectory(second)), second.dramaId);
    },
  );

  test('one failed migration does not block other episodes', () async {
    final blocked = _task();
    final next = _task(ep: '10');
    for (final task in [blocked, next]) {
      task.mp4Path = _write(
        '${layout.legacyDirectory(task)}/video.mp4',
        task.ep,
      ).path;
    }
    Directory(layout.mp4Path(blocked)).createSync(recursive: true);
    final blockedPath = blocked.mp4Path!;
    await migrate([blocked, next]);
    expect(File(blockedPath).readAsStringSync(), '9');
    expect(File(next.mp4Path!).readAsStringSync(), '10');
    expect(next.mp4Path, layout.mp4Path(next));
  });
}
