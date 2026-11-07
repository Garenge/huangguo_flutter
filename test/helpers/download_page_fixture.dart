import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/pages/download_page.dart';
import 'package:huangguo_flutter/services/download_service.dart';
import 'package:huangguo_flutter/services/download_settings_service.dart';
import 'package:huangguo_flutter/services/huangguo_api.dart';
import 'package:huangguo_flutter/services/html_parser.dart';
import 'package:huangguo_flutter/services/library_service.dart';
import 'package:huangguo_flutter/services/storage_usage_service.dart';
import 'package:huangguo_flutter/widgets/library_scope.dart';

class TestDownloadService extends DownloadService {
  final List<DownloadTask> completed;
  bool hasPendingTasks = false;

  TestDownloadService(super.api, this.completed);

  @override
  List<DownloadTask> get completedTasks => List.unmodifiable(completed);

  @override
  List<DownloadTask> get pendingTasks =>
      hasPendingTasks ? completed.take(1).toList() : [];

  void removeAlbum(String dramaId) {
    completed.removeWhere((task) => task.dramaId == dramaId);
    notifyListeners();
  }
}

class TestAlbumApi extends HuangguoApi {
  final List<String> checkedAlbums = [];
  Future<String> Function(String)? onFetchDetail;

  @override
  Future<String> fetchDetail(String dramaId) async {
    checkedAlbums.add(dramaId);
    return onFetchDetail == null ? '' : await onFetchDetail!(dramaId);
  }
}

List<DownloadTask> albumTasks(String dramaId, int count) => List.generate(
  count,
  (index) => DownloadTask(
    id: '$dramaId-$index',
    dramaId: dramaId,
    dramaName: '测试剧$dramaId',
    episodeName: '$dramaId 第${index + 1}集',
    episodeUrl: '/$dramaId/$index',
    ep: '${index + 1}',
    status: DownloadStatus.completed,
    createdAt: DateTime(2026),
  ),
);

Future<TestDownloadService> mountDownloads(
  WidgetTester tester, {
  LibraryService? library,
  DownloadSettingsService? downloadSettings,
  List<DownloadTask>? tasks,
  TestAlbumApi? albumApi,
  bool hasPendingTasks = false,
  StorageUsageService? storageUsageService,
}) async {
  if (downloadSettings == null) {
    final directory = Directory.systemTemp.createTempSync('download_page_sort');
    addTearDown(() => directory.deleteSync(recursive: true));
    downloadSettings = DownloadSettingsService(directory: directory);
  }
  await tester.runAsync(downloadSettings.load);
  final api = albumApi ?? TestAlbumApi();
  final service = TestDownloadService(
    api,
    tasks ??
        [
          ...albumTasks('A', 25),
          ...albumTasks('B', 25),
          ...albumTasks('C', 25),
        ],
  );
  service.hasPendingTasks = hasPendingTasks;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    service.dispose();
    api.dispose();
  });
  final content = MaterialApp(
    home: DownloadPage(
      downloadService: service,
      api: api,
      htmlParser: HtmlParser(api.site),
      onOpenDetail: (_) {},
      downloadSettings: downloadSettings,
      now: tester.binding.clock.now,
      storageUsageService: storageUsageService,
    ),
  );
  await tester.pumpWidget(
    library == null ? content : LibraryScope(library: library, child: content),
  );
  await tester.tap(find.textContaining('已完成 ('));
  await tester.pumpAndSettle();
  return service;
}

ScrollPosition completedPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .hitTestable()
          .first,
    )
    .position;

Finder albumHeader(String dramaId) => find.text('测试剧$dramaId ($dramaId)');

Future<void> jumpDownloads(WidgetTester tester, double offset) async {
  completedPosition(tester).jumpTo(offset);
  await tester.pumpAndSettle();
}
