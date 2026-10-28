import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/source_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SourceLoader loader;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('source_loader_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    loader = SourceLoader();
  });

  tearDown(() async {
    loader.dispose();
    await directory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  test('startup repairs an obfuscated cache using bundled rules', () async {
    await File('${directory.path}/huangguo_source_cache.json').writeAsString(
      jsonEncode({
        'site': 'https://huangguoai.com',
        'ua': '',
        'tabs': [
          {'name': '首页', 'id': 'home'},
        ],
        'rawSource': 'const UA=decode(1),SITE=decode(2);',
      }),
    );
    final config = await loader.loadSource();
    expect(config.tabs, hasLength(11));
    expect(config.ua, isNotEmpty);
    expect(config.site, 'https://huangguoai.com');
  });

  test('invalid update preserves the last valid configuration', () async {
    await loader.loadSource();
    final cache = File('${directory.path}/huangguo_source_cache.json');
    final previous = await cache.readAsString();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.write('const UA=decode(1),SITE=decode(2);');
      await request.response.close();
    });
    try {
      await expectLater(
        loader.forceReload(url: 'http://127.0.0.1:${server.port}'),
        throwsA(isA<Exception>()),
      );
      expect(await cache.readAsString(), previous);
      expect(loader.updatedConfig, isNull);
    } finally {
      await server.close(force: true);
    }
  });
}
