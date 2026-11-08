import 'dart:io';

import '../models/compression_test.dart';
import '../models/download_task.dart';
import 'compression_test_engine.dart';
import 'compression_test_workspace.dart';

class CompressionTestSource {
  CompressionTestSource(this.engine, this.workspace, this.checkOpen);

  final CompressionTestEngine engine;
  final CompressionTestWorkspace workspace;
  final void Function() checkOpen;
  String? fullPath;
  CompressionMedia? fullMedia;
  int fullBytes = 0;
  String? path;
  CompressionMedia? media;
  int bytes = 0;

  void reset() {
    fullPath = path = null;
    fullMedia = media = null;
    fullBytes = bytes = 0;
  }

  Future<void> prepare(
    DownloadTask task,
    CompressionTestRange range,
    bool Function() cancelled,
    void Function(String) onStatus,
  ) async {
    final original = CompressionTestWorkspace.sourcePath(task);
    if (original == null) throw StateError('本地文件已丢失');
    final copy = await workspace.copySource(original, cancelled: cancelled);
    checkOpen();
    var playable = copy.path;
    if (playable.toLowerCase().endsWith('.m3u8')) {
      onStatus('正在准备原视频预览');
      playable = '${workspace.directory.path}/original.mp4';
      await engine.remux(copy.path, playable);
    }
    checkOpen();
    final inspected = await engine.inspect(playable);
    checkOpen();
    fullPath = playable;
    fullMedia = inspected;
    fullBytes = copy.bytes;
    await selectRange(range);
  }

  Future<void> selectRange(CompressionTestRange range) async {
    path = null;
    media = null;
    bytes = 0;
    await _removePrevious();
    checkOpen();
    final original = fullPath;
    final originalMedia = fullMedia;
    if (original == null || originalMedia == null) return;
    var selected = original;
    if (range == CompressionTestRange.sample && originalMedia.seconds > 30) {
      selected = '${workspace.directory.path}/sample_original.mp4';
      await engine.remux(original, selected, seconds: 30);
    }
    checkOpen();
    final inspected = selected == original
        ? originalMedia
        : await engine.inspect(selected);
    if (selected != original) {
      inspected.validateAgainst(
        CompressionMedia(
          seconds: 30,
          width: originalMedia.width,
          height: originalMedia.height,
          hasAudio: originalMedia.hasAudio,
        ),
      );
    }
    checkOpen();
    path = selected;
    media = inspected;
    bytes = range == CompressionTestRange.full
        ? fullBytes
        : await File(selected).length();
  }

  Future<void> _removePrevious() async {
    for (final name in ['sample_original.mp4', 'compressed.mp4']) {
      final file = File('${workspace.directory.path}/$name');
      if (await file.exists()) await file.delete();
    }
  }
}
