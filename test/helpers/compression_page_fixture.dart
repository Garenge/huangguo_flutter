import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/pages/compression_test_page.dart';
import 'package:huangguo_flutter/services/compression_test_controller.dart';
import 'package:huangguo_flutter/services/compression_test_workspace.dart';
import 'package:huangguo_flutter/services/playback_coordinator.dart';
import 'package:huangguo_flutter/services/playback_settings_service.dart';
import 'package:huangguo_flutter/widgets/playback_scope.dart';
// Tests replace native decoding with the existing video platform fixture.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'compression_test_fixture.dart';
import 'local_video_platform.dart';

Future<
  ({
    CompressionTestController controller,
    FakeCompressionEngine engine,
    File source,
  })
>
mountCompressionPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 1100);
  tester.view.devicePixelRatio = 1;
  final root = Directory.systemTemp.createTempSync('compression_page_');
  final source = File('${root.path}/source.mp4')
    ..writeAsBytesSync(List.filled(100, 1));
  final engine = FakeCompressionEngine();
  final controller = CompressionTestController(
    engine: engine,
    workspace: CompressionTestWorkspace(temporaryDirectory: () async => root),
  );
  final previousPlatform = VideoPlayerPlatform.instance;
  VideoPlayerPlatform.instance = LocalVideoPlatform();
  final settings = PlaybackSettingsService(directory: root);
  await tester.runAsync(settings.load);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await flushCompressionPage(tester);
    var closed = false;
    unawaited(controller.close().then((_) => closed = true));
    await flushCompressionPage(tester);
    expect(closed, isTrue);
    VideoPlayerPlatform.instance = previousPlatform;
    settings.dispose();
    root.deleteSync(recursive: true);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    PlaybackScope(
      settings: settings,
      coordinator: PlaybackCoordinator(),
      onlineVisible: false,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CompressionTestPage(
                    tasks: [compressionTask(source.path)],
                    controller: controller,
                  ),
                ),
              ),
              child: const Text('打开测试'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开测试'));
  await flushCompressionPage(tester);
  return (controller: controller, engine: engine, source: source);
}

Future<void> flushCompressionPage(WidgetTester tester) async {
  for (var frame = 0; frame < 24; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> selectCompressionEpisode(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('测试剧').last);
  await flushCompressionPage(tester);
  await tester.tap(find.byType(DropdownButtonFormField<String>).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('第1集').last);
  await flushCompressionPage(tester);
  final controller = tester
      .widget<CompressionTestPage>(find.byType(CompressionTestPage))
      .controller!;
  for (var attempt = 0; attempt < 10 && controller.busy; attempt++) {
    await flushCompressionPage(tester);
  }
  expect(controller.busy, isFalse, reason: controller.status);
}
