import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/models/episode.dart';
import 'package:huangguo_flutter/pages/player_page.dart';
import 'package:huangguo_flutter/services/html_parser.dart';
import 'package:huangguo_flutter/services/playback_coordinator.dart';
import 'package:huangguo_flutter/services/playback_settings_service.dart';
import 'package:huangguo_flutter/widgets/playback_scope.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'api_single_video_fixture.dart';
import 'local_download_player_fixture.dart';
import 'local_video_platform.dart';
import 'player_download_fixture.dart';

const localFirstEpisodesFirst = Episode(
  name: '第1集',
  url: '/video/11969/1/',
  ep: '1',
);
const localFirstEpisodes = [
  localFirstEpisodesFirst,
  Episode(name: '第2集', url: '/video/11969/2/', ep: '2'),
];

class SourceVideoPlatform extends LocalVideoPlatform {
  final sources = <DataSource>[];
  final playCalls = <int>[];
  bool failLocal = false;
  Completer<void>? initializationGate;

  @override
  Future<void> play(int playerId) async {
    playCalls.add(playerId);
    await super.play(playerId);
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) {
    final source = options.dataSource;
    sources.add(source);
    return super.createWithOptions(options);
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) async* {
    await initializationGate?.future;
    if (failLocal && sources.last.sourceType == DataSourceType.file) {
      throw PlatformException(code: 'decode', message: '模拟本地解码失败');
    }
    yield* super.videoEventsFor(playerId);
  }
}

class _Settings extends PlaybackSettingsService {
  @override
  Future<void> load() async {}
}

class _Api extends ApiSingleVideoFixture {
  @override
  Future<String> fetchDetail(String dramaId) async => '''
    <div class="hg-web-play__ep-grid">
      <a href="/video/11969/1/" data-ep-id="1">第1集</a>
      <a href="/video/11969/2/" data-ep-id="2">第2集</a>
    </div>
  ''';
}

class LookupDownloads extends ButtonDownloads {
  LookupDownloads(super.api, this.root);

  final String root;

  @override
  String get downloadRoot => root;

  @override
  List<DownloadTask> get tasks => List.unmodifiable(items);
}

class OnlineLocalFixture {
  final api = _Api();
  final platform = SourceVideoPlatform();
  final directory = Directory.systemTemp.createTempSync('online_local_');
  final settings = _Settings();
  final coordinator = PlaybackCoordinator();
  bool onlineVisible = true;
  int playbackRequestId = 0;
  late final downloads = LookupDownloads(api, directory.path);

  DownloadTask addTask({
    String name = 'episode.mp4',
    DownloadStatus status = DownloadStatus.completed,
    String dramaId = '11969',
    String ep = '1',
    String? episodeUrl,
  }) {
    final file = File('${directory.path}/$name')..writeAsStringSync('#EXTM3U');
    final task = DownloadTask(
      id: '$dramaId-$ep',
      dramaId: dramaId,
      dramaName: '本地优先测试剧',
      episodeName: '第$ep集',
      episodeUrl: episodeUrl ?? '/video/$dramaId/',
      ep: ep,
      filePath: file.path,
      status: status,
    );
    downloads.items.add(task);
    return task;
  }

  Future<void> mount(
    WidgetTester tester, {
    String? dramaId = '11969',
    Episode episode = localFirstEpisodesFirst,
  }) async {
    final previous = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = platform;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      VideoPlayerPlatform.instance = previous;
      downloads.dispose();
      settings.dispose();
      api.dispose();
      directory.deleteSync(recursive: true);
    });
    await render(tester, dramaId: dramaId, episode: episode);
    await pumpLocalPlayer(tester);
  }

  Future<void> render(
    WidgetTester tester, {
    String? dramaId = '11969',
    Episode episode = localFirstEpisodesFirst,
  }) => tester.pumpWidget(
    MaterialApp(
      home: PlaybackScope(
        settings: settings,
        coordinator: coordinator,
        onlineVisible: onlineVisible,
        child: PlayerPage(
          api: api,
          htmlParser: HtmlParser(api.site),
          initialEpisode: episode,
          playbackRequestId: playbackRequestId,
          allEpisodes: localFirstEpisodes,
          dramaId: dramaId,
          dramaName: '本地优先测试剧',
          downloadService: downloads,
          startPosition: const Duration(seconds: 25),
        ),
      ),
    ),
  );
}
