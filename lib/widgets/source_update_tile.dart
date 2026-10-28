import 'package:flutter/material.dart';
import '../services/source_loader.dart';

class SourceUpdateTile extends StatefulWidget {
  final SourceLoader sourceLoader;

  const SourceUpdateTile({super.key, required this.sourceLoader});

  @override
  State<SourceUpdateTile> createState() => _SourceUpdateTileState();
}

class _SourceUpdateTileState extends State<SourceUpdateTile> {
  bool _loading = false;

  Future<void> _update() async {
    setState(() => _loading = true);
    String message;
    try {
      await widget.sourceLoader.forceReload();
      message = '解析规则已更新';
    } catch (error) {
      message = '更新失败，继续使用现有规则：$error';
    }
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('更新解析规则'),
      subtitle: const Text('更新站点与分类配置；失败时保留现有规则'),
      trailing: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      onTap: _loading ? null : _update,
    );
  }
}
