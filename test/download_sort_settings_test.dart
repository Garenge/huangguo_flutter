import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/services/download_catalog.dart';
import 'package:huangguo_flutter/services/download_settings_service.dart';

import 'helpers/download_page_fixture.dart';

class _TrackedSettings extends DownloadSettingsService {
  _TrackedSettings(this.storage);

  final Map<String, DownloadSortMode> storage;

  @override
  Future<void> load() async {
    sortMode = storage['sortMode'] ?? DownloadSortMode.recent;
  }

  @override
  Future<void> setSortMode(DownloadSortMode mode) async {
    storage['sortMode'] = sortMode = mode;
  }
}

void main() {
  testWidgets('default recent mode places the newest album first', (
    tester,
  ) async {
    final tasks = [...albumTasks('A', 1), ...albumTasks('B', 1)];
    final newer = tasks.last.toJson();
    newer['createdAt'] = DateTime(2026, 11).toIso8601String();
    tasks[1] = DownloadTask.fromJson(newer);
    await mountDownloads(
      tester,
      downloadSettings: _TrackedSettings({}),
      tasks: tasks,
    );
    expect(find.text('最近下载'), findsOneWidget);
    expect(
      tester.getTopLeft(albumHeader('B')).dy,
      lessThan(tester.getTopLeft(albumHeader('A')).dy),
    );
  });

  for (final mode in DownloadSortMode.values) {
    testWidgets('${mode.name} selection persists and restores on a new page', (
      tester,
    ) async {
      final storage = <String, DownloadSortMode>{};
      final tasks = [...albumTasks('A', 1), ...albumTasks('B', 2)];
      await mountDownloads(
        tester,
        downloadSettings: _TrackedSettings(storage),
        tasks: tasks,
      );
      await tester.tap(find.byTooltip('排序方式'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(mode.label).last);
      await tester.pumpAndSettle();
      expect(storage['sortMode'], mode);
      await tester.pumpWidget(const SizedBox());
      await mountDownloads(
        tester,
        downloadSettings: _TrackedSettings(storage),
        tasks: tasks,
      );
      expect(find.text(mode.label), findsOneWidget);
      final first = mode == DownloadSortMode.count ? 'B' : 'A';
      final second = first == 'A' ? 'B' : 'A';
      expect(
        tester.getTopLeft(albumHeader(first)).dy,
        lessThan(tester.getTopLeft(albumHeader(second)).dy),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
