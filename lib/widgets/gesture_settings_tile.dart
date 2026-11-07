import 'package:flutter/material.dart';

import '../pages/gesture_setup_page.dart';
import '../services/gesture_lock_service.dart';

class GestureSettingsTile extends StatefulWidget {
  const GestureSettingsTile({super.key, required this.service});

  final GestureLockService service;

  @override
  State<GestureSettingsTile> createState() => _GestureSettingsTileState();
}

class _GestureSettingsTileState extends State<GestureSettingsTile> {
  bool _opening = false;

  Future<void> _open({bool disabling = false}) async {
    if (_opening) return;
    setState(() => _opening = true);
    final success = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'gesture_setup'),
        builder: (_) =>
            GestureSetupPage(service: widget.service, disabling: disabling),
      ),
    );
    if (!mounted) return;
    setState(() => _opening = false);
    if (success == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(disabling ? '手势解锁已关闭' : '手势已保存')));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) => Card(
      color: Colors.grey[900],
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('手势解锁'),
            subtitle: const Text('开启后，启动及从后台返回时验证手势'),
            value: widget.service.enabled,
            onChanged: _opening ? null : (value) => _open(disabling: !value),
          ),
          if (widget.service.enabled)
            ListTile(
              leading: const Icon(Icons.gesture_rounded),
              title: const Text('修改正常使用 / 演示使用手势'),
              subtitle: const Text('需先验证当前正常使用手势'),
              onTap: _opening ? null : _open,
            ),
        ],
      ),
    ),
  );
}
