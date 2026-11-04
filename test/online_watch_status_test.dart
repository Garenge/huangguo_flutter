import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/episode.dart';
import 'package:huangguo_flutter/pages/player_page.dart';
import 'package:huangguo_flutter/services/huangguo_api.dart';
import 'package:huangguo_flutter/services/html_parser.dart';
import 'package:huangguo_flutter/services/playback_coordinator.dart';
import 'package:huangguo_flutter/services/playback_settings_service.dart';
import 'package:huangguo_flutter/widgets/app_video_player.dart';
import 'package:huangguo_flutter/widgets/library_scope.dart';
import 'package:huangguo_flutter/widgets/playback_scope.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'helpers/library_fixture.dart';
import 'helpers/local_download_player_fixture.dart';
import 'helpers/local_video_platform.dart';

class _Api extends HuangguoApi {
  static const html = '''
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

void main() {
  testWidgets('online player marks the correct drama only after progress', (
    tester,
  ) async {
    final library = await memoryLibrary();
    final api = _Api();
    final settings = _Settings();
    final platform = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = LocalVideoPlatform();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      VideoPlayerPlatform.instance = platform;
      library.dispose();
      settings.dispose();
      api.dispose();
    });
    const episode = Episode(name: '第1集', url: '/video/online/', ep: '1');
    await tester.pumpWidget(
      LibraryScope(
        library: library,
        child: MaterialApp(
          home: PlaybackScope(
            settings: settings,
            coordinator: PlaybackCoordinator(),
            onlineVisible: true,
            child: PlayerPage(
              api: api,
              htmlParser: HtmlParser(api.site),
              initialEpisode: episode,
              allEpisodes: const [episode],
              dramaId: 'online',
              dramaName: '在线测试剧',
            ),
          ),
        ),
      ),
    );
    await pumpLocalPlayer(tester);
    final controller = tester
        .widget<AppVideoPlayer>(find.byType(AppVideoPlayer))
        .controller!;
    expect(library.hasWatched('online', '在线测试剧'), isFalse);
    controller.value = controller.value.copyWith(
      position: const Duration(seconds: 2),
    );
    await pumpLocalPlayer(tester);
    expect(library.hasWatched('online', '在线测试剧', ep: '1'), isTrue);
    expect(library.hasWatched('other', '在线测试剧'), isFalse);
    expect(tester.takeException(), isNull);
  });
}
