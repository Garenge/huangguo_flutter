import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/widgets/share_origin.dart';

void main() {
  testWidgets('share origin is non-zero and inside the current window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final origin = await _readOrigin(tester);
    expect(origin.size, const Size(1, 1));
    expect(origin.center, const Offset(220, 478));
    expect(
      (Offset.zero & const Size(440, 956)).contains(origin.topLeft),
      isTrue,
    );
    expect(
      (Offset.zero & const Size(440, 956)).contains(origin.bottomRight),
      isTrue,
    );
  });

  testWidgets('share origin follows rotation instead of caching old bounds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(956, 440);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    expect((await _readOrigin(tester)).center, const Offset(478, 220));
    tester.view.physicalSize = const Size(440, 956);
    await tester.pump();
    expect((await _readOrigin(tester)).center, const Offset(220, 478));
  });
}

Future<Rect> _readOrigin(WidgetTester tester) async {
  late Rect origin;
  await tester.pumpWidget(
    Builder(
      builder: (context) {
        origin = shareOriginFor(context);
        return const SizedBox();
      },
    ),
  );
  return origin;
}
