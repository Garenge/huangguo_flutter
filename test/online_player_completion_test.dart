import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/episode.dart';
import 'package:huangguo_flutter/pages/player_page.dart';
import 'package:huangguo_flutter/services/huangguo_api.dart';
import 'package:huangguo_flutter/services/html_parser.dart';
import 'package:huangguo_flutter/services/playback_coordinator.dart';
import 'package:huangguo_flutter/services/playback_settings_service.dart';
import 'package:huangguo_flutter/widgets/app_video_player.dart';
import 'package:huangguo_flutter/widgets/playback_scope.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'helpers/local_download_player_fixture.dart';
import 'helpers/local_video_platform.dart';

class _Api extends HuangguoApi {
  static const html = '''
    <div class="hg-web-play__ep-grid">
      <a href="/play/123/1/" data-ep-id="1">第1集</a>
      <a href="/play/123/2/" data-ep-id="2">第2集</a>
    </div>
    <script id="videoInitialData" type="application/json">
    {"id":"online","videoSrc":"https://example.com/video.mp4"}
    </script>
  ''';

  @override
  Future<String> fetchDetail(String dramaId) async => html;

  @override
  Future<String> fetchPlayPage(String playUrl) async => html;
}

class _Settings extends PlaybackSettingsService {
  @override
  Future<void> load() async {}
}

Future<void> _mountOnlinePlayer(WidgetTester tester) async {
  final api = _Api();
  final settings = _Settings();
  final platform = VideoPlayerPlatform.instance;
  VideoPlayerPlatform.instance = LocalVideoPlatform();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (_) async => null,
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    VideoPlayerPlatform.instance = platform;
    settings.dispose();
    api.dispose();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
  const episodes = [
    Episode(name: '第1集', url: '/play/123/1/', ep: '1'),
    Episode(name: '第2集', url: '/play/123/2/', ep: '2'),
  ];
  await tester.pumpWidget(
    MaterialApp(
      home: PlaybackScope(
        settings: settings,
        coordinator: PlaybackCoordinator(),
        onlineVisible: true,
        child: PlayerPage(
          api: api,
          htmlParser: HtmlParser(api.site),
          initialEpisode: episodes.first,
          allEpisodes: episodes,
          dramaId: 'online',
          dramaName: '在线测试剧',
        ),
      ),
    ),
  );
  await pumpLocalPlayer(tester);
}

AppVideoPlayer _player(WidgetTester tester) => tester.widget<AppVideoPlayer>(
  find.byType(AppVideoPlayer, skipOffstage: false),
);

void main() {
  testWidgets('online autoplay stays fullscreen until the final episode ends', (
    tester,
  ) async {
    await _mountOnlinePlayer(tester);
    final first = _player(tester).controller!;
    await tester.tap(find.byTooltip('全屏'));
    await pumpLocalPlayer(tester);
    await first.pause();
    first.value = first.value.copyWith(
      position: first.value.duration,
      isPlaying: false,
    );
    await pumpLocalPlayer(tester);
    expect(find.byTooltip('退出全屏'), findsOneWidget);
    expect(find.text('第2集'), findsOneWidget);
    expect(_player(tester).onNext, isNull);
    final last = _player(tester).controller!;
    expect(last, isNot(same(first)));
    await last.pause();
    last.value = last.value.copyWith(
      position: last.value.duration,
      isPlaying: false,
    );
    await pumpLocalPlayer(tester);
    await pumpLocalPlayer(tester);
    expect(find.byTooltip('退出全屏'), findsNothing);
    expect(find.byTooltip('全屏'), findsOneWidget);
    expect(_player(tester).controller, same(last));
    expect(_player(tester).title, '第2集');
    expect(tester.takeException(), isNull);
  });
}
