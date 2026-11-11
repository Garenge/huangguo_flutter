import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/widgets/player_layout.dart';

const _playerKey = Key('player');

Future<void> _mountLayout(
  WidgetTester tester,
  TargetPlatform platform,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        appBar: AppBar(),
        body: PlayerLayout(
          builder: (context, height) => Column(
            children: [
              SizedBox(key: _playerKey, width: double.infinity, height: height),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform uses available width at 16:9', (tester) async {
      await _mountLayout(tester, platform, const Size(390, 844));
      expect(tester.getSize(find.byKey(_playerKey)), const Size(390, 219.375));
      expect(tester.takeException(), isNull);
    });
  }

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets('$platform caps height and responds to window resizing', (
      tester,
    ) async {
      await _mountLayout(tester, platform, const Size(800, 600));
      final bodyHeight = tester.getSize(find.byType(PlayerLayout)).height;
      expect(
        tester.getSize(find.byKey(_playerKey)).height,
        closeTo(bodyHeight * 0.65, 0.001),
      );
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pump();
      expect(tester.getSize(find.byKey(_playerKey)), const Size(400, 225));
      expect(tester.takeException(), isNull);
    });
  }
}
