import 'package:flutter/widgets.dart';

import '../services/gesture_lock_service.dart';

class GestureLockScope extends InheritedWidget {
  const GestureLockScope({
    super.key,
    required this.service,
    required super.child,
  });

  final GestureLockService service;

  static GestureLockService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GestureLockScope>()?.service;

  @override
  bool updateShouldNotify(GestureLockScope oldWidget) =>
      service != oldWidget.service;
}
