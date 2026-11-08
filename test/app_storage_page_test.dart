import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/storage_usage.dart';
import 'package:huangguo_flutter/pages/app_storage_page.dart';
import 'package:huangguo_flutter/services/download_service.dart';
import 'package:huangguo_flutter/services/storage_usage_service.dart';

import 'helpers/download_page_fixture.dart';

class _ControlledStorage extends StorageUsageService {
  final reads = <Completer<StorageUsage>>[];

  @override
  Future<StorageUsage> read(DownloadService downloads) {
    final pending = Completer<StorageUsage>();
    reads.add(pending);
    return pending.future;
  }
}

void main() {
  late TestAlbumApi api;
  late TestDownloadService downloads;
  late _ControlledStorage service;

  setUp(() {
    api = TestAlbumApi();
    downloads = TestDownloadService(api, []);
    service = _ControlledStorage();
  });
  tearDown(() {
    downloads.dispose();
    api.dispose();
  });

  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: AppStoragePage(downloads: downloads, service: service),
    ),
  );

  testWidgets('shows loading and partial results on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester);
    expect(find.text('正在统计…'), findsOneWidget);
    final refresh = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == '重新统计 App 占用',
      ),
    );
    expect(refresh.onPressed, isNull);
    service.reads.last.complete(
      const StorageUsage(appBytes: 1024, failedPaths: ['/private/blocked']),
    );
    await tester.pumpAndSettle();
    expect(find.text('1.00 KB'), findsOneWidget);
    expect(find.textContaining('当前仅显示已读取部分'), findsOneWidget);
    await tester.tap(find.text('无法读取的路径（1）'));
    await tester.pumpAndSettle();
    expect(find.text('/private/blocked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed scan retries and preserves last result on refresh failure',
    (tester) async {
      await mount(tester);
      service.reads.last.completeError(StateError('scan failed'));
      await tester.pumpAndSettle();
      expect(find.text('未能读取应用占用，请重试。'), findsOneWidget);
      await tester.tap(find.text('重试统计'));
      await tester.pump();
      service.reads.last.complete(const StorageUsage(appBytes: 2048));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('重新统计 App 占用'));
      await tester.pump();
      service.reads.last.completeError(StateError('retry failed'));
      await tester.pumpAndSettle();
      expect(find.text('2.00 KB'), findsOneWidget);
      expect(find.text('重新统计失败，保留上次结果。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late scan completion after leaving never updates disposed page',
    (tester) async {
      await mount(tester);
      await tester.pumpWidget(const SizedBox());
      service.reads.last.complete(const StorageUsage(appBytes: 100));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
