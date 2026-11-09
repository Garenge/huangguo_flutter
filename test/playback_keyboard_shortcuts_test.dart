import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/widgets/app_video_player.dart';

import 'helpers/test_video_controller.dart';

class _DelayedController extends TestVideoController {
  Completer<void>? pending;

  @override
  Future<void> seekTo(Duration position) async {
    final blocker = pending;
    pending = null;
    await blocker?.future;
    await super.seekTo(position);
  }
}

Future<void> _mount(
  WidgetTester tester,
  TestVideoController controller, {
  bool loading = false,
  TargetPlatform platform = TargetPlatform.macOS,
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
    testWidgets('five second seeks clamp both boundaries on $platform', (
      tester,
    ) async {
      final controller = TestVideoController(playing: false);
      await _mount(tester, controller, platform: platform);
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 2),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(controller.seeks.last, Duration.zero);
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 598),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.seeks.last, controller.value.duration);
      expect(controller.value.isPlaying, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(controller.seeks.last, const Duration(seconds: 595));
    });
  }

  testWidgets('queued and repeated arrows accumulate while native seek waits', (
    tester,
  ) async {
    final controller = _DelayedController();
    final blocker = Completer<void>();
    controller.pending = blocker;
    await _mount(tester, controller);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(controller.seeks, isEmpty);
    blocker.complete();
    await tester.pump();
    expect(controller.seeks, [
      const Duration(seconds: 65),
      const Duration(seconds: 70),
      const Duration(seconds: 65),
    ]);
    expect(controller.value.isPlaying, isTrue);
  });

  testWidgets('space toggles once per press and replays completed video', (
    tester,
  ) async {
    final controller = TestVideoController();
    await _mount(tester, controller);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(controller.value.isPlaying, isFalse);
    controller.value = controller.value.copyWith(
      position: controller.value.duration,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(controller.value.isPlaying, isTrue);
    expect(controller.seeks.last, Duration.zero);
  });

  testWidgets('typing, modifiers and popup routes do not control playback', (
    tester,
  ) async {
    final controller = TestVideoController();
    await _mount(tester, controller);
    await tester.tap(find.byType(TextField));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(controller.value.isPlaying, isTrue);
    expect(controller.seeks, isEmpty);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    expect(controller.seeks, isEmpty);
    final context = tester.element(find.byType(AppVideoPlayer));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('弹窗')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(controller.value.isPlaying, isTrue);
    expect(controller.seeks, isEmpty);
  });

  testWidgets('fullscreen keys run once and work after exit', (tester) async {
    final controller = TestVideoController();
    await _mount(tester, controller);
    await tester.tap(find.byTooltip('全屏'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.seeks, [const Duration(seconds: 65)]);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(controller.value.isPlaying, isFalse);
    await tester.tap(find.byTooltip('退出全屏'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.seeks.last, const Duration(seconds: 60));
  });

  testWidgets('loading disables playback keys', (tester) async {
    final controller = TestVideoController();
    await _mount(tester, controller, loading: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(controller.seeks, isEmpty);
    expect(controller.value.isPlaying, isTrue);
  });
  testWidgets('slider focus does not consume five second keyboard seek', (
    tester,
  ) async {
    final controller = TestVideoController(playing: false);
    await _mount(tester, controller);
    final sliderContext = tester.element(find.byType(Slider));
    final focus = sliderContext.findAncestorWidgetOfExactType<Focus>();
    focus?.focusNode?.requestFocus();
    await tester.tap(find.byType(Slider));
    await tester.pump();
    final start = controller.value.position;
    controller.seeks.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.seeks, [start + const Duration(seconds: 5)]);
  });

  testWidgets('zero duration and initialization errors ignore seeks', (
    tester,
  ) async {
    final controller = TestVideoController();
    await _mount(tester, controller);
    controller.value = controller.value.copyWith(duration: Duration.zero);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(controller.seeks, isEmpty);
    controller.value = controller.value.copyWith(errorDescription: '解码失败');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(controller.value.isPlaying, isTrue);
  });

  testWidgets('source replacement cancels queued seeks', (tester) async {
    final first = _DelayedController();
    final second = TestVideoController();
    final blocker = Completer<void>();
    first.pending = blocker;
    final source = ValueNotifier<TestVideoController>(first);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: ValueListenableBuilder<TestVideoController>(
            valueListenable: source,
            builder: (_, controller, _) => SizedBox(
              height: 260,
              child: AppVideoPlayer(controller: controller, title: '视频'),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    source.value = second;
    await tester.pump();
    blocker.complete();
    await tester.pump();
    expect(first.seeks, [const Duration(seconds: 65)]);
    expect(second.seeks, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(second.seeks, [const Duration(seconds: 55)]);
    await tester.pumpWidget(const SizedBox());
    await first.dispose();
    await second.dispose();
    source.dispose();
  });
}
