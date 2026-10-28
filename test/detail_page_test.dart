import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/models/drama.dart';
import 'package:huangguo_flutter/models/episode.dart';
import 'package:huangguo_flutter/pages/detail_page.dart';
import 'package:huangguo_flutter/services/download_service.dart';
import 'package:huangguo_flutter/services/huangguo_api.dart';
import 'package:huangguo_flutter/services/html_parser.dart';
import 'package:huangguo_flutter/services/image_decryptor.dart';

class _TestApi extends HuangguoApi {
  int detailFetchCount = 0;

  @override
  Future<String> fetchDetail(String dramaId) async {
    detailFetchCount++;
    return '''
    <div class="hg-web-detail__cover">
      <img data-original="/detail-cover.jpg">
    </div>
    <div class="hg-web-play__ep-grid">
      <a href="/play/$dramaId/1/" data-ep-id="1">第1集</a>
      <a href="/play/$dramaId/2/" data-ep-id="2">第2集</a>
    </div>
  ''';
  }

  @override
  Future<List<int>> fetchImageBytes(String url) async => [];
}

class _TestDownloadService extends DownloadService {
  final List<DownloadTask> _testTasks = [];

  _TestDownloadService(super.api);

  @override
  List<DownloadTask> get tasks => List.unmodifiable(_testTasks);

  @override
  DownloadTask? taskForEpisode(String dramaId, String ep) {
    for (final task in _testTasks) {
      if (task.dramaId == dramaId && task.ep == ep) return task;
    }
    return null;
  }

  @override
  bool isEpisodeDownloaded(String dramaId, String ep) {
    return taskForEpisode(dramaId, ep)?.status == DownloadStatus.completed;
  }

  @override
  Future<DownloadTask?> addTask(Drama drama, Episode episode) async {
    final task = DownloadTask(
      id: '${drama.id}_${episode.ep}',
      dramaId: drama.id,
      dramaName: drama.name,
      episodeName: episode.name,
      episodeUrl: episode.url,
      ep: episode.ep,
    );
    _testTasks.add(task);
    notifyListeners();
    return task;
  }

  void completeTask(String ep) {
    final task = _testTasks.firstWhere((item) => item.ep == ep);
    task.status = DownloadStatus.completed;
    notifyListeners();
  }
}

void main() {
  testWidgets('episode and download controls have independent actions', (
    tester,
  ) async {
    final api = _TestApi();
    final service = _TestDownloadService(api);
    var playedEpisode = '';
    final drama = const Drama(id: '1', name: '测试剧', pic: '', remark: '');

    addTearDown(() {
      service.dispose();
      api.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: DetailPage(
          drama: drama,
          api: api,
          htmlParser: HtmlParser(api.site),
          imageDecryptor: ImageDecryptor(),
          downloadService: service,
          onPlayEpisode: (episode, _) => playedEpisode = episode.ep,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.detailFetchCount, 1);

    await tester.tap(find.text('第1集'));
    expect(playedEpisode, '1');
    expect(service.tasks, isEmpty);

    await tester.tap(find.byTooltip('下载第2集'));
    await tester.pump();
    expect(playedEpisode, '1');
    expect(service.tasks.single.ep, '2');
  });

  testWidgets('completed download updates the episode and shows a notice', (
    tester,
  ) async {
    final api = _TestApi();
    final service = _TestDownloadService(api);
    final drama = const Drama(id: '1', name: '测试剧', pic: '', remark: '');

    addTearDown(() {
      service.dispose();
      api.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: DetailPage(
          drama: drama,
          api: api,
          htmlParser: HtmlParser(api.site),
          imageDecryptor: ImageDecryptor(),
          downloadService: service,
          onPlayEpisode: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('下载第1集'));
    await tester.pumpAndSettle();
    service.completeTask('1');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
