import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/widgets/app_video_player.dart';
import 'package:huangguo_flutter/widgets/local_download_player.dart';

import 'helpers/local_download_player_fixture.dart';

void main() {
  testWidgets('local episodes show resource size after the episode name', (
    tester,
  ) async {
    await mountLocalDownloads(tester, taskCount: 2);
    final firstSize = find.descendant(
      of: localEpisode('本地第1集'),
      matching: find.text('1 B'),
    );
    expect(firstSize, findsOneWidget);
    expect(
      tester.getTopLeft(firstSize).dx,
      greaterThan(tester.getTopLeft(find.text('本地第1集').last).dx),
    );
    await tester.tap(localEpisode('本地第2集'));
    await pumpLocalPlayer(tester);
    expect(find.text('1 B'), findsNWidgets(2));
    expect(localPlayer(tester).controller!.value.isPlaying, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolling episodes leaves the playing video fixed', (
    tester,
  ) async {
    await mountLocalDownloads(tester);
    expect(localPlayer(tester).windowTitle, '本地测试剧 · 本地第1集');
    final bounds = tester.getRect(find.byType(AppVideoPlayer));
    final controller = localPlayer(tester).controller!;
    expect(controller.value.isPlaying, isTrue);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await pumpLocalPlayer(tester);
    expect(tester.getRect(find.byType(AppVideoPlayer)), bounds);
    expect(localEpisode('本地第1集'), findsNothing);
    expect(localPlayer(tester).controller, same(controller));
    expect(controller.value.isPlaying, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a scrolled episode keeps the player fixed', (
    tester,
  ) async {
    await mountLocalDownloads(tester);
    final bounds = tester.getRect(find.byType(AppVideoPlayer));
    await tester.scrollUntilVisible(localEpisode('本地第15集'), 200);
    await tester.tap(localEpisode('本地第15集'));
    await pumpLocalPlayer(tester);
    expect(localPlayer(tester).title, '本地第15集');
    expect(localPlayer(tester).windowTitle, '本地测试剧 · 本地第15集');
    expect(
      localPlayer(tester).loading,
      isFalse,
      reason:
          'local_download_player_test.dart select: ${localPlayer(tester).error}',
    );
    expect(localPlayer(tester).controller!.value.isPlaying, isTrue);
    expect(tester.getRect(find.byType(AppVideoPlayer)), bounds);
    expect(tester.widget<ListTile>(localEpisode('本地第15集')).selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('automatic next episode and its switch remain functional', (
    tester,
  ) async {
    await mountLocalDownloads(tester);
    final first = localPlayer(tester).controller!;
    first.value = first.value.copyWith(position: first.value.duration);
    await pumpLocalPlayer(tester);
    expect(localPlayer(tester).title, '本地第2集');
    await tester.tap(find.byType(Switch));
    await pumpLocalPlayer(tester);
    expect(
      localPlayer(tester).loading,
      isFalse,
      reason:
          'local_download_player_test.dart auto: ${localPlayer(tester).error}',
    );
    final second = localPlayer(tester).controller!;
    second.value = second.value.copyWith(position: second.value.duration);
    await pumpLocalPlayer(tester);
    expect(localPlayer(tester).title, '本地第2集');
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning from fullscreen preserves the fixed player', (
    tester,
  ) async {
    await mountLocalDownloads(tester);
    final bounds = tester.getRect(find.byType(AppVideoPlayer));
    final controller = localPlayer(tester).controller;
    expect(localPlayer(tester).onBack, isNull);
    expect(find.byType(AppBar), findsOneWidget);
    await tester.tap(find.byTooltip('全屏'));
    await pumpLocalPlayer(tester);
    expect(find.byTooltip('返回'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await pumpLocalPlayer(tester);
    await pumpLocalPlayer(tester);
    expect(localPlayer(tester).onBack, isNull);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(ListView).hitTestable(), findsOneWidget);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    final before = position.pixels;
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await pumpLocalPlayer(tester);
    expect(position.pixels, greaterThan(before));
    expect(tester.getRect(find.byType(AppVideoPlayer)), bounds);
    expect(localPlayer(tester).controller, same(controller));
    expect(controller!.value.isPlaying, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('last downloaded episode exits fullscreen when finished', (
    tester,
  ) async {
    await mountLocalDownloads(tester);
    await tester.scrollUntilVisible(localEpisode('本地第40集'), 300);
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await pumpLocalPlayer(tester);
    await tester.tap(localEpisode('本地第40集'));
    await pumpLocalPlayer(tester);
    final controller = localPlayer(tester).controller!;
    expect(localPlayer(tester).onNext, isNull);
    await tester.tap(find.byTooltip('全屏'));
    await pumpLocalPlayer(tester);
    await controller.pause();
    controller.value = controller.value.copyWith(
      position: controller.value.duration,
      isPlaying: false,
    );
    await pumpLocalPlayer(tester);
    await pumpLocalPlayer(tester);
    expect(find.byTooltip('退出全屏'), findsNothing);
    expect(find.byTooltip('全屏'), findsOneWidget);
    expect(find.byType(ListView).hitTestable(), findsOneWidget);
    expect(localPlayer(tester).controller, same(controller));
    expect(localPlayer(tester).title, '本地第40集');
    expect(tester.takeException(), isNull);
  });

  testWidgets('downloaded autoplay keeps fullscreen between episodes', (
    tester,
  ) async {
    await mountLocalDownloads(tester);
    final controller = localPlayer(tester).controller!;
    await tester.tap(find.byTooltip('全屏'));
    await pumpLocalPlayer(tester);
    await controller.pause();
    controller.value = controller.value.copyWith(
      position: controller.value.duration,
      isPlaying: false,
    );
    await pumpLocalPlayer(tester);
    expect(find.byTooltip('退出全屏'), findsOneWidget);
    expect(find.text('本地第2集'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disabled downloaded autoplay does not make a middle episode final',
    (tester) async {
      await mountLocalDownloads(tester);
      await tester.tap(find.byType(Switch));
      await pumpLocalPlayer(tester);
      final controller = localPlayer(tester).controller!;
      await tester.tap(find.byTooltip('全屏'));
      await pumpLocalPlayer(tester);
      await controller.pause();
      controller.value = controller.value.copyWith(
        position: controller.value.duration,
        isPlaying: false,
      );
      await pumpLocalPlayer(tester);
      expect(find.byTooltip('退出全屏'), findsOneWidget);
      expect(find.text('本地第1集'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('deleting a non-playing episode refreshes the list only', (
    tester,
  ) async {
    await mountLocalDownloads(tester);
    final controller = localPlayer(tester).controller!;
    await tester.scrollUntilVisible(localEpisode('本地第15集'), 200);
    final episode = localEpisode('本地第15集');
    await tester.tap(
      find.descendant(of: episode, matching: find.byTooltip('删除本地文件')),
    );
    await tester.pump();
    await tester.tap(find.text('删除').last);
    await pumpLocalPlayer(tester);

    expect(find.text('本地第15集'), findsNothing);
    expect(localPlayer(tester).title, '本地第1集');
    expect(localPlayer(tester).controller, same(controller));
    expect(controller.value.isPlaying, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting the playing episode starts the next episode', (
    tester,
  ) async {
    await mountLocalDownloads(tester);
    final episode = localEpisode('本地第1集');
    await tester.tap(
      find.descendant(of: episode, matching: find.byTooltip('删除本地文件')),
    );
    await tester.pump();
    await tester.tap(find.text('删除').last);
    await pumpLocalPlayer(tester);

    expect(localPlayer(tester).title, '本地第2集');
    expect(localPlayer(tester).controller!.value.isPlaying, isTrue);
    expect(find.text('本地第1集'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting the only episode returns to the previous page', (
    tester,
  ) async {
    await mountLocalDownloads(tester, taskCount: 1);
    final episode = localEpisode('本地第1集');
    await tester.tap(
      find.descendant(of: episode, matching: find.byTooltip('删除本地文件')),
    );
    await tester.pump();
    await tester.tap(find.text('删除').last);
    await pumpLocalPlayer(tester);
    await tester.pumpAndSettle();

    expect(find.byType(LocalDownloadPlayer), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
