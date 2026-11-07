import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/gesture_pattern.dart';
import 'app_log.dart';
import 'gesture_credential_store.dart';
import 'gesture_credentials.dart';
import 'gesture_password_hasher.dart';

enum GestureDestination { real, demo }

class GestureLockService extends ChangeNotifier {
  GestureLockService({GestureCredentialStore? store, int iterations = 100000})
    : _store = store ?? SecureGestureCredentialStore(),
      _hasher = GesturePasswordHasher(iterations);

  final GestureCredentialStore _store;
  final GesturePasswordHasher _hasher;
  Map<String, dynamic>? _credentials;
  Future<void>? _loading;
  bool _disposed = false;
  bool _realSessionOpen = false;
  bool ready = false;
  bool loadFailed = false;
  int sessionVersion = 0;

  bool get enabled => _credentials != null;
  bool get canAccessReal => ready && (!enabled || _realSessionOpen);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() => _loading ??= _load();

  Future<void> retryLoad() {
    _loading = null;
    return load();
  }

  Future<void> _load() async {
    ready = false;
    loadFailed = false;
    _notify();
    try {
      _credentials = GestureCredentials.decode(await _store.read());
      ready = true;
    } catch (error, stack) {
      loadFailed = true;
      const AppLog(
        'gesture_lock_service.dart',
      ).e('_load: 手势设置读取失败，保持入口锁定', error.runtimeType, stack);
    }
    _notify();
  }

  void invalidateSession() {
    sessionVersion++;
    _realSessionOpen = false;
    _notify();
  }

  Future<GestureDestination?> unlock(
    List<int> pattern, {
    required int expectedSession,
  }) async {
    final destination = await verify(pattern);
    if (sessionVersion != expectedSession) return null;
    _realSessionOpen = destination == GestureDestination.real;
    _notify();
    return destination;
  }

  Future<GestureDestination?> verify(List<int> pattern) async {
    final saved = _credentials;
    if (!ready || saved == null || !GesturePattern.isValid(pattern)) {
      return null;
    }
    final hash = await _hasher.hash(
      pattern,
      base64Decode(saved['salt'] as String),
    );
    if (_hasher.equal(hash, saved['a'] as String)) {
      return GestureDestination.real;
    }
    if (_hasher.equal(hash, saved['b'] as String)) {
      return GestureDestination.demo;
    }
    return null;
  }

  Future<void> configure(
    List<int> a,
    List<int> b, {
    List<int>? currentA,
    required int expectedSession,
  }) async {
    if (!ready ||
        !GesturePattern.isValid(a) ||
        !GesturePattern.isValid(b) ||
        a.join() == b.join()) {
      throw StateError('手势设置无效');
    }
    if (enabled && await verify(currentA ?? []) != GestureDestination.real) {
      throw StateError('当前手势验证失败');
    }
    final next = await GestureCredentials.create(a, b, _hasher);
    _checkSession(expectedSession);
    await _store.write(jsonEncode(next));
    _credentials = next;
    _realSessionOpen = sessionVersion == expectedSession;
    _notify();
  }

  Future<void> disable(
    List<int> currentA, {
    required int expectedSession,
  }) async {
    if (await verify(currentA) != GestureDestination.real) {
      throw StateError('当前手势验证失败');
    }
    _checkSession(expectedSession);
    await _store.delete();
    _credentials = null;
    _notify();
  }

  void _checkSession(int expected) {
    if (sessionVersion != expected) throw StateError('请重新解锁后设置');
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
