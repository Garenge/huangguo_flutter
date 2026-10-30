import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/playback_settings_service.dart';

void main() {
  test(
    'manual speed and pause preference survive service recreation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'playback_settings',
      );
      addTearDown(() => directory.delete(recursive: true));
      final settings = PlaybackSettingsService(directory: directory);
      expect(settings.speed, 1);
      expect(settings.pauseOnLeave, isTrue);
      await settings.setSpeed(1.5);
      await settings.setPauseOnLeave(false);
      await settings.setSpeed(3);
      final restored = PlaybackSettingsService(directory: directory);
      await restored.load();
      expect(restored.speed, 3);
      expect(restored.pauseOnLeave, isFalse);
      settings.dispose();
      restored.dispose();
    },
  );

  test('invalid stored values retain safe defaults', () async {
    final directory = await Directory.systemTemp.createTemp('playback_invalid');
    addTearDown(() => directory.delete(recursive: true));
    await File(
      '${directory.path}/playback_settings.json',
    ).writeAsString('{"speed":-2,"pauseOnLeave":"false"}');
    final settings = PlaybackSettingsService(directory: directory);
    await settings.load();
    expect(settings.speed, 1);
    expect(settings.pauseOnLeave, isTrue);
    await settings.setSpeed(8);
    expect(settings.speed, 1);
    settings.dispose();
  });
}
