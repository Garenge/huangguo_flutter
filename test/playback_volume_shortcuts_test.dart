import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/widgets/app_video_player.dart';

import 'helpers/test_video_controller.dart';

class _DelayedVolumeController extends TestVideoController {
  _DelayedVolumeController() : super(volume: 0.5);

  Completer<void>? pending;

  @override
  Future<void> setVolume(double volume) async {
    final blocker = pending;
    pending = null;
    await blocker?.future;
    await super.setVolume(volume);
  }
}

Future<void> _mount(
  WidgetTester tester,
  TestVideoController controller, {
  TargetPlatform platform = TargetPlatform.macOS,
  bool loading = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: Column(
          children: [
            SizedBox(
              height: 260,
              child: AppVideoPlayer(
                controller: controller,
                title: '测试视频',
                loading: loading,
              ),
            ),
            const TextField(),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
  });
}

void main() {
  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    for (final playing in [true, false]) {
      testWidgets('five percent volume steps on $platform playing=$playing', (
        tester,
      ) async {
        final controller = TestVideoController(volume: 0.5, playing: playing);
        await _mount(tester, controller, platform: platform);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(controller.value.volume, closeTo(0.55, 0.0001));
        expect(find.text('音量 55%'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(controller.value.volume, closeTo(0.5, 0.0001));
        expect(find.text('音量 50%'), findsOneWidget);
        expect(controller.value.isPlaying, playing);
        expect(controller.seeks, isEmpty);
      });
    }
  }

  testWidgets('volume clamps to mute and full volume', (tester) async {
    final controller = TestVideoController(volume: 0.02);
    await _mount(tester, controller);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.value.volume, 0);
    expect(find.text('音量 0%'), findsOneWidget);
    controller.value = controller.value.copyWith(volume: 0.98);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(controller.value.volume, 1);
    expect(find.text('音量 100%'), findsOneWidget);
  });

  testWidgets('repeat keys accumulate while native volume change waits', (
    tester,
  ) async {
    final controller = _DelayedVolumeController();
    final blocker = Completer<void>();
    controller.pending = blocker;
    await _mount(tester, controller);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(controller.volumes, isEmpty);
    blocker.complete();
    await tester.pump();
    expect(controller.volumes, [
      closeTo(0.55, 0.0001),
      closeTo(0.60, 0.0001),
      closeTo(0.65, 0.0001),
      closeTo(0.60, 0.0001),
    ]);
    expect(find.text('音量 60%'), findsOneWidget);
  });

  testWidgets('volume hint expires after the most recent key press', (
    tester,
  ) async {
    final controller = TestVideoController(volume: 0.5);
    await _mount(tester, controller);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('音量 60%'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('音量 60%'), findsNothing);
    expect(controller.value.volume, closeTo(0.6, 0.0001));
  });

  testWidgets('fullscreen changes volume once and preserves it after exit', (
    tester,
  ) async {
    final controller = TestVideoController(volume: 0.5);
    await _mount(tester, controller);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.tap(find.byTooltip('全屏'));
    await tester.pumpAndSettle();
    expect(find.text('音量 55%'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.volumes, hasLength(2));
    expect(find.text('音量 50%'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.volumes, hasLength(3));
    expect(controller.value.volume, closeTo(0.45, 0.0001));
    expect(find.text('音量 45%'), findsOneWidget);
  });

  testWidgets('text editing, modifiers and dialogs ignore volume keys', (
    tester,
  ) async {
    final controller = TestVideoController(volume: 0.5);
    await _mount(tester, controller);
    await tester.tap(find.byType(TextField));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    for (final modifier in [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.shiftLeft,
    ]) {
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(modifier);
    }
    final context = tester.element(find.byType(AppVideoPlayer));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('弹窗')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.volumes, isEmpty);
    expect(controller.value.volume, 0.5);
  });

  testWidgets('slider focus adjusts volume without seeking', (tester) async {
    final controller = TestVideoController(volume: 0.5, playing: false);
    await _mount(tester, controller);
    await tester.tap(find.byType(Slider));
    await tester.pump();
    controller.seeks.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(controller.value.volume, closeTo(0.55, 0.0001));
    expect(controller.seeks, isEmpty);
  });

  testWidgets('covered player routes ignore volume keys', (tester) async {
    final controller = TestVideoController(volume: 0.5);
    await _mount(tester, controller);
    final context = tester.element(find.byType(AppVideoPlayer));
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('其他页面'))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(controller.volumes, isEmpty);
  });

  testWidgets('loading disables volume keys', (tester) async {
    final controller = TestVideoController(volume: 0.5);
    await _mount(tester, controller, loading: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.volumes, isEmpty);
  });
}
