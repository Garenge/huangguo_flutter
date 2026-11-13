import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/services/download_service.dart';
import 'package:huangguo_flutter/services/local_playback_source.dart';
import 'package:huangguo_flutter/services/storage_usage_service.dart';
import 'package:huangguo_flutter/services/video_conversion_service.dart';

import 'helpers/download_deduplication_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DownloadDeduplicationFixture fixture;
  setUp(() async => fixture = await DownloadDeduplicationFixture.create());
  tearDown(() => fixture.dispose());

  test(
    'startup migrates files, persists relative paths and survives restart',
    () async {
      final old = await fixture.resource('episode.mp4');
      final playlist = await fixture.resource('playlist.m3u8');
      await fixture.seed(
        DownloadStatus.completed,
        filePath: playlist.path,
        mp4Path: old.path,
      );
      final task = fixture.service.tasks.single;
      final target = '${fixture.root}/测试剧/测试剧-1.mp4';
      expect(task.mp4Path, target);
      expect(old.existsSync(), isFalse);
      expect(task.status, DownloadStatus.completed);
      expect(
        fixture.service.isResourceDownloaded(dedupDrama, dedupEpisode),
        isTrue,
      );
      expect(
        LocalPlaybackSource.forEpisode(fixture.service, '1', '1')?.path,
        target,
      );
      expect(
        VideoConversionService(fixture.service).expectedMp4Path(task),
        target,
      );
      final records =
          jsonDecode(
                File('${fixture.root}/.download_tasks.json').readAsStringSync(),
              )
              as List;
      expect(records.single['mp4Path'], '测试剧/测试剧-1.mp4');
      expect(records.single['filePath'], '.sources/1/1/playlist.m3u8');
      final restarted = DownloadService(fixture.api);
      addTearDown(restarted.dispose);
      await restarted.init();
      expect(restarted.tasks.single.mp4Path, target);
      expect(restarted.tasks.single.status, DownloadStatus.completed);
      final usage = await StorageUsageService().readDownloadUsage(restarted);
      expect(usage.taskBytes[task.id], 'test resource'.length * 2);
      await restarted.deleteCompletedFile(task.id);
      expect(File(target).existsSync(), isFalse);
    },
  );

  test(
    'startup finds an unrecorded legacy MP4 and keeps download deduplication',
    () async {
      await fixture.resource('episode.mp4');
      await fixture.service.init();
      expect(fixture.service.tasks, isEmpty);
      expect(
        fixture.service.isResourceDownloaded(dedupDrama, dedupEpisode),
        isTrue,
      );
      expect(
        LocalPlaybackSource.forEpisode(fixture.service, '1', '1')?.path,
        '${fixture.root}/测试剧/测试剧-1.mp4',
      );
      expect(await fixture.service.addTask(dedupDrama, dedupEpisode), isNull);
    },
  );

  test(
    'MP4-only task remains playable and its source cleanup preserves MP4',
    () async {
      final old = await fixture.resource('episode.mp4');
      await fixture.seed(DownloadStatus.completed, filePath: old.path);
      final task = fixture.service.tasks.single;
      expect(task.filePath, '${fixture.root}/测试剧/测试剧-1.mp4');
      expect(await fixture.service.deleteSourceFiles(task.id), isTrue);
      expect(File(task.mp4Path!).existsSync(), isTrue);
      expect(LocalPlaybackSource.forTask(task)?.path, task.mp4Path);
      await fixture.service.deleteTask(task.id);
      expect(File(task.mp4Path!).existsSync(), isFalse);
    },
  );

  test(
    'a damaged task file is retained without moving existing videos',
    () async {
      final video = await fixture.resource('episode.mp4');
      final metadata = File('${fixture.root}/.download_tasks.json');
      await metadata.writeAsString('{broken');
      await fixture.service.init();
      expect(metadata.readAsStringSync(), '{broken');
      expect(video.existsSync(), isTrue);
    },
  );
}
