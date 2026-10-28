import 'package:flutter/material.dart';
import '../services/huangguo_api.dart';

class NetworkDiagnosticsTile extends StatefulWidget {
  final HuangguoApi api;

  const NetworkDiagnosticsTile({super.key, required this.api});

  @override
  State<NetworkDiagnosticsTile> createState() => _NetworkDiagnosticsTileState();
}

class _NetworkDiagnosticsTileState extends State<NetworkDiagnosticsTile> {
  bool _running = false;

  Future<void> _test() async {
    setState(() => _running = true);
    final results = await widget.api.testConnectivity();
    if (!mounted) return;
    setState(() => _running = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('网络检测结果'),
        content: SingleChildScrollView(child: SelectableText(results)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('检测网络'),
      subtitle: Text(_running ? '正在检测，请稍候…' : '检查目标站、规则源和当前代理'),
      trailing: const Icon(Icons.network_check),
      onTap: _running ? null : _test,
    );
  }
}
