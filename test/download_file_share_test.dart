import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/download_file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory directory;
  late List<MethodCall> calls;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('download_share_test');
    calls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      pathChannel,
      (_) async => directory.path,
    );
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      calls.add(call);
      return '';
    });
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathChannel, null);
    messenger.setMockMethodCallHandler(shareChannel, null);
    directory.deleteSync(recursive: true);
  });

  for (final format in {'mp4': 'video/mp4', 'zip': 'application/zip'}.entries) {
    test(
      'shares only a named ${format.key} file with its iPad origin',
      () async {
        final original = File('${directory.path}/original.${format.key}');
        await original.writeAsBytes([1, 2, 3]);
        final name = '测试剧 - 第一集.${format.key}';
        const origin = Rect.fromLTWH(200, 300, 1, 1);
        await DownloadFileService.shareFile(
          filePath: original.path,
          fileName: name,
          mimeType: format.value,
          sharePositionOrigin: origin,
        );
        expect(calls, hasLength(1));
        expect(calls.single.method, 'shareFiles');
        final args = calls.single.arguments as Map;
        expect(args.containsKey('text'), isFalse);
        expect(args['mimeTypes'], [format.value]);
        final shared = File((args['paths'] as List).single as String);
        expect(shared.uri.pathSegments.last, name);
        expect(await shared.readAsBytes(), [1, 2, 3]);
        expect(await original.exists(), isTrue);
        expect(
          [
            args['originX'],
            args['originY'],
            args['originWidth'],
            args['originHeight'],
          ],
          [200, 300, 1, 1],
        );
      },
    );
  }
}
