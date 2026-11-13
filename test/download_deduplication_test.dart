import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';

import 'helpers/download_deduplication_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DownloadDeduplicationFixture fixture;
  setUp(() async => fixture = await DownloadDeduplicationFixture.create());
  tearDown(() => fixture.dispose());

  test('single and batch requests skip paused tasks', () async {
    await fixture.seed(DownloadStatus.paused);
    expect(await fixture.service.addTask(dedupDrama, dedupEpisode), isNull);
    final result = await fixture.service.addTasks(dedupDrama, [dedupEpisode]);
    expect(result.addedCount, 0);
    expect(result.skippedCount, 1);
    expect(fixture.service.tasks.single.status, DownloadStatus.paused);
    expect(
      fixture.service.isResourceDownloaded(dedupDrama, dedupEpisode),
      isFalse,
    );
  });

  for (final name in ['playlist.m3u8', 'episode.mp4']) {
    test(
      'single and batch requests skip local $name without metadata',
      () async {
        final resource = await fixture.resource(name);
        expect(await fixture.service.addTask(dedupDrama, dedupEpisode), isNull);
        final result = await fixture.service.addTasks(dedupDrama, [
          dedupEpisode,
          dedupEpisode,
        ]);
        expect(result.addedCount, 0);
        expect(result.skippedCount, 2);
        expect(fixture.service.tasks, isEmpty);
        final path = name.endsWith('.mp4')
            ? '${fixture.root}/测试剧/测试剧-1.mp4'
            : resource.path;
        expect(await File(path).readAsString(), 'test resource');
        expect(
          fixture.service.isResourceDownloaded(dedupDrama, dedupEpisode),
          isTrue,
        );
      },
    );
  }

  test(
    'completed MP4 survives restart after source playlist removal',
    () async {
      final mp4 = await fixture.resource('episode.mp4');
      await fixture.seed(
        DownloadStatus.completed,
        filePath: '${fixture.episodeDirectory}/playlist.m3u8',
        mp4Path: mp4.path,
      );
      expect(fixture.service.tasks.single.status, DownloadStatus.completed);
      expect(fixture.service.isEpisodeDownloaded('1', '1'), isTrue);
      expect(await fixture.service.addTask(dedupDrama, dedupEpisode), isNull);
      expect(fixture.service.tasks, hasLength(1));
    },
  );

  test(
    'failed record with retained MP4 does not create another task',
    () async {
      final mp4 = await fixture.resource('episode.mp4');
      await fixture.seed(DownloadStatus.failed, mp4Path: mp4.path);
      expect(await fixture.service.addTask(dedupDrama, dedupEpisode), isNull);
      final result = await fixture.service.addTasks(dedupDrama, [dedupEpisode]);
      expect(result.skippedCount, 1);
      expect(fixture.service.tasks, hasLength(1));
      expect(fixture.service.isEpisodeDownloaded('1', '1'), isTrue);
    },
  );

  test('residual TS segments alone do not count as downloaded', () async {
    await fixture.resource('segment_0.ts');
    await fixture.seed(DownloadStatus.failed);
    expect(
      fixture.service.isResourceDownloaded(dedupDrama, dedupEpisode),
      isFalse,
    );
    expect(fixture.service.isEpisodeDownloaded('1', '1'), isFalse);
  });

  test('single download retries the existing failed task', () async {
    await fixture.seed(DownloadStatus.failed);
    final original = fixture.service.tasks.single;
    original.errorMessage = 'previous failure';
    original.progress = 0.5;
    original.downloadedBytes = 100;
    final task = await fixture.service.addTask(dedupDrama, dedupEpisode);
    expect(task, same(original));
    expect(fixture.service.tasks, hasLength(1));
    expect(task!.id, 'existing');
    expect(task.progress, 0);
    expect(task.downloadedBytes, 0);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });

  test('batch retries one failed task and skips repeated episode', () async {
    await fixture.seed(DownloadStatus.failed);
    final original = fixture.service.tasks.single;
    final result = await fixture.service.addTasks(dedupDrama, [
      dedupEpisode,
      dedupEpisode,
    ]);
    expect(result.addedCount, 0);
    expect(result.retriedCount, 1);
    expect(result.skippedCount, 1);
    expect(fixture.service.tasks.single, same(original));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
}
