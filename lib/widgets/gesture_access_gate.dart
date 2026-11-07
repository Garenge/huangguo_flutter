import 'package:flutter/material.dart';

import '../pages/gesture_demo_page.dart';
import '../services/gesture_lock_service.dart';
import 'gesture_prompt.dart';
import 'gesture_loading_cover.dart';

class GestureAccessGate extends StatefulWidget {
  const GestureAccessGate({
    super.key,
    required this.service,
    required this.navigatorKey,
    required this.child,
  });

  final GestureLockService service;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<GestureAccessGate> createState() => _GestureAccessGateState();
}

class _GestureAccessGateState extends State<GestureAccessGate>
    with WidgetsBindingObserver {
  GestureDestination? _destination;
  bool _hasOpenedReal = false;
  bool _busy = false;
  String? _error;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_refresh);
    WidgetsBinding.instance.addObserver(this);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _lock() {
    _attempt++;
    setState(() {
      _destination = null;
      _busy = false;
      _error = null;
    });
    widget.service.invalidateSession();
    // Discard password-management routes and their temporary authorization.
    widget.navigatorKey.currentState?.popUntil(
      (route) => widget.service.enabled || !widget.service.ready
          ? route.isFirst
          : route.settings.name != 'gesture_setup',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _lock();
    }
  }

  Future<void> _unlock(List<int> pattern) async {
    if (_busy) return;
    final attempt = ++_attempt;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.service.unlock(
      pattern,
      expectedSession: widget.service.sessionVersion,
    );
    if (!mounted || attempt != _attempt) return;
    setState(() {
      _busy = false;
      _destination = result;
      if (result == GestureDestination.real) _hasOpenedReal = true;
      if (result == null) _error = '手势错误，请重试';
    });
  }

  @override
  void dispose() {
    _attempt++;
    widget.service.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final real = service.canAccessReal;
    if (real) _hasOpenedReal = true;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_hasOpenedReal)
          Offstage(
            offstage: !real,
            child: TickerMode(
              enabled: real,
              child: ExcludeFocus(excluding: !real, child: widget.child),
            ),
          ),
        if (!real) ScaffoldMessenger(child: _buildCover(service)),
      ],
    );
  }

  Widget _buildCover(GestureLockService service) {
    if (service.ready && _destination == GestureDestination.demo) {
      return GestureDemoPage(onRetry: _lock);
    }
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: service.ready
            ? GesturePrompt(
                key: ValueKey(service.sessionVersion),
                title: '手势解锁',
                message: '请绘制解锁手势',
                error: _error,
                busy: _busy,
                onCompleted: _unlock,
              )
            : GestureLoadingCover(service: service),
      ),
    );
  }
}
