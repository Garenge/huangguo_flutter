import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/widgets/playback_controls.dart';
import 'package:huangguo_flutter/widgets/video_player_surface.dart';

import 'helpers/test_video_controller.dart';

Future<void> mountPlayer(
  WidgetTester tester,
  TestVideoController controller, {
  bool fullscreen = false,
  VoidCallback? next,
  double width = 380,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: 240,
            child: VideoPlayerSurface(
              controller: controller,
              title: '测试视频',
              fullscreen: fullscreen,
              onNext: next,
              onToggleFullscreen: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> removePlayer(
  WidgetTester tester,
  TestVideoController controller,
) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 400));
  await controller.dispose();
}

void main() {
  test('time formatting supports hours and negative input', () {
    expect(formatPlaybackTime(const Duration(seconds: -2)), '00:00');
    expect(formatPlaybackTime(const Duration(seconds: 65)), '01:05');
    expect(formatPlaybackTime(const Duration(seconds: 3661)), '1:01:01');
  });

  testWidgets('controls hide during playback and stay visible when paused', (
    tester,
  ) async {
    final controller = TestVideoController();
    await mountPlayer(tester, controller);
    expect(find.byType(PlaybackControls), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(PlaybackControls), findsNothing);
    await controller.pause();
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(PlaybackControls), findsOneWidget);
    await removePlayer(tester, controller);
  });

  testWidgets('drag previews then seeks once and resumes playback', (
    tester,
  ) async {
    final controller = TestVideoController();
    await mountPlayer(tester, controller);
    final origin = tester.getTopLeft(find.byType(VideoPlayerSurface));
    final gesture = await tester.startGesture(origin + const Offset(80, 40));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(70, 0));
    await tester.pump();
    expect(controller.seeks, isEmpty);
    expect(controller.value.isPlaying, isFalse);
    expect(find.textContaining('松开跳转'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(controller.seeks, hasLength(1));
    expect(controller.seeks.single, greaterThan(const Duration(seconds: 60)));
    expect(controller.value.isPlaying, isTrue);
    await removePlayer(tester, controller);
  });

  testWidgets('slider remains mounted while scrubbing a paused video', (
    tester,
  ) async {
    final controller = TestVideoController(playing: false);
    await mountPlayer(tester, controller);
    final start = tester.getCenter(find.byType(Slider));
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(find.byType(Slider), findsOneWidget);
    await gesture.moveBy(const Offset(20, 0));
    await gesture.up();
    await tester.pump();
    expect(controller.seeks, hasLength(1));
    expect(controller.value.isPlaying, isFalse);
    await removePlayer(tester, controller);
  });

  testWidgets('long press restores the original speed on release', (
    tester,
  ) async {
    final controller = TestVideoController(speed: 1.5);
    await mountPlayer(tester, controller);
    final origin = tester.getTopLeft(find.byType(VideoPlayerSurface));
    final gesture = await tester.startGesture(origin + const Offset(100, 40));
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.value.playbackSpeed, 2);
    await gesture.up();
    await tester.pump();
    expect(controller.value.playbackSpeed, 1.5);
    await removePlayer(tester, controller);
  });

  testWidgets('narrow controls do not overflow', (tester) async {
    final controller = TestVideoController();
    await mountPlayer(tester, controller, next: () {}, width: 280);
    expect(tester.takeException(), isNull);
    await removePlayer(tester, controller);
  });

  testWidgets('completed video can replay from the beginning', (tester) async {
    final controller = TestVideoController(playing: false);
    controller.value = controller.value.copyWith(
      position: controller.value.duration,
      isCompleted: true,
    );
    await mountPlayer(tester, controller);
    await tester.tap(find.byTooltip('播放'));
    await tester.pump();
    expect(controller.seeks, [Duration.zero]);
    expect(controller.value.isPlaying, isTrue);
    await removePlayer(tester, controller);
  });
}
