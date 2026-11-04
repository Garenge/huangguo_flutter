import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/widgets/app_video_player.dart';

import 'helpers/test_video_controller.dart';

Future<void> _mountPlayer(
  WidgetTester tester,
  ValueNotifier<TestVideoController> source, {
  VoidCallback? onNext,
  List<MethodCall>? calls,
}) async {
  final controllers = <TestVideoController>{};
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      calls?.add(call);
      return null;
    },
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    for (final controller in controllers) {
      await controller.dispose();
    }
    source.dispose();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: Scaffold(
        body: ValueListenableBuilder<TestVideoController>(
          valueListenable: source,
          builder: (_, controller, _) {
            controllers.add(controller);
            return SizedBox(
              height: 240,
              child: AppVideoPlayer(
                controller: controller,
                title: '测试剧集',
                onNext: onNext,
              ),
            );
          },
        ),
      ),
    ),
  );
}

void _complete(TestVideoController controller) {
  controller.value = controller.value.copyWith(
    position: controller.value.duration,
    isPlaying: false,
  );
}

void main() {
  testWidgets('last episode exits fullscreen and restores system modes once', (
    tester,
  ) async {
    final controller = TestVideoController();
    final calls = <MethodCall>[];
    await _mountPlayer(tester, ValueNotifier(controller), calls: calls);
    await tester.tap(find.byTooltip('全屏'));
    await tester.pumpAndSettle();
    _complete(controller);
    _complete(controller);
    await tester.pumpAndSettle();
    expect(find.byTooltip('退出全屏'), findsNothing);
    expect(find.byTooltip('全屏'), findsOneWidget);
    expect(
      calls
          .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
          .map((c) => c.arguments),
      [
        ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'],
        ['DeviceOrientation.portraitUp'],
      ],
    );
    expect(
      calls
          .where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
          .last
          .arguments,
      'SystemUiMode.edgeToEdge',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-final episode remains fullscreen after completion', (
    tester,
  ) async {
    final controller = TestVideoController();
    await _mountPlayer(tester, ValueNotifier(controller), onNext: () {});
    await tester.tap(find.byTooltip('全屏'));
    await tester.pumpAndSettle();
    _complete(controller);
    await tester.pumpAndSettle();
    expect(find.byTooltip('退出全屏'), findsOneWidget);
  });

  testWidgets('buffering at the end waits until completion is ready', (
    tester,
  ) async {
    final controller = TestVideoController();
    await _mountPlayer(tester, ValueNotifier(controller));
    await tester.tap(find.byTooltip('全屏'));
    await tester.pumpAndSettle();
    controller.value = controller.value.copyWith(isBuffering: true);
    _complete(controller);
    await tester.pump();
    expect(find.byTooltip('退出全屏'), findsOneWidget);
    controller.value = controller.value.copyWith(isBuffering: false);
    await tester.pumpAndSettle();
    expect(find.byTooltip('全屏'), findsOneWidget);
  });

  testWidgets('completion outside fullscreen leaves the player page open', (
    tester,
  ) async {
    final controller = TestVideoController();
    await _mountPlayer(tester, ValueNotifier(controller));
    _complete(controller);
    await tester.pumpAndSettle();
    expect(find.byType(AppVideoPlayer), findsOneWidget);
    expect(find.byTooltip('全屏'), findsOneWidget);
  });

  testWidgets(
    'controller replacement ignores old completion and tracks new one',
    (tester) async {
      final first = TestVideoController();
      final second = TestVideoController();
      final source = ValueNotifier(first);
      await _mountPlayer(tester, source);
      await tester.tap(find.byTooltip('全屏'));
      await tester.pumpAndSettle();
      source.value = second;
      await tester.pump();
      await tester.pump();
      _complete(first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('退出全屏'), findsOneWidget);
      _complete(second);
      await tester.pumpAndSettle();
      expect(find.byTooltip('全屏'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending completion does not pop a covering route', (
    tester,
  ) async {
    final controller = TestVideoController();
    await _mountPlayer(tester, ValueNotifier(controller));
    await tester.tap(find.byTooltip('全屏'));
    await tester.pumpAndSettle();
    _complete(controller);
    final context = tester.element(find.byTooltip('退出全屏'));
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('覆盖页面')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('覆盖页面'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
