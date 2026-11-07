import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/models/drama.dart';
import 'package:huangguo_flutter/models/episode.dart';
import 'package:huangguo_flutter/services/download_service.dart';
import 'package:huangguo_flutter/services/huangguo_api.dart';

const dedupDrama = Drama(id: '1', name: '测试剧', pic: '', remark: '');
const dedupEpisode = Episode(name: '第1集', url: '/play/1/1/', ep: '1');

class _TestApi extends HuangguoApi {
  @override
  Future<String> fetchPlayPage(String url) async => '';
}

class DownloadDeduplicationFixture {
  final Directory directory;
  final HuangguoApi api = _TestApi();
  late final DownloadService service = DownloadService(api);

  DownloadDeduplicationFixture(this.directory);

  String get root => '${directory.path}/huangguo_downloads';
  String get episodeDirectory => '$root/测试剧 (1)/第1集';

  static Future<DownloadDeduplicationFixture> create() async {
    final fixture = DownloadDeduplicationFixture(
      await Directory.systemTemp.createTemp('download_deduplication_'),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => fixture.directory.path,
        );
    return fixture;
  }

  Future<File> resource(String name) async {
    final file = File('$episodeDirectory/$name');
    await file.parent.create(recursive: true);
    return file.writeAsString('test resource');
  }

  Future<void> seed(
    DownloadStatus status, {
    String? filePath,
    String? mp4Path,
  }) async {
    final task = DownloadTask(
      id: 'existing',
      dramaId: dedupDrama.id,
      dramaName: dedupDrama.name,
      episodeName: dedupEpisode.name,
      episodeUrl: dedupEpisode.url,
      ep: dedupEpisode.ep,
      status: status,
      filePath: filePath,
      mp4Path: mp4Path,
    );
    final metadata = File('$root/.download_tasks.json');
    await metadata.parent.create(recursive: true);
    await metadata.writeAsString(jsonEncode([task.toJson(downloadRoot: root)]));
    await service.init();
  }

  Future<void> dispose() async {
    service.dispose();
    api.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await directory.delete(recursive: true);
  }
}
