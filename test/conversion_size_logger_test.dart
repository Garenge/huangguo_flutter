import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/conversion_size_logger.dart';

void main() {
  late Directory root;
  late List<String> logs;
  late DebugPrintCallback originalPrint;
  setUp(() {
    root = Directory.systemTemp.createTempSync('conversion_size_log');
    logs = [];
    originalPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
  });
  tearDown(() {
    debugPrint = originalPrint;
    root.deleteSync(recursive: true);
  });

  ConversionSizeLogger logger() => ConversionSizeLogger(
    label: '测试剧 / 第1集',
    playlistPath: '${root.path}/playlist.m3u8',
    outputPath: '${root.path}/video.mp4',
  );

  int createSource() {
    final playlist = File('${root.path}/playlist.m3u8')
      ..writeAsStringSync('#EXTM3U\n#EXTINF:2,\n00000.ts\n');
    File('${root.path}/00000.ts').writeAsBytesSync(List.filled(100, 1));
    return playlist.lengthSync() + 100;
  }

  test(
    'before and after use the pre-conversion snapshot with exact growth',
    () async {
      final bytes = createSource();
      final sizeLogger = logger();
      await sizeLogger.logBefore();
      expect(logs.single, contains('源资源=$bytes B ($bytes B)'));
      expect(logs.single, contains('分片=1'));
      File('${root.path}/00000.ts').deleteSync();
      File(
        '${root.path}/video.mp4',
      ).writeAsBytesSync(List.filled(bytes * 2, 1));
      await sizeLogger.logAfter();
      expect(logs.last, contains('剧集=测试剧 / 第1集'));
      expect(logs.last, contains('变化=+$bytes B ($bytes B)'));
      expect(logs.last, contains('变化率=+100.00%'));
      expect(logs.last, contains('体积倍数=2.00x'));
    },
  );

  test('shrinking output reports negative delta and percentage', () async {
    final bytes = createSource();
    final sizeLogger = logger();
    await sizeLogger.logBefore();
    File('${root.path}/video.mp4').writeAsBytesSync(List.filled(bytes ~/ 2, 1));
    await sizeLogger.logAfter();
    expect(logs.last, contains('变化=-'));
    expect(logs.last, contains('变化率=-'));
    expect(logs.last, contains('体积倍数=0.50x'));
  });

  test('statistics errors do not throw or produce misleading growth', () async {
    final sizeLogger = logger();
    await sizeLogger.logBefore();
    File('${root.path}/video.mp4').writeAsBytesSync(List.filled(200, 1));
    await sizeLogger.logAfter();
    expect(logs.last, contains('源资源=暂不可用'));
    expect(logs.last, contains('MP4=200 B (200 B)'));
    expect(logs.last, contains('变化率=暂不可用'));
    expect(logs.last, contains('体积倍数=暂不可用'));
    expect(logs.join('\n'), contains('conversion_size_logger.dart'));
  });

  test(
    'reused output is clearly identified without a conversion comparison',
    () async {
      File('${root.path}/video.mp4').writeAsBytesSync(List.filled(256, 1));
      await ConversionSizeLogger.logReused(
        label: '第1集',
        outputPath: '${root.path}/video.mp4',
      );
      expect(logs.single, contains('复用已有 MP4，跳过转换'));
      expect(logs.single, contains('256 B (256 B)'));
      expect(logs.single, isNot(contains('变化率=')));
    },
  );

  test(
    'zero source size reports an unavailable ratio instead of infinity',
    () async {
      File('${root.path}/playlist.m3u8').writeAsStringSync('');
      final sizeLogger = logger();
      await sizeLogger.logBefore();
      File('${root.path}/video.mp4').writeAsBytesSync([1, 2, 3]);
      await sizeLogger.logAfter();
      expect(logs.last, contains('源资源=0 B (0 B)'));
      expect(logs.last, contains('MP4=3 B (3 B)'));
      expect(logs.last, contains('变化率=暂不可用'));
      expect(logs.last, contains('体积倍数=暂不可用'));
    },
  );
}
