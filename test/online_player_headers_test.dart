import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/pages/player_page.dart';
import 'package:huangguo_flutter/services/html_parser.dart';
import 'package:huangguo_flutter/services/playback_coordinator.dart';
import 'package:huangguo_flutter/services/playback_settings_service.dart';
import 'package:huangguo_flutter/widgets/app_video_player.dart';
import 'package:huangguo_flutter/widgets/playback_scope.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'helpers/api_single_video_fixture.dart';
import 'helpers/local_download_player_fixture.dart';
import 'helpers/local_video_platform.dart';

class _Settings extends PlaybackSettingsService {
  @override
  Future<void> load() async {}
}

class _Platform extends LocalVideoPlatform {
  DataSource? source;

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) {
    source = options.dataSource;
    return super.createWithOptions(options);
  }
}

Future<void> _mountPlayer(
  WidgetTester tester,
  ApiSingleVideoFixture api,
  PlaybackSettingsService settings,
) async {
  final parser = HtmlParser(api.site);
  final episodes = parser.parseEpisodes(apiSingleVideoHtml);
  await tester.pumpWidget(
    MaterialApp(
      home: PlaybackScope(
        settings: settings,
        coordinator: PlaybackCoordinator(),
        onlineVisible: true,
        child: PlayerPage(
          api: api,
          htmlParser: parser,
          initialEpisode: episodes.single,
          allEpisodes: episodes,
          dramaId: '11969',
          dramaName: 'API 单视频测试',
        ),
      ),
    ),
  );
  await pumpLocalPlayer(tester);
}

void main() {
  testWidgets('passes API CDN headers to the native online player', (
    tester,
  ) async {
    final api = ApiSingleVideoFixture();
    final settings = _Settings();
    final previous = VideoPlayerPlatform.instance;
    final platform = _Platform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      VideoPlayerPlatform.instance = previous;
      settings.dispose();
      api.dispose();
    });

    await _mountPlayer(tester, api, settings);

    expect(api.requests, ['11969:1']);
    expect(platform.source?.uri, 'https://cdn.example/main.m3u8');
    expect(platform.source?.httpHeaders, apiSingleVideoHeaders);
    final player = tester.widget<AppVideoPlayer>(find.byType(AppVideoPlayer));
    expect(player.controller?.value.isInitialized, isTrue);
    expect(tester.takeException(), isNull);
  });
}
