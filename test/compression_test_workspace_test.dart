import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/compression_test.dart';
import 'package:huangguo_flutter/services/compression_test_workspace.dart';

void main() {
  late Directory root;
  late CompressionTestWorkspace workspace;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('compression_workspace_');
    workspace = CompressionTestWorkspace(temporaryDirectory: () async => root);
    await workspace.open();
  });

  tearDown(() async {
    await workspace.close();
    await root.delete(recursive: true);
  });

  test(
    'copies only HLS references, counts unique resources, preserves originals',
    () async {
      final source = await Directory('${root.path}/downloads').create();
      final playlist = File('${source.path}/playlist.m3u8');
      const content =
          '#EXTM3U\n'
          '#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n'
          '#EXTINF:30,\n00000.ts\n'
          '#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n'
          '#EXTINF:30,\n00001.ts\n#EXT-X-ENDLIST\n';
      await playlist.writeAsString(content);
      await File('${source.path}/key.bin').writeAsBytes(List.filled(16, 1));
      await File('${source.path}/00000.ts').writeAsBytes(List.filled(50, 2));
      await File('${source.path}/00001.ts').writeAsBytes(List.filled(60, 3));
      await File('${source.path}/unrelated.mp4').writeAsBytes([9]);
      final copied = await workspace.copySource(
        playlist.path,
        cancelled: () => false,
      );
      expect(copied.bytes, content.length + 16 + 50 + 60);
      expect(await File(copied.path).readAsString(), content);
      expect(
        File('${File(copied.path).parent.path}/unrelated.mp4').existsSync(),
        isFalse,
      );
      final session = workspace.directory;
      await workspace.close();
      expect(session.existsSync(), isFalse);
      expect(await playlist.readAsString(), content);
      expect(await source.list().length, 5);
    },
  );

  test('cancel during copying prevents publishing a source', () async {
    final source = File('${root.path}/video.mp4');
    await source.writeAsBytes([1, 2, 3]);
    await expectLater(
      workspace.copySource(source.path, cancelled: () => true),
      throwsA(isA<CompressionCancelled>()),
    );
    expect(await source.readAsBytes(), [1, 2, 3]);
  });

  test(
    'rejects remote references and paths outside the episode directory',
    () async {
      final source = await Directory('${root.path}/source').create();
      final playlist = File('${source.path}/playlist.m3u8');
      for (final reference in [
        'https://example.com/a.ts',
        '../outside.ts',
        '..%2Foutside.ts',
        '%2e%2e/outside.ts',
      ]) {
        await playlist.writeAsString('#EXTM3U\n$reference\n');
        await expectLater(
          workspace.copySource(playlist.path, cancelled: () => false),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'removes stale sessions without touching active sessions or other caches',
    () async {
      final tests = workspace.directory.parent;
      final stale = await Directory('${tests.path}/session_stale').create();
      final other = await Directory('${tests.path}/other_cache').create();
      final active = workspace.directory;
      final second = CompressionTestWorkspace(
        temporaryDirectory: () async => root,
      );
      await second.open();
      expect(stale.existsSync(), isFalse);
      expect(active.existsSync(), isTrue);
      expect(other.existsSync(), isTrue);
      await second.close();
    },
  );
}
