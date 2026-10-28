import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/main.dart';
import 'package:huangguo_flutter/models/episode.dart';
import 'package:huangguo_flutter/pages/home_page.dart';
import 'package:huangguo_flutter/pages/player_page.dart';
import 'package:flutter/widgets.dart';

void main() {
  testWidgets('selecting a video reaches the existing player tab', (
    tester,
  ) async {
    await tester.pumpWidget(const HuangguoApp());
    final home = tester.widget<HomePage>(find.byType(HomePage));
    const episode = Episode(name: '测试集', url: '/test', ep: '1');
    home.onPlayEpisode(episode, [episode], '测试剧');
    await tester.pump();
    final page = tester.widget<PlayerPage>(find.byType(PlayerPage));
    expect(page.initialEpisode, episode);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
