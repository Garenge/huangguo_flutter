import 'dart:async';
import 'dart:io';

import 'package:huangguo_flutter/models/compression_test.dart';
import 'package:huangguo_flutter/models/download_task.dart';
import 'package:huangguo_flutter/services/compression_test_engine.dart';

class FakeCompressionEngine implements CompressionTestEngine {
  static const preset = CompressionPreset('清晰优先', 'libx265', 20);
  static const sourceMedia = CompressionMedia(
    seconds: 60,
    width: 1920,
    height: 1080,
    hasAudio: true,
  );
  CompressionMedia? outputMedia;
  CompressionMedia _compressedMedia = sourceMedia;
  Completer<void>? compression;
  Completer<void>? started;
  bool cancelled = false;
  int compressCount = 0;
  int remuxCount = 0;
  int outputBytes = 40;
  int verifyCount = 0;
  double? lastRemuxSeconds;
  @override
  List<String> get unavailableReasons => [];

  @override
  Future<List<CompressionPreset>> presets() async => [preset];

  @override
  Future<List<CompressionPreset>> verifyPresets(
    String source,
    CompressionMedia media,
    String directory,
  ) async {
    verifyCount++;
    return [preset];
  }

  @override
  Future<CompressionMedia> inspect(String path) async {
    if (RegExp(r'compressed_\d+\.mp4$').hasMatch(path)) {
      return outputMedia ?? _compressedMedia;
    }
    if (path.endsWith('sample_original.mp4')) {
      return const CompressionMedia(
        seconds: 30,
        width: 1920,
        height: 1080,
        hasAudio: true,
      );
    }
    return sourceMedia;
  }

  @override
  Future<void> remux(String source, String output, {double? seconds}) async {
    remuxCount++;
    lastRemuxSeconds = seconds;
    await File(output).writeAsBytes(List.filled(90, 1));
  }

  @override
  Future<void> compress(
    String source,
    String output,
    CompressionPreset preset,
    CompressionMedia media,
    void Function(CompressionEncodingProgress) onProgress, {
    int sourceBytes = 0,
  }) async {
    cancelled = false;
    compressCount++;
    _compressedMedia = media;
    started?.complete();
    await File(output).writeAsBytes(List.filled(outputBytes, 2));
    onProgress(
      CompressionEncodingProgress(seconds: media.seconds / 2, speed: 2),
    );
    await compression?.future;
    if (cancelled) throw const CompressionCancelled();
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    final pending = compression;
    if (pending != null && !pending.isCompleted) pending.complete();
  }
}

DownloadTask compressionTask(String path, {String id = 'one'}) => DownloadTask(
  id: id,
  dramaId: 'drama',
  dramaName: '测试剧',
  episodeName: '第1集',
  episodeUrl: '/episode/1',
  ep: '1',
  status: DownloadStatus.completed,
  filePath: path,
);
