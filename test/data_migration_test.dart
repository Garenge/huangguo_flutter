import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/data_migration_service.dart';

void main() {
  test('迁移旧地址和文件路径后生成通过的校验报告', () async {
    final documents = await Directory.systemTemp.createTemp(
      'huangguo_migration_',
    );
    addTearDown(() => documents.delete(recursive: true));

    final root = Directory('${documents.path}/huangguo_downloads');
    final episodeDir = Directory('${root.path}/测试剧 (1)/第1集');
    await episodeDir.create(recursive: true);
    await File('${episodeDir.path}/00000.ts').writeAsString('ts');
    await File(
      '${episodeDir.path}/playlist.m3u8',
    ).writeAsString('#EXTM3U\n#EXTINF:1,\n00000.ts\n#EXT-X-ENDLIST\n');

    await File('${root.path}/.download_tasks.json').writeAsString(
      jsonEncode([
        {
          'id': 'task-1',
          'dramaId': '1',
          'dramaName': '测试剧',
          'episodeName': '第1集',
          'episodeUrl': 'https://huangguoai.com/play/1/1/',
          'ep': '1',
          'status': 'completed',
          'progress': 1.0,
          'filePath': '${episodeDir.path}/playlist.m3u8',
          'errorMessage': null,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'totalBytes': 2,
          'downloadedBytes': 2,
          'm3u8Url': 'https://cdn.example.com/temporary.m3u8',
          'mp4Path': null,
        },
      ]),
    );
    await File('${documents.path}/playback_history.json').writeAsString(
      jsonEncode([
        {
          'id': 'history-1',
          'dramaName': '测试剧',
          'episodeName': '第1集',
          'ep': '1',
          'url': 'https://huangguoai.com/play/1/1/',
          'positionMs': 1000,
          'savedAt': '2026-01-01T00:00:00.000Z',
          'dramaId': '1',
        },
      ]),
    );

    await DataMigrationService(documents).run();

    final taskData =
        jsonDecode(
              await File('${root.path}/.download_tasks.json').readAsString(),
            )
            as List;
    final task = taskData.single as Map;
    expect(task['episodeUrl'], '/play/1/1/');
    expect(task['filePath'], '测试剧 (1)/第1集/playlist.m3u8');
    expect(task['m3u8Url'], isNull);

    final report =
        jsonDecode(
              await File(
                '${documents.path}/relative_path_migration.json',
              ).readAsString(),
            )
            as Map;
    expect(report['verified'], isTrue);
    expect(report['errors'], isEmpty);
  });
}
