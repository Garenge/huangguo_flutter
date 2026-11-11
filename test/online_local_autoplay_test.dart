import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/playback_session.dart';

import 'helpers/local_download_player_fixture.dart';
import 'helpers/online_local_playback_fixture.dart';
import 'helpers/test_video_controller.dart';

void main() {
  for (final name in ['episode.mp4', 'playlist.m3u8']) {
    testWidgets('selecting the same local $name after leaving plays again', (
      tester,
    ) async {
      final fixture = OnlineLocalFixture()..addTask(name: name);
      await fixture.mount(tester);
      expect(localPlayer(tester).controller!.value.isPlaying, isTrue);
      expect(fixture.platform.playCalls, isNotEmpty);

      fixture.onlineVisible = false;
      await fixture.render(tester);
      await pumpLocalPlayer(tester);
      expect(localPlayer(tester).controller!.value.isPlaying, isFalse);

      // A deliberate selection may carry exactly the same episode and position.
      final previousPlayCount = fixture.platform.playCalls.length;
      fixture.onlineVisible = true;
      fixture.playbackRequestId++;
      await fixture.render(tester);
      await pumpLocalPlayer(tester);
      expect(localPlayer(tester).controller!.value.isPlaying, isTrue);
      expect(fixture.platform.playCalls.length, greaterThan(previousPlayCount));
      expect(fixture.api.requests, isEmpty);
    });

    testWidgets(
      'returning to the local $name tab alone keeps playback paused',
      (tester) async {
        final fixture = OnlineLocalFixture()..addTask(name: name);
        await fixture.mount(tester);
        fixture.onlineVisible = false;
        await fixture.render(tester);
        await pumpLocalPlayer(tester);
        fixture.onlineVisible = true;
        await fixture.render(tester);
        await pumpLocalPlayer(tester);

        expect(localPlayer(tester).controller!.value.isPlaying, isFalse);
      },
    );

    testWidgets('selecting another local $name while opening tab autoplays', (
      tester,
    ) async {
      final fixture = OnlineLocalFixture()
        ..addTask(name: name)
        ..addTask(name: 'next_$name', ep: '2');
      await fixture.mount(tester);
      fixture.onlineVisible = false;
      await fixture.render(tester);
      await pumpLocalPlayer(tester);
      fixture.onlineVisible = true;
      fixture.playbackRequestId++;
      await fixture.render(tester, episode: localFirstEpisodes.last);
      await pumpLocalPlayer(tester);

      expect(localPlayer(tester).title, '第2集');
      expect(localPlayer(tester).controller!.value.isPlaying, isTrue);
      expect(fixture.api.requests, isEmpty);
    });

    testWidgets(
      'loading local $name cannot resume after leaving and returning',
      (tester) async {
        final fixture = OnlineLocalFixture()..addTask(name: name);
        final gate = Completer<void>();
        fixture.platform.initializationGate = gate;
        await fixture.mount(tester);
        fixture.onlineVisible = false;
        await fixture.render(tester);
        fixture.onlineVisible = true;
        await fixture.render(tester);
        gate.complete();
        await pumpLocalPlayer(tester);

        expect(localPlayer(tester).controller!.value.isInitialized, isTrue);
        expect(localPlayer(tester).controller!.value.isPlaying, isFalse);
      },
    );

    testWidgets('loading local $name cannot resume after backgrounding', (
      tester,
    ) async {
      final fixture = OnlineLocalFixture()..addTask(name: name);
      final gate = Completer<void>();
      fixture.platform.initializationGate = gate;
      await fixture.mount(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      gate.complete();
      await pumpLocalPlayer(tester);

      expect(localPlayer(tester).controller!.value.isPlaying, isFalse);
    });

    testWidgets('loading local $name cannot steal another player ownership', (
      tester,
    ) async {
      final fixture = OnlineLocalFixture()..addTask(name: name);
      final gate = Completer<void>();
      fixture.platform.initializationGate = gate;
      await fixture.mount(tester);
      final other = PlaybackSession(fixture.settings, fixture.coordinator);
      final controller = TestVideoController(playing: false);
      await other.begin();
      await other.attach(controller);
      await other.play();
      gate.complete();
      await pumpLocalPlayer(tester);

      expect(localPlayer(tester).controller!.value.isPlaying, isFalse);
      expect(controller.value.isPlaying, isTrue);
      other.dispose();
      await controller.dispose();
    });
  }
}
