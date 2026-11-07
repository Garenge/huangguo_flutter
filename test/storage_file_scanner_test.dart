import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/storage_usage.dart';
import 'package:huangguo_flutter/services/storage_file_scanner.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('storage_scan'));
  tearDown(() => root.deleteSync(recursive: true));

  void write(String path, int size) {
    final file = File('${root.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(List.filled(size, 1));
  }

  test('counts source and MP4 once across nested and repeated roots', () {
    write('downloads/album/ep1/segment.ts', 100);
    write('downloads/album/ep1/local.m3u8', 20);
    write('downloads/album/ep1/video.mp4', 80);
    write('downloads/album/ep2/video.mp4', 150);
    write('cache/cover.jpg', 50);
    final episode = '${root.path}/downloads/album/ep1';
    final result = StorageFileScanner().scan(
      [root.path, '${root.path}/cache', root.path],
      {
        'album': [episode, '$episode/video.mp4', '$episode/../ep2'],
      },
    );
    expect(result.appBytes, 400);
    expect(result.albumBytes['album'], 350);
  });

  test('missing files count as zero and symlinks are not followed', () {
    write('album/video.mp4', 40);
    Link('${root.path}/album/loop').createSync(root.path);
    Link('${root.path}/alias.mp4').createSync('${root.path}/album/video.mp4');
    final result = StorageFileScanner().scan(
      [root.path],
      {
        'album': ['${root.path}/album', '${root.path}/missing'],
        'empty': ['${root.path}/removed.mp4'],
      },
    );
    expect(result.appBytes, 40);
    expect(result.albumBytes, {'album': 40, 'empty': 0});
  });

  test('keeps separate episode directories and updates after deletion', () {
    write('episode/video.mp4', 30);
    write('episode_other/video.mp4', 70);
    final paths = {
      'first': ['${root.path}/episode'],
      'second': ['${root.path}/episode_other'],
    };
    expect(StorageFileScanner().scan([], paths).albumBytes['first'], 30);
    File('${root.path}/episode/video.mp4').deleteSync();
    final result = StorageFileScanner().scan([], paths);
    expect(result.appBytes, isNull);
    expect(result.albumBytes, {'first': 0, 'second': 70});
  });

  test('formats large sizes and clamps inconsistent device capacity', () {
    expect(formatStorageBytes(null), '暂不可用');
    expect(formatStorageBytes(0), '0 B');
    expect(formatStorageBytes(1536), '1.50 KB');
    expect(formatStorageBytes(2 * 1024 * 1024 * 1024), '2.00 GB');
    expect(
      const StorageUsage(totalBytes: 100, availableBytes: 25).usedBytes,
      75,
    );
    expect(
      const StorageUsage(totalBytes: 100, availableBytes: 120).usedBytes,
      0,
    );
    expect(
      const StorageUsage(totalBytes: 0, availableBytes: 0).usedBytes,
      isNull,
    );
  });
}
