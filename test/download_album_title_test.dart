import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/services/download_layout.dart';

import 'helpers/download_page_fixture.dart';

DownloadTask _task(String id, {String name = '示例剧'}) => DownloadTask.fromJson({
  ...albumTasks(id, 1).single.toJson(),
  'dramaName': name,
});

void main() {
  late Directory root;
  late DownloadLayout layout;
  setUp(() {
    root = Directory.systemTemp.createTempSync('download_album_title_');
    layout = DownloadLayout(root.path);
  });
  tearDown(() => root.deleteSync(recursive: true));

  testWidgets('album title matches directory name without internal ID', (
    tester,
  ) async {
    final task = _task('2833');
    await layout.prepareAlbum(task);
    await mountDownloads(tester, tasks: [task], downloadRoot: root.path);
    expect(find.text('示例剧'), findsOneWidget);
    expect(find.text('示例剧 (2833)'), findsNothing);
    expect(
      layout.albumName(task),
      Directory(
        layout.albumDirectory(task),
      ).uri.pathSegments.where((part) => part.isNotEmpty).last,
    );
  });

  testWidgets(
    'same-name dramas show their directories and collapse independently',
    (tester) async {
      final first = _task('2833');
      final second = _task('9000');
      await layout.prepareAlbum(first);
      await layout.prepareAlbum(second);
      await mountDownloads(
        tester,
        tasks: [first, second],
        downloadRoot: root.path,
      );
      expect(find.text('示例剧'), findsOneWidget);
      expect(find.text('示例剧 (9000)'), findsOneWidget);
      await tester.tap(find.text('示例剧'));
      await tester.pumpAndSettle();
      expect(find.text('2833 第1集'), findsNothing);
      expect(find.text('9000 第1集'), findsOneWidget);
      await tester.tap(find.text('示例剧 (9000)'));
      await tester.pumpAndSettle();
      expect(find.text('9000 第1集'), findsNothing);
      expect(find.text('全部展开'), findsOneWidget);
    },
  );

  test(
    'title follows the owned directory even after a directory rename',
    () async {
      final task = _task('2833');
      await layout.prepareAlbum(task);
      Directory(layout.albumDirectory(task)).renameSync('${root.path}/整理后的剧名');
      expect(layout.albumName(task), '整理后的剧名');
    },
  );
}
