import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/models/drama.dart';
import 'package:huangguo_flutter/models/episode.dart';
import 'package:huangguo_flutter/services/download_service.dart';
import 'package:huangguo_flutter/services/huangguo_api.dart';
import 'package:huangguo_flutter/widgets/player_download_button.dart';

const buttonDrama = Drama(id: 'button', name: '按钮测试剧', pic: '', remark: '');
const buttonEpisode = Episode(name: '第1集', url: '/video/1', ep: '1');

class ButtonDownloads extends DownloadService {
  ButtonDownloads(super.api);
  final items = <DownloadTask>[];
  Completer<void>? adding;
  bool failAdd = false;
  int adds = 0;
  int resumes = 0;

  @override
  DownloadTask? taskForEpisode(String dramaId, String ep) {
    for (final task in items) {
      if (task.dramaId == dramaId && task.ep == ep) return task;
    }
    return null;
  }

  @override
  bool isResourceDownloaded(Drama drama, Episode episode) {
    final task = taskForEpisode(drama.id, episode.ep);
    return task != null && isEpisodeDownloadedForTask(task);
  }

  @override
  Future<DownloadTask?> addTask(Drama drama, Episode episode) async {
    adds++;
    await adding?.future;
    if (failAdd) throw StateError('模拟添加失败');
    final task = DownloadTask(
      id: episode.ep,
      dramaId: drama.id,
      dramaName: drama.name,
      episodeName: episode.name,
      episodeUrl: episode.url,
      ep: episode.ep,
    );
    items.add(task);
    changed();
    return task;
  }

  @override
  Future<void> resumeTask(String taskId) async {
    resumes++;
    items.firstWhere((task) => task.id == taskId).status =
        DownloadStatus.pending;
    changed();
  }

  void changed() => notifyListeners();
}

Future<ButtonDownloads> setupDownloadButton(WidgetTester tester) async {
  final api = HuangguoApi();
  final service = ButtonDownloads(api);
  final root = Directory.systemTemp.createTempSync('player_button_');
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    service.dispose();
    api.dispose();
    root.deleteSync(recursive: true);
  });
  await mountDownloadButton(tester, service);
  return service;
}

Future<void> mountDownloadButton(
  WidgetTester tester,
  ButtonDownloads service, {
  Episode episode = buttonEpisode,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        actions: [
          PlayerDownloadButton(
            key: ValueKey(episode.ep),
            service: service,
            drama: buttonDrama,
            episode: episode,
          ),
        ],
      ),
    ),
  ),
);

File completedButtonFile() {
  final root = Directory.systemTemp.createTempSync('player_button_file_');
  addTearDown(() => root.deleteSync(recursive: true));
  return File('${root.path}/video.mp4')..writeAsBytesSync([0]);
}
