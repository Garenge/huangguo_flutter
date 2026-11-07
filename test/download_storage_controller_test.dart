import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/storage_usage.dart';
import 'package:huangguo_flutter/services/download_service.dart';
import 'package:huangguo_flutter/services/download_storage_controller.dart';
import 'package:huangguo_flutter/services/storage_usage_service.dart';

import 'helpers/download_page_fixture.dart';

class _ControlledStorage extends StorageUsageService {
  final reads = <Completer<StorageUsage>>[];

  @override
  Future<StorageUsage> read(DownloadService downloads) {
    final result = Completer<StorageUsage>();
    reads.add(result);
    return result.future;
  }
}

void main() {
  late TestAlbumApi api;
  late TestDownloadService downloads;
  late _ControlledStorage service;
  late DownloadStorageController controller;

  setUp(() {
    api = TestAlbumApi();
    downloads = TestDownloadService(api, albumTasks('A', 2));
    service = _ControlledStorage();
    controller = DownloadStorageController(downloads, service);
  });
  tearDown(() {
    controller.dispose();
    downloads.dispose();
    api.dispose();
  });

  testWidgets(
    'coalesces changes during scan and ignores progress-only notifications',
    (tester) async {
      controller.setActive(true);
      expect(service.reads.length, 1);
      downloads.notifyListeners();
      await tester.pump(const Duration(seconds: 3));
      service.reads.first.complete(const StorageUsage(appBytes: 100));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(service.reads.length, 1);
      downloads.removeAlbum('A');
      await tester.pump(const Duration(seconds: 3));
      expect(service.reads.length, 2);
      await controller.refresh();
      service.reads.last.complete(const StorageUsage(appBytes: 0));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(service.reads.length, 3);
      service.reads.last.complete(const StorageUsage(appBytes: 0));
      await tester.pump();
      expect(controller.usage?.appBytes, 0);
      controller.setActive(false);
    },
  );

  testWidgets('leaving completed tab cancels scheduled and periodic refresh', (
    tester,
  ) async {
    controller.setActive(true);
    service.reads.first.complete(const StorageUsage());
    await tester.pump();
    downloads.removeAlbum('A');
    controller.setActive(false);
    await tester.pump(const Duration(seconds: 40));
    expect(service.reads.length, 1);
    controller.setActive(true);
    expect(service.reads.length, 2);
    service.reads.last.complete(const StorageUsage());
    await tester.pump();
      controller.setActive(false);
  });
}
