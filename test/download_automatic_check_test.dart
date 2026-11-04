import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/download_page_fixture.dart';

void main() {
  testWidgets('initial check visits every album without no-update snacks', (
    tester,
  ) async {
    final api = TestAlbumApi();
    await mountDownloads(tester, albumApi: api);
    expect(api.checkedAlbums, ['A', 'B', 'C']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('periodic checks revisit every album after thirty minutes', (
    tester,
  ) async {
    final api = TestAlbumApi();
    await mountDownloads(tester, albumApi: api);
    await tester.pump(const Duration(minutes: 30));
    await tester.pumpAndSettle();
    expect(api.checkedAlbums, ['A', 'B', 'C', 'A', 'B', 'C']);
  });

  testWidgets('background skips timer and resume checks overdue albums', (
    tester,
  ) async {
    final api = TestAlbumApi();
    await mountDownloads(tester, albumApi: api);
    _background(tester);
    await tester.pump(const Duration(minutes: 30));
    expect(api.checkedAlbums, ['A', 'B', 'C']);
    _resume(tester);
    await tester.pumpAndSettle();
    expect(api.checkedAlbums, ['A', 'B', 'C', 'A', 'B', 'C']);
  });

  testWidgets('resume respects the per-album interval', (tester) async {
    final api = TestAlbumApi();
    await mountDownloads(tester, albumApi: api);
    _background(tester);
    _resume(tester);
    await tester.pumpAndSettle();
    expect(api.checkedAlbums, ['A', 'B', 'C']);
  });

  testWidgets('queued downloads defer automatic checks until an idle trigger', (
    tester,
  ) async {
    final api = TestAlbumApi();
    final service = await mountDownloads(
      tester,
      albumApi: api,
      hasPendingTasks: true,
    );
    expect(api.checkedAlbums, isEmpty);
    await tester.pump(const Duration(minutes: 30));
    expect(api.checkedAlbums, isEmpty);
    service.hasPendingTasks = false;
    _background(tester);
    _resume(tester);
    await tester.pumpAndSettle();
    expect(api.checkedAlbums, ['A', 'B', 'C']);
  });

  testWidgets('failed album does not prevent checking later albums', (
    tester,
  ) async {
    final api = TestAlbumApi()
      ..onFetchDetail = (id) async {
        if (id == 'A') throw StateError('test detail request failure');
        return '';
      };
    await mountDownloads(tester, albumApi: api);
    expect(api.checkedAlbums, ['A', 'B', 'C']);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('background during a batch stops remaining album requests', (
    tester,
  ) async {
    final api = TestAlbumApi()
      ..onFetchDetail = (id) async {
        if (id == 'A') _background(tester);
        return '';
      };
    await mountDownloads(tester, albumApi: api);
    expect(api.checkedAlbums, ['A']);
    _resume(tester);
    await tester.pumpAndSettle();
    expect(api.checkedAlbums, ['A', 'B', 'C']);
  });

  testWidgets('resume during a batch does not start overlapping checks', (
    tester,
  ) async {
    final api = TestAlbumApi()
      ..onFetchDetail = (_) async {
        _background(tester);
        _resume(tester);
        return '';
      };
    await mountDownloads(tester, albumApi: api);
    expect(api.checkedAlbums, ['A', 'B', 'C']);
    expect(tester.takeException(), isNull);
  });
}

void _background(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void _resume(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}
