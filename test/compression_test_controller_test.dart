import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/compression_test.dart';
import 'package:huangguo_flutter/services/compression_test_controller.dart';
import 'package:huangguo_flutter/services/compression_test_workspace.dart';

import 'helpers/compression_test_fixture.dart';

void main() {
  late Directory root;
  late File source;
  late FakeCompressionEngine engine;
  late CompressionTestController controller;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('compression_controller_');
    source = await File(
      '${root.path}/download.mp4',
    ).writeAsBytes(List.filled(100, 1));
    engine = FakeCompressionEngine();
    controller = CompressionTestController(
      engine: engine,
      workspace: CompressionTestWorkspace(temporaryDirectory: () async => root),
    );
    await controller.initialize();
  });

  tearDown(() async {
    await controller.close();
    controller.dispose();
    await root.delete(recursive: true);
  });

  test(
    'compresses a temporary copy and never updates download records',
    () async {
      final task = compressionTask(source.path);
      await controller.select(task);
      expect(controller.sourcePath, isNot(source.path));
      expect(controller.sourceBytes, 90);
      expect(controller.source.fullBytes, 100);
      expect(controller.media!.seconds, 30);
      await controller.compress(enginePreset);
      expect(controller.result!.bytes, 40);
      expect(controller.result!.preset, same(enginePreset));
      expect(task.filePath, source.path);
      expect(task.mp4Path, isNull);
      expect(await source.length(), 100);
      final session = controller.workspace.directory;
      await controller.close();
      expect(session.existsSync(), isFalse);
      expect(source.existsSync(), isTrue);
    },
  );

  test('source selection clears the last output and handles HLS', () async {
    await controller.select(compressionTask(source.path));
    await controller.compress(enginePreset);
    final oldOutput = controller.result!.path;
    final playlist = await File(
      '${root.path}/playlist.m3u8',
    ).writeAsString('#EXTM3U\n#EXTINF:60,\n00000.ts\n#EXT-X-ENDLIST\n');
    await File('${root.path}/00000.ts').writeAsBytes(List.filled(80, 1));
    await controller.select(compressionTask(playlist.path, id: 'two'));
    expect(controller.result, isNull);
    expect(File(oldOutput).existsSync(), isFalse);
    expect(engine.remuxCount, 3);
    expect(controller.sourcePath, endsWith('/sample_original.mp4'));
    expect(controller.source.fullBytes, await playlist.length() + 80);
    expect(controller.sourceBytes, 90);
  });

  test(
    'switching to full episode removes sample results and compares full size',
    () async {
      await controller.select(compressionTask(source.path));
      final samplePath = controller.sourcePath!;
      await controller.compress(enginePreset);
      final resultPath = controller.result!.path;
      await controller.changeRange(CompressionTestRange.full);
      expect(controller.result, isNull);
      expect(File(samplePath).existsSync(), isFalse);
      expect(File(resultPath).existsSync(), isFalse);
      expect(controller.sourceBytes, 100);
      expect(controller.media!.seconds, 60);
      await controller.compress(enginePreset);
      expect(controller.result!.range, CompressionTestRange.full);
      expect(controller.result!.sourceBytes, 100);
      expect(controller.progress, 1);
    },
  );

  test(
    'return during compression cancels before deleting partial output',
    () async {
      await controller.select(compressionTask(source.path));
      engine.compression = Completer<void>();
      engine.started = Completer<void>();
      final operation = controller.compress(enginePreset);
      await engine.started!.future;
      await controller.compress(enginePreset);
      expect(engine.compressCount, 1);
      final session = controller.workspace.directory;
      await controller.close();
      await operation;
      expect(engine.cancelled, isTrue);
      expect(controller.result, isNull);
      expect(session.existsSync(), isFalse);
      expect(source.existsSync(), isTrue);
    },
  );

  test(
    'rejects duration or track mismatch and permits a subsequent retry',
    () async {
      await controller.select(compressionTask(source.path));
      engine.outputMedia = const CompressionMedia(
        seconds: 20,
        width: 1920,
        height: 1080,
        hasAudio: false,
      );
      await controller.compress(enginePreset);
      expect(controller.result, isNull);
      expect(controller.error, contains('不符'));
      engine.outputMedia = null;
      await controller.compress(enginePreset);
      expect(controller.error, isNull);
      expect(controller.result, isNotNull);
    },
  );

  test(
    'retains results for comparison and clears all outputs on range change',
    () async {
      await controller.select(compressionTask(source.path));
      await controller.compress(enginePreset);
      final first = controller.result!;
      engine.outputBytes = 30;
      await controller.compress(enginePreset);
      final second = controller.result!;
      expect(controller.results, [first, second]);
      expect(second.path, isNot(first.path));
      controller.selectResult(first);
      expect(controller.result, same(first));
      expect(await File(first.path).length(), 40);
      expect(await File(second.path).length(), 30);
      await controller.changeRange(CompressionTestRange.full);
      expect(controller.results, isEmpty);
      expect(File(first.path).existsSync(), isFalse);
      expect(File(second.path).existsSync(), isFalse);
    },
  );

  test('encoder detection uses exact names and only available encoders', () {
    expect(CompressionPreset.fromEncoders(' V....D libx265 encoder').length, 5);
    expect(
      CompressionPreset.fromEncoders(' V....D libx264 encoder').first.encoder,
      'libx264',
    );
    expect(
      CompressionPreset.fromEncoders(' V....D libx264rgb encoder'),
      isEmpty,
    );
    expect(CompressionPreset.fromEncoders(' A..... aac encoder'), isEmpty);
  });

  test(
    'rejects impossible target before encoding and preserves prior result',
    () async {
      await controller.select(compressionTask(source.path));
      await controller.compress(enginePreset);
      final previous = controller.result;
      await controller.compress(
        const CompressionPreset('10%', 'libx265', 34, sizeRatio: .10),
      );
      expect(controller.error, contains('预算不足'));
      expect(engine.compressCount, 1);
      expect(controller.result, same(previous));
      expect(controller.results.length, 1);
    },
  );
}

const enginePreset = FakeCompressionEngine.preset;
