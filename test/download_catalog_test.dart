import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/services/download_catalog.dart';

DownloadTask task({
  required String id,
  required String dramaName,
  required String episodeName,
  required String ep,
  DateTime? createdAt,
}) {
  return DownloadTask(
    id: id,
    dramaId: id,
    dramaName: dramaName,
    episodeName: episodeName,
    episodeUrl: '/$id',
    ep: ep,
    createdAt: createdAt,
    status: DownloadStatus.completed,
  );
}

void main() {
  final tasks = [
    task(id: '1', dramaName: '庆余年', episodeName: '第一集', ep: '1'),
    task(id: '1', dramaName: '庆余年', episodeName: '第二集', ep: '2'),
    task(id: '3', dramaName: '爱情公寓', episodeName: '第一集', ep: '1'),
  ];

  test('filters by Chinese name, pinyin, initials, and episode number', () {
    expect(DownloadCatalog.filter(tasks, '庆余年'), hasLength(2));
    expect(DownloadCatalog.filter(tasks, 'qingy'), hasLength(2));
    expect(DownloadCatalog.filter(tasks, 'qy'), hasLength(2));
    expect(DownloadCatalog.filter(tasks, '第二'), hasLength(1));
    expect(DownloadCatalog.filter(tasks, '2'), hasLength(1));
  });

  test('sorts album groups by pinyin name and episode count', () {
    final byName = DownloadCatalog.groupAndSort(tasks, DownloadSortMode.name);
    expect(byName.keys.toList(), ['爱情公寓 (3)', '庆余年 (1)']);

    final byCount = DownloadCatalog.groupAndSort(tasks, DownloadSortMode.count);
    expect(byCount.keys.toList(), ['庆余年 (1)', '爱情公寓 (3)']);
  });
}
