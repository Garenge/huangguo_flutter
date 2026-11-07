import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/video_conversion_service.dart';

import 'helpers/download_page_fixture.dart';

void main() {
  for (final batch in [false, true]) {
    test(
      '${batch ? "batch" : "single"} conversion reports reuse without converting or deleting',
      () async {
        final root = Directory.systemTemp.createTempSync('conversion_reuse');
        final api = TestAlbumApi();
        final tasks = albumTasks('A', 1);
        final downloads = TestDownloadService(api, tasks);
        final logs = <String>[];
        final originalPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) =>
            logs.add(message ?? '');
        addTearDown(() {
          debugPrint = originalPrint;
          downloads.dispose();
          api.dispose();
          root.deleteSync(recursive: true);
        });
        final source = File('${root.path}/playlist.m3u8')
          ..writeAsStringSync('#EXTM3U\n');
        final mp4 = File('${root.path}/video.mp4')
          ..writeAsBytesSync(List.filled(400, 1));
        tasks.single.filePath = source.path;
        tasks.single.mp4Path = mp4.path;
        final conversion = VideoConversionService(downloads);
        if (batch) {
          final result = await conversion.convertTasks(tasks);
          expect(result.skippedCount, 1);
          expect(result.convertedCount, 0);
          expect(result.failedCount, 0);
        } else {
          final result = await conversion.exportTask(tasks.single);
          expect(result.success, isTrue);
          expect(result.outputPath, mp4.path);
        }
        expect(logs.join('\n'), contains('复用已有 MP4，跳过转换'));
        expect(logs.join('\n'), contains('剧集=测试剧A / A 第1集'));
        expect(logs.join('\n'), contains('400 B (400 B)'));
        expect(logs.join('\n'), isNot(contains('logBefore:')));
        expect(source.existsSync(), isTrue);
        expect(mp4.lengthSync(), 400);
      },
    );
  }
}
