import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/playback_window_title.dart';
import 'package:huangguo_flutter/widgets/app_video_player.dart';
import 'package:huangguo_flutter/widgets/video_player_surface.dart';

import 'helpers/test_video_controller.dart';

Future<void> _doubleTapVideo(WidgetTester tester) async {
  final surface = find.byType(VideoPlayerSurface);
  final position = tester.getCenter(surface);
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(position);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'window title includes drama and handles missing or duplicate names',
    () {
      AppVideoPlayer player(String title, String? drama) =>
          AppVideoPlayer(controller: null, title: title, dramaName: drama);
      expect(player('第3集', '测试剧').windowTitle, '测试剧 · 第3集');
      expect(player('第3集', null).windowTitle, '第3集');
      expect(player('第3集', '  ').windowTitle, '第3集');
      expect(player('', '测试剧').windowTitle, '测试剧');
      expect(player('测试剧', '测试剧').windowTitle, '测试剧');
    },
  );
  testWidgets(
    'double tap sets drama title, follows episode and restores on exit',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        PlaybackWindowTitle.channel,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      final controller = TestVideoController();
      final title = ValueNotifier('第一集');
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await controller.dispose();
        title.dispose();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          PlaybackWindowTitle.channel,
          null,
        );
        debugDefaultTargetPlatformOverride = null;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: title,
              builder: (_, value, _) => SizedBox(
                height: 260,
                child: AppVideoPlayer(
                  controller: controller,
                  title: value,
                  dramaName: '测试剧',
                ),
              ),
            ),
          ),
        ),
      );
      expect(calls, isEmpty);
      await _doubleTapVideo(tester);
      expect(calls.last.method, 'setPlaybackTitle');
      expect(calls.last.arguments, '测试剧 · 第一集');
      title.value = '第二集';
      await tester.pump();
      await tester.pump();
      expect(calls.last.arguments, '测试剧 · 第二集');
      await _doubleTapVideo(tester);
      expect(calls.map((call) => call.arguments), [
        '测试剧 · 第一集',
        '测试剧 · 第二集',
        null,
      ]);
      await tester.tap(find.byTooltip('全屏'));
      await tester.pumpAndSettle();
      controller.value = controller.value.copyWith(
        position: controller.value.duration,
        isPlaying: false,
      );
      await tester.pumpAndSettle();
      expect(calls.last.arguments, isNull);
      expect(find.byTooltip('退出全屏'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('disposing fullscreen restores title', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      PlaybackWindowTitle.channel,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    final controller = TestVideoController();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 260,
              child: AppVideoPlayer(controller: controller, title: '视频'),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('全屏'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(calls.last.arguments, isNull);
    } finally {
      await controller.dispose();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        PlaybackWindowTitle.channel,
        null,
      );
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
