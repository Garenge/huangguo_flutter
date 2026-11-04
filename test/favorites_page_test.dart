import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/pages/favorites_page.dart';
import 'package:huangguo_flutter/services/huangguo_api.dart';
import 'package:huangguo_flutter/widgets/library_scope.dart';

import 'helpers/library_fixture.dart';

void main() {
  testWidgets('favorites open detail and cancellation reveals empty state', (
    tester,
  ) async {
    final library = await memoryLibrary();
    final api = HuangguoApi();
    final downloads = LibraryDownloads(api);
    addTearDown(() {
      library.dispose();
      downloads.dispose();
      api.dispose();
    });
    await library.toggleFavorite(libraryDrama);
    var openedId = '';
    await tester.pumpWidget(
      LibraryScope(
        library: library,
        child: MaterialApp(
          home: FavoritesPage(
            downloadService: downloads,
            onOpenDetail: (drama) => openedId = drama.id,
          ),
        ),
      ),
    );
    await tester.tap(find.text(libraryDrama.name));
    expect(openedId, libraryDrama.id);
    await tester.tap(find.byTooltip('取消收藏'));
    await tester.pump();
    expect(find.text('还没有收藏，点击卡片上的星标即可收藏'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'check mark needs completed existing resources and updates on deletion',
    (tester) async {
      final library = await memoryLibrary();
      final api = HuangguoApi();
      final downloads = LibraryDownloads(api);
      final root = Directory.systemTemp.createTempSync(
        'library_download_test_',
      );
      final file = File('${root.path}/episode.mp4')..writeAsBytesSync([0]);
      addTearDown(() {
        library.dispose();
        downloads.dispose();
        api.dispose();
        root.deleteSync(recursive: true);
      });
      final task = DownloadTask(
        id: 'task',
        dramaId: libraryDrama.id,
        dramaName: libraryDrama.name,
        episodeName: '第1集',
        episodeUrl: '/ep/1',
        ep: '1',
        filePath: file.path,
        status: DownloadStatus.downloading,
      );
      downloads.items.add(task);
      await library.toggleFavorite(libraryDrama);
      await tester.pumpWidget(
        LibraryScope(
          library: library,
          child: MaterialApp(
            home: FavoritesPage(
              downloadService: downloads,
              onOpenDetail: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('有下载'), findsNothing);
      task.status = DownloadStatus.completed;
      downloads.changed();
      await tester.pump();
      expect(find.text('有下载'), findsOneWidget);
      file.deleteSync();
      downloads.changed();
      await tester.pump();
      expect(find.text('有下载'), findsNothing);
      expect(library.isFavorite(libraryDrama.id), isTrue);
    },
  );
}
