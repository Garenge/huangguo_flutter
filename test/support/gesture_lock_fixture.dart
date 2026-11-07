import 'package:huangguo_flutter/services/gesture_credential_store.dart';
import 'package:huangguo_flutter/services/gesture_lock_service.dart';

const gestureA = [1, 4, 7, 8, 9];
const gestureB = [1, 2, 3, 5, 7];
const wrongGesture = [3, 6, 9, 8, 7];

class MemoryGestureStore implements GestureCredentialStore {
  String? value;
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<String?> read() async {
    if (failRead) throw StateError('test read failure');
    return value;
  }

  @override
  Future<void> write(String next) async {
    if (failWrite) throw StateError('test write failure');
    value = next;
  }

  @override
  Future<void> delete() async {
    if (failWrite) throw StateError('test delete failure');
    value = null;
  }
}

Future<GestureLockService> createGestureService(
  MemoryGestureStore store, {
  bool enabled = true,
}) async {
  final service = GestureLockService(store: store, iterations: 1);
  await service.load();
  if (enabled && !service.enabled) {
    await service.configure(gestureA, gestureB, expectedSession: 0);
    service.dispose();
    return createGestureService(store);
  }
  return service;
}
