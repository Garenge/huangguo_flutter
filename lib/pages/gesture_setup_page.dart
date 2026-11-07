import 'package:flutter/material.dart';

import '../services/gesture_lock_service.dart';
import '../services/gesture_setup_controller.dart';
import '../widgets/gesture_prompt.dart';

class GestureSetupPage extends StatefulWidget {
  const GestureSetupPage({
    super.key,
    required this.service,
    this.disabling = false,
  });

  final GestureLockService service;
  final bool disabling;

  @override
  State<GestureSetupPage> createState() => _GestureSetupPageState();
}

class _GestureSetupPageState extends State<GestureSetupPage> {
  late final _controller = GestureSetupController(
    widget.service,
    disabling: widget.disabling,
  );

  Future<void> _submit(List<int> pattern) async {
    final complete = await _controller.submit(pattern);
    if (!mounted || _controller.session != widget.service.sessionVersion) {
      return;
    }
    if (complete) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => PopScope(
      canPop: !_controller.busy,
      child: Scaffold(
        backgroundColor: const Color(0xFF111827),
        appBar: AppBar(
          title: Text(widget.disabling ? '关闭手势解锁' : '设置手势解锁'),
          backgroundColor: const Color(0xFF111827),
        ),
        body: SafeArea(
          child: GesturePrompt(
            title: widget.disabling ? '验证正常使用手势' : '手势设置',
            message: _controller.message,
            error: _controller.error,
            busy: _controller.busy,
            onCompleted: _submit,
          ),
        ),
      ),
    ),
  );
}
