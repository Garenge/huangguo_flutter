import 'package:flutter/material.dart';

class GestureDemoPage extends StatefulWidget {
  const GestureDemoPage({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  State<GestureDemoPage> createState() => _GestureDemoPageState();
}

class _GestureDemoPageState extends State<GestureDemoPage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF111827),
    appBar: AppBar(
      title: const Text('Flutter Demo'),
      backgroundColor: const Color(0xFF111827),
      automaticallyImplyLeading: false,
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FlutterLogo(size: 80),
            const SizedBox(height: 32),
            const Text(
              '手势解锁 App 测试 Demo',
              style: TextStyle(fontSize: 21),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text('解锁成功，可以点击按钮测试交互。'),
            const SizedBox(height: 24),
            Text('点击次数：$_count', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() => _count++),
              child: const Text('点击测试'),
            ),
            TextButton(onPressed: widget.onRetry, child: const Text('重新测试')),
          ],
        ),
      ),
    ),
  );
}
