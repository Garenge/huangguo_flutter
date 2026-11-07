import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/pages/gesture_setup_page.dart';
import 'package:huangguo_flutter/widgets/gesture_access_gate.dart';
import 'package:huangguo_flutter/widgets/gesture_settings_tile.dart';

import 'support/gesture_gate_harness.dart';
import 'support/gesture_lock_fixture.dart';

void main() {
  testWidgets('完整开关流程，确认前不启用，关闭前验证正常使用手势', (tester) async {
    final service = await createGestureService(
      MemoryGestureStore(),
      enabled: false,
    );
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) => GestureAccessGate(
          service: service,
          navigatorKey: navigator,
          child: child!,
        ),
        home: Scaffold(body: GestureSettingsTile(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('设置正常使用手势 · 用于进入真实应用'), findsOneWidget);
    await drawGesture(tester, gestureA);
    expect(find.text('再次绘制正常使用手势'), findsOneWidget);
    await drawGesture(tester, gestureA);
    expect(find.text('设置演示使用手势 · 用于进入演示页面'), findsOneWidget);
    await drawGesture(tester, gestureA);
    expect(find.text('演示使用手势不能与正常使用手势相同'), findsOneWidget);
    await drawGesture(tester, gestureB);
    expect(find.text('再次绘制演示使用手势'), findsOneWidget);
    expect(service.enabled, isFalse);
    await drawGesture(tester, gestureB);
    expect(service.enabled, isTrue);
    expect(find.byType(GestureSetupPage), findsNothing);
    expect(find.text('修改正常使用 / 演示使用手势'), findsOneWidget);
    expect(find.text('需先验证当前正常使用手势'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('验证正常使用手势'), findsOneWidget);
    expect(find.text('请绘制当前正常使用手势，验证身份'), findsOneWidget);
    await drawGesture(tester, gestureB);
    expect(service.enabled, isTrue);
    expect(find.text('手势错误，请重试'), findsOneWidget);
    await drawGesture(tester, gestureA);
    expect(service.enabled, isFalse);
    expect(find.byType(GestureSetupPage), findsNothing);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
