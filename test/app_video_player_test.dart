import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/widgets/app_video_player.dart';
import 'package:huangguo_flutter/widgets/video_player_surface.dart';

import 'helpers/test_video_controller.dart';

void main() {
  testWidgets('fullscreen follows source changes and restores screen mode', (
    tester,
  ) async {
    final first = TestVideoController();
    final second = TestVideoController();
    final source = ValueNotifier(first);
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: ValueListenableBuilder<TestVideoController>(
            valueListenable: source,
            builder: (_, controller, _) => SizedBox(
              height: 240,
              child: AppVideoPlayer(
                controller: controller,
                title: controller == first ? '第一集' : '第二集',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('全屏'));
    await tester.pumpAndSettle();
    expect(find.text('第一集'), findsOneWidget);
    source.value = second;
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('第二集'), findsOneWidget);
    expect(find.byType(VideoPlayerSurface), findsOneWidget);
    await tester.tap(find.byTooltip('退出全屏'));
    await tester.pumpAndSettle();
    expect(second.value.isPlaying, isTrue);
    expect(
      calls
          .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
          .last
          .arguments,
      ['DeviceOrientation.portraitUp'],
    );
    await tester.pumpWidget(const SizedBox());
    await first.dispose();
    await second.dispose();
    source.dispose();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  testWidgets('portrait fullscreen keeps the device in portrait', (
    tester,
  ) async {
    final controller = TestVideoController(size: const Size(1080, 1920));
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: AppVideoPlayer(controller: controller, title: '竖屏'),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('全屏'));
    await tester.pumpAndSettle();
    expect(
      calls
          .where(
            (call) => call.method == 'SystemChrome.setPreferredOrientations',
          )
          .first
          .arguments,
      ['DeviceOrientation.portraitUp'],
    );
    await tester.tap(find.byTooltip('退出全屏'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  testWidgets('macOS keeps the fullscreen route without mobile system modes', (
    tester,
  ) async {
    final controller = TestVideoController();
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: AppVideoPlayer(controller: controller, title: 'Mac 视频'),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('全屏'));
    await tester.pumpAndSettle();
    expect(find.text('Mac 视频'), findsOneWidget);
    expect(
      calls.where(
        (call) =>
            call.method == 'SystemChrome.setPreferredOrientations' ||
            call.method == 'SystemChrome.setEnabledSystemUIMode',
      ),
      isEmpty,
    );
    await tester.tap(find.byTooltip('退出全屏'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  testWidgets('error has retry and back even before initialization', (
    tester,
  ) async {
    var retried = false;
    var exited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: AppVideoPlayer(
              controller: null,
              title: '本地视频',
              error: '加载失败',
              onRetry: () => retried = true,
              onBack: () => exited = true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('重试'));
    await tester.tap(find.byTooltip('返回'));
    expect(retried, isTrue);
    expect(exited, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
