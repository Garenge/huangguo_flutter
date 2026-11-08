import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/storage_usage.dart';
import 'package:huangguo_flutter/services/download_service.dart';
import 'package:huangguo_flutter/services/download_storage_controller.dart';
import 'package:huangguo_flutter/services/storage_usage_service.dart';

import 'helpers/download_page_fixture.dart';

class _ControlledStorage extends StorageUsageService {
  final reads = <Completer<StorageUsage>>[];
  final appReads = <Completer<StorageUsage>>[];

  @override
  Future<StorageUsage> read(DownloadService downloads) {
    final pending = Completer<StorageUsage>();
    appReads.add(pending);
    return pending.future;
  }

  @override
  Future<StorageUsage> readDownloadUsage(DownloadService downloads) {
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

  testWidgets('app scans on activation but not on periodic refresh', (
    tester,
  ) async {
    controller.setActive(true);
    service.reads.last.complete(const StorageUsage());
    service.appReads.last.complete(const StorageUsage(appBytes: 100));
    await tester.pump();
    expect(controller.appUsage?.appBytes, 100);
    await tester.pump(const Duration(seconds: 20));
    expect(service.appReads.length, 1);
    service.reads.last.complete(const StorageUsage());
    await tester.pump();
    controller.setActive(false);
    controller.setActive(true);
    expect(service.appReads.length, 2);
    service.appReads.last.complete(const StorageUsage(appBytes: 120));
    service.reads.last.complete(const StorageUsage());
    await tester.pump();
    expect(controller.appUsage?.appBytes, 120);
    controller.setActive(false);
  });

  test(
    'app failures and unavailable results preserve last usable size',
    () async {
      controller.updateAppUsage(const StorageUsage(appBytes: 100));
      final refresh = controller.refreshAppUsage();
      expect(controller.appRefreshing, isTrue);
      service.appReads.last.completeError(StateError('unreadable'));
      await refresh;
      expect(controller.appUsage?.appBytes, 100);
      expect(controller.appRefreshFailed, isTrue);
      controller.updateAppUsage(const StorageUsage());
      expect(controller.appUsage?.appBytes, 100);
      expect(controller.appRefreshFailed, isTrue);
      controller.updateAppUsage(
        const StorageUsage(appBytes: 80, failedPaths: ['/blocked']),
      );
      expect(controller.appUsage?.isPartial, isTrue);
      expect(controller.appRefreshFailed, isFalse);
    },
  );

  test(
    'management result takes precedence over older in-flight app scan',
    () async {
      final refresh = controller.refreshAppUsage();
      await controller.refreshAppUsage();
      expect(service.appReads.length, 1);
      controller.updateAppUsage(const StorageUsage(appBytes: 200));
      service.appReads.last.complete(const StorageUsage(appBytes: 100));
      await refresh;
      expect(controller.appUsage?.appBytes, 200);
      expect(controller.appRefreshFailed, isFalse);
    },
  );

  test(
    'app scan completion after disposal does not notify listeners',
    () async {
      final detached = DownloadStorageController(downloads, service);
      var notifications = 0;
      detached.addListener(() => notifications++);
      final refresh = detached.refreshAppUsage();
      detached.dispose();
      service.appReads.last.complete(const StorageUsage(appBytes: 100));
      await refresh;
      expect(notifications, 1);
      expect(detached.appUsage, isNull);
    },
  );

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
