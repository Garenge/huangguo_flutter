import 'package:flutter_test/flutter_test.dart';
import 'package:huangguo_flutter/models/gesture_pattern.dart';
import 'package:huangguo_flutter/services/gesture_lock_service.dart';
import 'package:huangguo_flutter/services/gesture_setup_controller.dart';

import 'support/gesture_lock_fixture.dart';

void main() {
  test('解锁计算期间会话过期，正确 A 也不能放行', () async {
    final service = await createGestureService(MemoryGestureStore());
    final verifying = service.unlock(gestureA, expectedSession: 0);
    service.invalidateSession();
    expect(await verifying, isNull);
    expect(service.canAccessReal, isFalse);
    service.dispose();
  });

  test('九宫格补中点、忽略重复点，识别大 L', () {
    expect(GesturePattern.append([1], 9), [1, 5, 9]);
    expect(GesturePattern.append([1, 2], 3), [1, 2, 3]);
    expect(GesturePattern.append([1, 2], 1), [1, 2]);
    expect(GesturePattern.isValid(gestureA), isTrue);
    expect(GesturePattern.isValid([1, 9, 7, 3]), isFalse);
    expect(GesturePattern.isValid([1, 2, 3]), isFalse);
  });

  test('持久化后可分流 A/B，错误密码不放行且没有明文手势', () async {
    final store = MemoryGestureStore();
    final first = await createGestureService(store);
    expect(store.value, isNot(contains(gestureA.join())));
    expect(store.value, isNot(contains(gestureB.join())));
    first.dispose();
    final restored = await createGestureService(store);
    expect(await restored.verify(gestureA), GestureDestination.real);
    expect(await restored.verify(gestureB), GestureDestination.demo);
    expect(await restored.verify(wrongGesture), isNull);
    restored.dispose();
  });

  test('二次确认、A/B 不同及取消均不提前启用', () async {
    final service = await createGestureService(
      MemoryGestureStore(),
      enabled: false,
    );
    final setup = GestureSetupController(service);
    await setup.submit(gestureA);
    await setup.submit(wrongGesture);
    expect(setup.step, 1);
    expect(service.enabled, isFalse);
    await setup.submit(gestureA);
    await setup.submit(gestureA);
    await setup.submit(gestureA);
    expect(setup.step, 3);
    expect(setup.error, contains('不能'));
    await setup.submit(gestureB);
    expect(service.enabled, isFalse);
    expect(await setup.submit(gestureB), isTrue);
    expect(service.enabled, isTrue);
    setup.dispose();
    service.dispose();
  });

  test('B 无法修改或关闭，修改须确认且原 A 失效', () async {
    final service = await createGestureService(MemoryGestureStore());
    final setup = GestureSetupController(service);
    await setup.submit(gestureB);
    expect(setup.step, 0);
    await setup.submit(gestureA);
    await setup.submit(wrongGesture);
    await setup.submit(wrongGesture);
    await setup.submit(gestureB);
    expect(await setup.submit(gestureB), isTrue);
    expect(await service.verify(gestureA), isNull);
    expect(await service.verify(wrongGesture), GestureDestination.real);
    await expectLater(
      service.disable(gestureB, expectedSession: 0),
      throwsStateError,
    );
    await service.disable(wrongGesture, expectedSession: 0);
    expect(service.enabled, isFalse);
    setup.dispose();
    service.dispose();
  });

  test('写入失败保留旧手势；会话变化后禁止保存', () async {
    final store = MemoryGestureStore();
    final service = await createGestureService(store);
    store.failWrite = true;
    await expectLater(
      service.configure(
        wrongGesture,
        gestureB,
        currentA: gestureA,
        expectedSession: 0,
      ),
      throwsStateError,
    );
    expect(await service.verify(gestureA), GestureDestination.real);
    store.failWrite = false;
    service.invalidateSession();
    await expectLater(
      service.configure(
        wrongGesture,
        gestureB,
        currentA: gestureA,
        expectedSession: 0,
      ),
      throwsStateError,
    );
    expect(await service.verify(gestureA), GestureDestination.real);
    service.dispose();
  });

  test('读取失败或数据损坏时保持锁定，重试可恢复', () async {
    final store = MemoryGestureStore()..failRead = true;
    final service = GestureLockService(store: store, iterations: 1);
    await service.load();
    expect(service.ready, isFalse);
    expect(service.loadFailed, isTrue);
    store.failRead = false;
    store.value = '{"version":1}';
    await service.retryLoad();
    expect(service.ready, isFalse);
    store.value = null;
    await service.retryLoad();
    expect(service.ready, isTrue);
    expect(service.enabled, isFalse);
    service.dispose();
  });
}
