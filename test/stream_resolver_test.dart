import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/episode.dart';
import 'package:huangguo_flutter/services/huangguo_api.dart';
import 'package:huangguo_flutter/services/stream_resolver.dart';

import 'helpers/api_single_video_fixture.dart';

class _Api extends HuangguoApi {
  Map<String, dynamic>? playback;
  int playbackCalls = 0;

  @override
  Future<Map<String, dynamic>> fetchPlayback(
    String videoId, {
    String? episode,
  }) async {
    playbackCalls++;
    return playback!;
  }

  @override
  Future<String> fetchPlayPage(String url) async {
    throw StateError('HTML fallback should not be used');
  }
}

void main() {
  test('resolves an API-only detail page through the playback endpoint', () async {
    final api = ApiSingleVideoFixture();
    addTearDown(api.dispose);
    final resolver = StreamResolver(api);
    final episodes = await resolver.resolveEpisodes('11969');

    expect(episodes, hasLength(1));
    expect(await resolver.resolveStream(episodes.single),
        'https://cdn.example/main.m3u8');
    expect(api.requests, ['11969:1']);
    expect(resolver.streamHeaders, apiSingleVideoHeaders);
  });

  test('resolves current playback API and keeps CDN headers', () async {
    final api = _Api()
      ..playback = {
        'id': '11919',
        'ep': 1,
        'manifest_method': 'GET',
        'streams': {'main': 'https://cdn.example/main.m3u8'},
        'cdn': {'authKey': 'x-cdn-auth', 'authValue': 'signed', 'app': '150'},
      };
    final resolver = StreamResolver(api);

    final result = await resolver.resolveStream(
      const Episode(name: '第1集', url: '/video/11919/', ep: '1'),
    );

    expect(result, 'https://cdn.example/main.m3u8');
    expect(api.playbackCalls, 1);
    expect(resolver.streamHeaders, {
      'x-cdn-auth': 'signed',
      'x-cdn-app': '150',
    });
  });
}
