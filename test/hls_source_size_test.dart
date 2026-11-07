import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/hls_source_size.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('hls_size'));
  tearDown(() => root.deleteSync(recursive: true));

  File write(String name, List<int> bytes) {
    final file = File('${root.path}/$name');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return file;
  }

  File playlist(String content) => write('playlist.m3u8', content.codeUnits);

  test(
    'counts only referenced segments, playlist and shared key once',
    () async {
      final manifest = playlist('''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="key_0.bin"
#EXTINF:2,
00000.ts
#EXT-X-KEY:METHOD=AES-128,URI="./key_0.bin"
#EXTINF:2,
./00000.ts
#EXTINF:2,
nested/00001.ts
#EXT-X-ENDLIST
''');
      write('key_0.bin', List.filled(16, 1));
      write('00000.ts', List.filled(100, 1));
      write('nested/00001.ts', List.filled(200, 1));
      write('old.mp4', List.filled(900, 1));
      write('unreferenced.ts', List.filled(800, 1));
      final size = await HlsSourceSize.read(manifest.path);
      expect(size.bytes, manifest.lengthSync() + 16 + 100 + 200);
      expect(size.segmentCount, 2);
    },
  );

  test(
    'resolves escaped names and includes a referenced initialization file',
    () async {
      final manifest = playlist('''
#EXTM3U
#EXT-X-MAP:URI="init.mp4"
#EXTINF:2,
part%201.m4s
''');
      write('init.mp4', List.filled(20, 1));
      write('part 1.m4s', List.filled(80, 1));
      final size = await HlsSourceSize.read(manifest.path);
      expect(size.bytes, manifest.lengthSync() + 100);
      expect(size.segmentCount, 1);
    },
  );

  test(
    'missing segment rejects the entire total instead of returning a partial size',
    () async {
      final manifest = playlist('#EXTM3U\n#EXTINF:2,\nmissing.ts\n');
      await expectLater(
        HlsSourceSize.read(manifest.path),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test('remote references are not counted as local files', () async {
    final manifest = playlist('#EXTM3U\nhttps://example.com/video.ts\n');
    await expectLater(HlsSourceSize.read(manifest.path), throwsFormatException);
  });

  test('master playlists do not produce incomplete source totals', () async {
    final manifest = playlist(
      '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=100\nlow.m3u8\n',
    );
    write('low.m3u8', '#EXTM3U'.codeUnits);
    await expectLater(HlsSourceSize.read(manifest.path), throwsFormatException);
  });
}
