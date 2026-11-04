import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/download_catalog.dart';
import 'package:huangguo_flutter/services/download_settings_service.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('download_settings');
  });
  tearDown(() => directory.delete(recursive: true));

  test('missing settings default to recent downloads', () async {
    final settings = DownloadSettingsService(directory: directory);
    await settings.load();
    expect(settings.sortMode, DownloadSortMode.recent);
  });

  for (final mode in DownloadSortMode.values) {
    test('${mode.name} survives service recreation', () async {
      await DownloadSettingsService(directory: directory).setSortMode(mode);
      final restored = DownloadSettingsService(directory: directory);
      await restored.load();
      expect(restored.sortMode, mode);
    });
  }

  for (final data in [
    '{"sortMode":"unknown"}',
    '{"sortMode":2}',
    '{}',
    'not json',
    '[]',
  ]) {
    test('invalid settings fall back to recent: $data', () async {
      await File(
        '${directory.path}/download_settings.json',
      ).writeAsString(data);
      final settings = DownloadSettingsService(directory: directory);
      await settings.load();
      expect(settings.sortMode, DownloadSortMode.recent);
    });
  }

  test(
    'rapid changes persist the last selection even during loading',
    () async {
      await File(
        '${directory.path}/download_settings.json',
      ).writeAsString('{"sortMode":"count"}');
      final settings = DownloadSettingsService(directory: directory);
      await Future.wait([
        settings.setSortMode(DownloadSortMode.name),
        settings.setSortMode(DownloadSortMode.count),
        settings.setSortMode(DownloadSortMode.recent),
      ]);
      final restored = DownloadSettingsService(directory: directory);
      await restored.load();
      expect(restored.sortMode, DownloadSortMode.recent);
    },
  );
}
