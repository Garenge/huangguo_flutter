import 'package:flutter/foundation.dart';

import '../models/gesture_pattern.dart';
import 'gesture_lock_service.dart';

class GestureSetupController extends ChangeNotifier {
  GestureSetupController(this.service, {this.disabling = false})
    : session = service.sessionVersion,
      step = service.enabled ? 0 : 1;

  final GestureLockService service;
  final bool disabling;
  final int session;
  int step;
  bool busy = false;
  String? error;
  List<int>? _currentA;
  List<int>? _candidate;
  List<int>? _a;
  bool _disposed = false;

  String get message => switch (step) {
    0 => '请绘制当前正常使用手势，验证身份',
    1 => '设置正常使用手势 · 用于进入真实应用',
    2 => '再次绘制正常使用手势',
    3 => '设置演示使用手势 · 用于进入演示页面',
    _ => '再次绘制演示使用手势',
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> submit(List<int> pattern) async {
    if (busy || session != service.sessionVersion) return false;
    error = null;
    if (!GesturePattern.isValid(pattern)) {
      error = '请至少连接 4 个点';
      _notify();
      return false;
    }
    busy = true;
    _notify();
    try {
      return await _advance(pattern);
    } catch (_) {
      error = '保存失败，请重试；原设置保持不变';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> _advance(List<int> pattern) async {
    if (step == 0) {
      if (await service.verify(pattern) != GestureDestination.real) {
        error = '手势错误，请重试';
        return false;
      }
      _currentA = List.of(pattern);
      if (disabling) {
        await service.disable(pattern, expectedSession: session);
        return true;
      }
      step = 1;
    } else if (step == 1 || step == 3) {
      if (step == 3 && pattern.join() == _a!.join()) {
        error = '演示使用手势不能与正常使用手势相同';
        return false;
      }
      _candidate = List.of(pattern);
      step++;
    } else if (_candidate!.join() != pattern.join()) {
      step--;
      _candidate = null;
      error = '两次手势不一致，请重新设置';
    } else if (step == 2) {
      _a = _candidate;
      _candidate = null;
      step = 3;
    } else {
      await service.configure(
        _a!,
        pattern,
        currentA: _currentA,
        expectedSession: session,
      );
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _currentA = _candidate = _a = null;
    super.dispose();
  }
}
