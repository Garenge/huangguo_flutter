import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/pages/gesture_setup_page.dart';
import 'package:huangguo_flutter/services/gesture_lock_service.dart';
import 'package:huangguo_flutter/widgets/gesture_pattern_pad.dart';

import 'support/gesture_gate_harness.dart';
import 'support/gesture_lock_fixture.dart';

void main() {
  late GestureLockService service;
  setUp(() async {
    service = await createGestureService(MemoryGestureStore());
  });
  tearDown(() => service.dispose());

  testWidgets('提交正确手势后立即切后台，返回仍锁定', (tester) async {
    await tester.pumpWidget(GestureGateHarness(service: service));
    tester
        .widget<GesturePatternPad>(find.byType(GesturePatternPad))
        .onCompleted(gestureA);
    await backgroundAndResume(tester);
    expect(find.text('真实页面'), findsNothing);
    expect(find.byType(GesturePatternPad), findsOneWidget);
    await drawGesture(tester, gestureA);
    expect(find.text('真实页面'), findsOneWidget);
  });

  testWidgets('错误不放行，B 后台后输入 A，真实页面后台后输入 B', (tester) async {
    final harness = GestureGateHarness(service: service);
    await tester.pumpWidget(harness);
    expect(harness.realBuilds, 0);
    await drawGesture(tester, wrongGesture);
    expect(find.text('手势错误，请重试'), findsOneWidget);
    await drawGesture(tester, gestureB);
    expect(find.text('手势解锁 App 测试 Demo'), findsOneWidget);
    expect(harness.realBuilds, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('真实页面'), findsNothing);
    await backgroundAndResume(tester);
    expect(find.byType(GesturePatternPad), findsOneWidget);
    await drawGesture(tester, gestureA);
    expect(find.text('真实页面'), findsOneWidget);
    await backgroundAndResume(tester);
    expect(find.text('真实页面'), findsNothing);
    await drawGesture(tester, gestureB);
    expect(find.text('手势解锁 App 测试 Demo'), findsOneWidget);
    expect(find.text('真实页面'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('重建应用保持锁定，真实页面的顶层路由不能绕过遮罩', (tester) async {
    final harness = GestureGateHarness(service: service);
    await tester.pumpWidget(harness);
    await drawGesture(tester, gestureA);
    harness.navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('全屏真实内容')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('全屏真实内容'), findsOneWidget);
    await backgroundAndResume(tester);
    expect(find.text('全屏真实内容'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('真实页面'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(GestureGateHarness(service: service));
    expect(find.byType(GesturePatternPad), findsOneWidget);
    expect(find.text('真实页面'), findsNothing);
  });

  testWidgets('修改密码验证正常使用手势后切后台，必须重新解锁并重新验证', (tester) async {
    final harness = GestureGateHarness(service: service);
    await tester.pumpWidget(harness);
    await drawGesture(tester, gestureA);
    harness.navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => GestureSetupPage(service: service),
      ),
    );
    await tester.pumpAndSettle();
    await drawGesture(tester, gestureA);
    expect(find.textContaining('设置正常使用手势'), findsOneWidget);
    await backgroundAndResume(tester);
    expect(find.byType(GestureSetupPage), findsNothing);
    await drawGesture(tester, gestureA);
    expect(find.text('真实页面'), findsOneWidget);
  });

  testWidgets('手机窄屏布局和手势页面预览', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = GestureGateHarness(service: service);
    await tester.pumpWidget(harness);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary =
        harness.captureKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/gesture_preview');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/lock.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}
