import 'package:huangguo_flutter/services/huangguo_api.dart';

// Mirrors /video/11969/ without expiring URLs, credentials or page content.
const apiSingleVideoHtml = '''
  <section class="hg-web-play" data-web-play data-show-episodes="0">
    <video data-ssr-native controls>
      <source type="application/vnd.apple.mpegurl">
    </video>
  </section>
  <script id="videoInitialData" type="application/json">
    {"id":"11969","ep":1,"videoType":1,"videoSrc":"",
     "videoSrcHevc":"","epPlaySrcs":{},"epPlaySrcsHevc":{}}
  </script>
''';

const apiSingleVideoHeaders = {'x-cdn-auth': 'signed', 'x-cdn-app': '150'};

class ApiSingleVideoFixture extends HuangguoApi {
  final requests = <String>[];

  @override
  Future<String> fetchDetail(String dramaId) async => apiSingleVideoHtml;

  @override
  Future<Map<String, dynamic>> fetchPlayback(
    String videoId, {
    String? episode,
  }) async {
    requests.add('$videoId:$episode');
    return {
      'id': videoId,
      'ep': 1,
      'manifest_method': 'GET',
      'streams': {'main': 'https://cdn.example/main.m3u8'},
      'cdn': {'authKey': 'x-cdn-auth', 'authValue': 'signed', 'app': '150'},
    };
  }

  @override
  Future<String> fetchPlayPage(String url) async {
    throw StateError('API-only video must not fall back to HTML');
  }
}
