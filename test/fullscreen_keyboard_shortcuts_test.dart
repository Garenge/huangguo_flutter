import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/widgets/app_video_player.dart';
import 'package:huangguo_flutter/widgets/video_player_surface.dart';

import 'helpers/test_video_controller.dart';

Future<void> _openFullscreen(
  WidgetTester tester,
  TestVideoController controller,
  ValueNotifier<String?> status,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.macOS),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                body: ValueListenableBuilder<String?>(
                  valueListenable: status,
                  builder: (_, value, _) => AppVideoPlayer(
                    controller: controller,
                    title: '测试视频',
                    loading: value == 'loading',
                    error: value == 'error' ? '播放失败' : null,
                  ),
                ),
              ),
            ),
          ),
          child: const Text('打开播放器'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开播放器'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('全屏'));
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    status.dispose();
    await controller.dispose();
  });
}

void main() {
  for (final key in [LogicalKeyboardKey.backspace, LogicalKeyboardKey.escape]) {
    for (final statusValue in [null, 'loading', 'error']) {
      for (final playing in [true, false]) {
        testWidgets(
          '$key exits only fullscreen with status=$statusValue playing=$playing',
          (tester) async {
            final controller = TestVideoController(playing: playing);
            final status = ValueNotifier<String?>(null);
            await _openFullscreen(tester, controller, status);
            expect(
              tester
                  .widget<VideoPlayerSurface>(find.byType(VideoPlayerSurface))
                  .fullscreen,
              isTrue,
            );
            status.value = statusValue;
            await tester.pump();
            await tester.pump();
            final position = controller.value.position;

            await tester.sendKeyDownEvent(key);
            await tester.sendKeyRepeatEvent(key);
            await tester.pump();
            await tester.pump(const Duration(seconds: 1));
            await tester.sendKeyRepeatEvent(key);
            await tester.sendKeyUpEvent(key);
            await tester.pump();

            expect(find.byType(AppVideoPlayer), findsOneWidget);
            expect(
              tester
                  .widget<VideoPlayerSurface>(find.byType(VideoPlayerSurface))
                  .fullscreen,
              isFalse,
            );
            expect(controller.value.position, position);
            expect(controller.value.isPlaying, playing);
            expect(find.text('打开播放器'), findsNothing);

            await tester.sendKeyEvent(key);
            await tester.pump();
            expect(find.byType(AppVideoPlayer), findsOneWidget);
          },
        );
      }
    }
  }
}
