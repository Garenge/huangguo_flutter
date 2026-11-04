import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/pages/favorites_page.dart';
import 'package:huangguo_flutter/widgets/watch_progress.dart';
import 'package:video_player/video_player.dart';

import 'helpers/library_fixture.dart';
import 'helpers/local_download_player_fixture.dart';
import 'helpers/download_page_fixture.dart';
import 'helpers/home_pagination_fixture.dart';

void main() {
  test(
    'progress rule excludes zero, paused, buffering and error values',
    () async {
      final library = await memoryLibrary();
      addTearDown(library.dispose);
      final base = VideoPlayerValue(
        duration: const Duration(minutes: 10),
        position: const Duration(seconds: 1),
        isInitialized: true,
        isPlaying: true,
      );
      for (final value in [
        base.copyWith(position: Duration.zero),
        base.copyWith(isPlaying: false),
        base.copyWith(isBuffering: true),
        base.copyWith(errorDescription: '测试错误'),
      ]) {
        recordWatchProgress(
          library: library,
          value: value,
          dramaId: 'online',
          dramaName: '在线剧',
          ep: '1',
        );
        await Future<void>.delayed(Duration.zero);
        expect(library.hasWatched('online', '在线剧'), isFalse);
      }
      recordWatchProgress(
        library: library,
        value: base,
        dramaId: 'online',
        dramaName: '在线剧',
        ep: '1',
      );
      await Future<void>.delayed(Duration.zero);
      expect(library.hasWatched('online', '在线剧', ep: '1'), isTrue);
    },
  );

  testWidgets(
    'local playback writes episode state without marking unopened episodes',
    (tester) async {
      final library = await memoryLibrary();
      addTearDown(library.dispose);
      await mountLocalDownloads(tester, library: library);
      expect(library.hasWatched('local-drama', '本地测试剧'), isFalse);
      final controller = localPlayer(tester).controller!;
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 3),
      );
      await pumpLocalPlayer(tester);
      expect(library.hasWatched('local-drama', '本地测试剧', ep: '1'), isTrue);
      expect(library.hasWatched('local-drama', '本地测试剧', ep: '2'), isFalse);
      expect(find.text('看过'), findsOneWidget);
    },
  );

  testWidgets('downloaded album and episodes reflect watched state live', (
    tester,
  ) async {
    final library = await memoryLibrary();
    addTearDown(library.dispose);
    await mountDownloads(tester, library: library);
    expect(find.text('看过 0 / 已下载 25 集').hitTestable(), findsOneWidget);
    await library.markWatched('A', '测试剧A', '1');
    await tester.pumpAndSettle();
    expect(find.text('看过 1 / 已下载 25 集').hitTestable(), findsOneWidget);
    expect(find.text('看过').hitTestable(), findsOneWidget);
    final text = tester.widget<Text>(find.text('A 第1集'));
    expect(text.style!.color, Colors.white38);
  });

  testWidgets(
    'home opens favorites and keeps watched state after canceling favorite',
    (tester) async {
      final library = await memoryLibrary();
      addTearDown(library.dispose);
      await mountPaginationHome(tester, library: library);
      await library.markWatched('1001', 'home:latest:1', '1');
      await tester.pump();
      expect(find.text('看过'), findsOneWidget);
      await tester.tap(find.byTooltip('收藏'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的收藏'));
      await tester.pumpAndSettle();
      expect(find.byType(FavoritesPage), findsOneWidget);
      await tester.tap(find.byTooltip('取消收藏').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('还没有收藏，点击卡片上的星标即可收藏'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('看过'), findsOneWidget);
      expect(find.byTooltip('收藏'), findsOneWidget);
    },
  );
}
