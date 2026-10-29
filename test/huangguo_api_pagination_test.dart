import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/huangguo_api.dart';

void main() {
  late HttpServer server;
  late HuangguoApi api;
  final requests = <HttpRequest>[];
  const response = '{"data":{"items":[],"pagination":{"page":2,"pages":2}}}';

  setUp(() async {
    requests.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request);
      request.response.headers.contentType = ContentType.json;
      request.response.write(response);
      await request.response.close();
    });
    api = HuangguoApi()..updateSite('http://127.0.0.1:${server.port}');
  });

  tearDown(() async {
    api.dispose();
    await server.close(force: true);
  });

  test(
    'hot pagination uses the verified site API and keeps JSON as text',
    () async {
      expect(await api.fetchChannelPage('ai-duanju', 'hot', 2), response);
      expect(requests.single.uri.path, '/api/videos/category/ai-duanju');
      expect(requests.single.uri.queryParameters, {
        'sort': 'hot_window',
        'page': '2',
        'size': '21',
      });
      expect(
        requests.single.headers.value('referer'),
        '${api.site}/ai-duanju/',
      );
    },
  );

  test(
    'original pagination adds the original filter and uses its category',
    () async {
      await api.fetchChannelPage('/ai-manju/', 'original', 3);
      expect(requests.single.uri.path, '/api/videos/category/ai-manju');
      expect(requests.single.uri.queryParameters, {
        'sort': 'hot_window',
        'is_original': '1',
        'page': '3',
        'size': '21',
      });
    },
  );

  test(
    'home and standard categories retain their HTML pagination paths',
    () async {
      await api.fetchCategory('home', 1);
      await api.fetchCategory('home', 2);
      await api.fetchCategory('ai-duanju', 2);
      expect(requests.map((r) => r.uri.path), [
        '/',
        '/newest/2/',
        '/ai-duanju/2/',
      ]);
    },
  );

  test('unsupported channel does not make a request', () {
    expect(
      () => api.fetchChannelPage('ai-duanju', 'random', 2),
      throwsArgumentError,
    );
    expect(requests, isEmpty);
  });
}
