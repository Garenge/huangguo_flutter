import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/episode.dart';
import 'package:huangguo_flutter/models/drama.dart';
import 'package:huangguo_flutter/pages/player_page.dart';
import 'package:huangguo_flutter/services/huangguo_api.dart';
import 'package:huangguo_flutter/services/html_parser.dart';
import 'package:huangguo_flutter/services/library_service.dart';
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

Future<void> _verifyFavorites(
  WidgetTester tester,
  LibraryService library,
  Drama drama,
) async {
  expect(find.byTooltip('收藏'), findsOneWidget);
  await tester.tap(find.byTooltip('收藏'));
  await tester.pump();
  expect(library.isFavorite(drama.id), isTrue);
  expect(library.favorites.single.pic, drama.pic);
  expect(library.favorites.single.remark, drama.remark);
  expect(find.byTooltip('取消收藏'), findsOneWidget);
  await library.toggleFavorite(drama);
  await tester.pump();
  expect(find.byTooltip('收藏'), findsOneWidget);
  await tester.tap(find.byTooltip('收藏'));
  await tester.pump();
  await tester.tap(find.byTooltip('取消收藏'));
  await tester.pump();
  expect(library.isFavorite(drama.id), isFalse);
}

void main() {
  testWidgets(
    'online player syncs favorites and marks watched after progress',
    (tester) async {
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
      const drama = Drama(
        id: 'online',
        name: '在线测试剧',
        pic: 'https://example.com/cover.jpg',
        remark: '全10集',
      );
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
                drama: drama,
              ),
            ),
          ),
        ),
      );
      await pumpLocalPlayer(tester);
      await _verifyFavorites(tester, library, drama);
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
    },
  );
}
