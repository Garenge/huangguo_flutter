import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/widgets/video_player_surface.dart';

import 'helpers/test_video_controller.dart';
import 'video_player_surface_test.dart' show mountPlayer, removePlayer;

void main() {
  testWidgets('3x long press uses 2x and vibrates once, release restores 3x', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final controller = TestVideoController(speed: 3);
    await mountPlayer(tester, controller);
    final origin = tester.getTopLeft(find.byType(VideoPlayerSurface));
    final gesture = await tester.startGesture(origin + const Offset(80, 40));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(controller.value.playbackSpeed, 2);
    expect(
      calls
          .where((c) => c.method == 'HapticFeedback.vibrate')
          .map((c) => c.arguments),
      ['HapticFeedbackType.lightImpact'],
    );
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pump();
    expect(controller.value.playbackSpeed, 3);
    expect(
      calls.where((c) => c.method == 'HapticFeedback.vibrate'),
      hasLength(1),
    );
    await removePlayer(tester, controller);
  });

  testWidgets('paused long press neither accelerates nor vibrates', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final controller = TestVideoController(playing: false);
    await mountPlayer(tester, controller);
    final origin = tester.getTopLeft(find.byType(VideoPlayerSurface));
    final gesture = await tester.startGesture(origin + const Offset(80, 40));
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.speeds, isEmpty);
    expect(calls.where((c) => c.method == 'HapticFeedback.vibrate'), isEmpty);
    await gesture.up();
    await removePlayer(tester, controller);
  });

  testWidgets('cancelled drag restores play state without seeking', (
    tester,
  ) async {
    final controller = TestVideoController();
    await mountPlayer(tester, controller);
    final origin = tester.getTopLeft(find.byType(VideoPlayerSurface));
    final gesture = await tester.startGesture(origin + const Offset(80, 40));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(controller.value.isPlaying, isFalse);
    await gesture.cancel();
    await tester.pump();
    expect(controller.value.isPlaying, isTrue);
    expect(controller.seeks, isEmpty);
    await removePlayer(tester, controller);
  });

  testWidgets('background interrupts temporary fast forwarding', (
    tester,
  ) async {
    final controller = TestVideoController(speed: 1.25);
    await mountPlayer(tester, controller);
    final origin = tester.getTopLeft(find.byType(VideoPlayerSurface));
    final gesture = await tester.startGesture(origin + const Offset(80, 40));
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.value.playbackSpeed, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(controller.value.isPlaying, isFalse);
    expect(controller.value.playbackSpeed, 1.25);
    await gesture.cancel();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await removePlayer(tester, controller);
  });

  testWidgets('episode swipe is enabled only in fullscreen', (tester) async {
    final controller = TestVideoController();
    var switched = 0;
    await mountPlayer(tester, controller, next: () => switched++);
    var origin = tester.getTopLeft(find.byType(VideoPlayerSurface));
    await tester.flingFrom(
      origin + const Offset(80, 100),
      const Offset(0, -60),
      1000,
    );
    await tester.pump();
    expect(switched, 0);
    await mountPlayer(
      tester,
      controller,
      next: () => switched++,
      fullscreen: true,
    );
    origin = tester.getTopLeft(find.byType(VideoPlayerSurface));
    await tester.flingFrom(
      origin + const Offset(80, 100),
      const Offset(0, -60),
      1000,
    );
    await tester.pump();
    expect(switched, 1);
    await removePlayer(tester, controller);
  });
}
