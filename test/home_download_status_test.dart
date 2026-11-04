import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';

import 'helpers/home_pagination_fixture.dart';
import 'helpers/library_fixture.dart';

void main() {
  testWidgets('home check mark updates on completion and resource removal', (
    tester,
  ) async {
    final library = await memoryLibrary();
    final directory = Directory.systemTemp.createTempSync('home_status_test_');
    final file = File('${directory.path}/episode.mp4')..writeAsBytesSync([0]);
    addTearDown(() {
      library.dispose();
      directory.deleteSync(recursive: true);
    });
    late LibraryDownloads downloads;
    await mountPaginationHome(
      tester,
      library: library,
      createDownloads: (api) => downloads = LibraryDownloads(api),
    );
    final task = DownloadTask(
      id: 'task',
      dramaId: '1001',
      dramaName: 'home:latest:1',
      episodeName: '第1集',
      episodeUrl: '/video/1001/',
      ep: '1',
      filePath: file.path,
      status: DownloadStatus.downloading,
    );
    downloads.items.add(task);
    downloads.changed();
    await tester.pump();
    expect(find.text('有下载'), findsNothing);
    task.status = DownloadStatus.completed;
    downloads.changed();
    await tester.pump();
    expect(find.text('有下载'), findsOneWidget);
    file.deleteSync();
    downloads.changed();
    await tester.pump();
    expect(find.text('有下载'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
