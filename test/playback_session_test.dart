import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/playback_coordinator.dart';
import 'package:huangguo_flutter/services/playback_session.dart';
import 'package:huangguo_flutter/services/playback_settings_service.dart';
import 'package:huangguo_flutter/widgets/playback_settings_tile.dart';

import 'helpers/test_video_controller.dart';

class MemoryPlaybackSettings extends PlaybackSettingsService {
  @override
  Future<void> load() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryPlaybackSettings settings;
  late PlaybackCoordinator coordinator;
  late PlaybackSession online;
  late TestVideoController controller;

  setUp(() async {
    settings = MemoryPlaybackSettings();
    coordinator = PlaybackCoordinator();
    online = PlaybackSession(settings, coordinator);
    controller = TestVideoController(playing: false);
    await online.begin();
    await online.attach(controller);
    await online.play();
  });

  tearDown(() async {
    online.dispose();
    settings.dispose();
    await controller.dispose();
  });

  test('leaving pauses by default and returning does not autoplay', () async {
    online.setVisible(false);
    expect(controller.value.isPlaying, isFalse);
    online.setVisible(true);
    await online.play();
    expect(controller.value.isPlaying, isFalse);
    await online.play(explicit: true);
    expect(controller.value.isPlaying, isTrue);
  });

  test(
    'disabled preference continues playback on hidden and covered pages',
    () {
      settings.pauseOnLeave = false;
      online.setVisible(false);
      online.setRouteVisible(false);
      expect(controller.value.isPlaying, isTrue);
      expect(online.canPlay, isTrue);
    },
  );

  test('loading episode cannot autoplay after leaving and returning', () async {
    online.controller = null;
    online.setVisible(false);
    online.setVisible(true);
    await online.attach(controller);
    await controller.pause();
    await online.play();
    expect(controller.value.isPlaying, isFalse);
  });

  test(
    'local ownership stops online regardless of continue preference',
    () async {
      settings.pauseOnLeave = false;
      final local = PlaybackSession(settings, coordinator);
      final localController = TestVideoController(playing: false);
      await local.begin();
      expect(controller.value.isPlaying, isFalse);
      await local.attach(localController);
      await local.play();
      expect(localController.value.isPlaying, isTrue);
      await online.play();
      expect(controller.value.isPlaying, isFalse);
      local.dispose();
      await localController.dispose();
      expect(controller.value.isPlaying, isFalse);
    },
  );

  test('late online initialization cannot steal local ownership', () async {
    online.controller = null;
    final local = PlaybackSession(settings, coordinator);
    await local.begin();
    await online.attach(controller);
    await controller.pause();
    await online.play();
    expect(controller.value.isPlaying, isFalse);
    local.dispose();
  });

  test(
    'episode controller replacement restores remembered manual speed',
    () async {
      settings.speed = 3;
      final next = TestVideoController(playing: false);
      await online.attach(next);
      expect(next.value.playbackSpeed, 3);
      await next.setPlaybackSpeed(2);
      expect(settings.speed, 3);
      await online.attach(controller);
      expect(controller.value.playbackSpeed, 3);
      await next.dispose();
    },
  );

  test(
    'background always pauses without automatic foreground recovery',
    () async {
      settings.pauseOnLeave = false;
      online.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(controller.value.isPlaying, isFalse);
      online.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await online.play();
      expect(controller.value.isPlaying, isFalse);
    },
  );

  testWidgets('pause setting defaults on and persists toggling off', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('playback_tile');
    final stored = PlaybackSettingsService(directory: directory);
    await tester.runAsync(stored.load);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlaybackSettingsTile(settings: stored)),
      ),
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.runAsync(() async {
      await stored.load();
      // Wait for the serialized persistence triggered by the tap.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
    stored.dispose();
    directory.deleteSync(recursive: true);
  });
}
