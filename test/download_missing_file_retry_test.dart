import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';

import 'helpers/download_deduplication_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'completed task can resume after its local resource disappears',
    () async {
      final fixture = await DownloadDeduplicationFixture.create();
      addTearDown(fixture.dispose);
      final file = await fixture.resource('episode.mp4');
      await fixture.seed(DownloadStatus.completed, filePath: file.path);
      final task = fixture.service.tasks.single;
      await File(task.filePath!).delete();
      final states = <DownloadStatus>[];
      fixture.service.addListener(() => states.add(task.status));
      await fixture.service.resumeTask(task.id);
      expect(states, contains(DownloadStatus.pending));
      expect(fixture.service.tasks.single, same(task));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    },
  );
}
