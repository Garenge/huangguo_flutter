import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/pages/download_page.dart';
import 'package:huangguo_flutter/services/download_service.dart';
import 'package:huangguo_flutter/services/huangguo_api.dart';
import 'package:huangguo_flutter/services/html_parser.dart';

class TestDownloadService extends DownloadService {
  final List<DownloadTask> completed;

  TestDownloadService(super.api, this.completed);

  @override
  List<DownloadTask> get completedTasks => List.unmodifiable(completed);

  void removeAlbum(String dramaId) {
    completed.removeWhere((task) => task.dramaId == dramaId);
    notifyListeners();
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
  ),
);

Future<TestDownloadService> mountDownloads(WidgetTester tester) async {
  final api = HuangguoApi();
  final service = TestDownloadService(api, [
    ...albumTasks('A', 25),
    ...albumTasks('B', 25),
    ...albumTasks('C', 25),
  ]);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    service.dispose();
    api.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: DownloadPage(
        downloadService: service,
        api: api,
        htmlParser: HtmlParser(api.site),
        onOpenDetail: (_) {},
      ),
    ),
  );
  await tester.tap(find.text('已完成 (75)'));
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
