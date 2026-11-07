import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/services/gesture_lock_service.dart';
import 'package:huangguo_flutter/widgets/gesture_access_gate.dart';
import 'package:huangguo_flutter/widgets/gesture_pattern_pad.dart';

class GestureGateHarness extends StatelessWidget {
  GestureGateHarness({super.key, required this.service});

  final GestureLockService service;
  final navigatorKey = GlobalKey<NavigatorState>();
  final captureKey = GlobalKey();
  final _buildCount = ValueNotifier(0);
  int get realBuilds => _buildCount.value;

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    theme: ThemeData.dark(useMaterial3: true),
    builder: (context, child) => RepaintBoundary(
      key: captureKey,
      child: GestureAccessGate(
        service: service,
        navigatorKey: navigatorKey,
        child: child!,
      ),
    ),
    home: Builder(
      builder: (context) {
        _buildCount.value++;
        return const Scaffold(body: Center(child: Text('真实页面')));
      },
    ),
  );
}

Future<void> drawGesture(WidgetTester tester, List<int> points) async {
  final rect = tester.getRect(find.byType(GesturePatternPad));
  Offset point(int number) => Offset(
    rect.left + ((number - 1) % 3 + 0.5) * rect.width / 3,
    rect.top + ((number - 1) ~/ 3 + 0.5) * rect.height / 3,
  );
  final gesture = await tester.startGesture(point(points.first));
  for (final number in points.skip(1)) {
    await gesture.moveTo(point(number));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> backgroundAndResume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}
