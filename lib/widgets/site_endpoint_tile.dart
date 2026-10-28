import 'package:flutter/material.dart';

import '../models/site_endpoint.dart';
import '../services/site_endpoint_service.dart';

class SiteEndpointTile extends StatefulWidget {
  final SiteEndpointService service;

  const SiteEndpointTile({super.key, required this.service});

  @override
  State<SiteEndpointTile> createState() => _SiteEndpointTileState();
}

class _SiteEndpointTileState extends State<SiteEndpointTile> {
  bool _testing = false;

  Future<void> _testSites() async {
    setState(() => _testing = true);
    try {
      await widget.service.testAll();
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _selectFastest() async {
    setState(() => _testing = true);
    try {
      final fastest = await widget.service.selectFastest();
      if (!mounted) return;
      _showMessage(
        fastest == null
            ? '没有找到可用站点'
            : '已切换到最快站点：${fastest.host}（${fastest.latency!.inMilliseconds} ms）',
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  String _formatResult(SiteEndpoint item) {
    if (item.isAvailable) return '${item.latency!.inMilliseconds} ms';
    return item.error ?? '未测试';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) => Card(
        color: Colors.grey[900],
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: const Text('站点地址'),
                subtitle: Text('当前：${widget.service.selectedUrl}'),
                trailing: _testing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : PopupMenuButton<String>(
                        tooltip: '切换站点',
                        icon: const Icon(Icons.swap_horiz),
                        onSelected: (url) => widget.service.select(url),
                        itemBuilder: (context) => SiteEndpointService.urls
                            .map(
                              (url) => PopupMenuItem(
                                value: url,
                                child: Text(Uri.parse(url).host),
                              ),
                            )
                            .toList(),
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _testing ? null : _testSites,
                      icon: const Icon(Icons.speed, size: 18),
                      label: const Text('测试速度'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _testing ? null : _selectFastest,
                      icon: const Icon(Icons.flash_on, size: 18),
                      label: const Text('加载最快'),
                    ),
                  ),
                ],
              ),
              if (widget.service.results.isNotEmpty)
                ...widget.service.results.map(
                  (item) => ListTile(
                    dense: true,
                    leading: Icon(
                      item.isAvailable ? Icons.check_circle : Icons.error,
                      color: item.isAvailable ? Colors.green : Colors.red[300],
                      size: 18,
                    ),
                    title: Text(Uri.parse(item.url).host),
                    trailing: Text(_formatResult(item)),
                    onTap: item.isAvailable
                        ? () => widget.service.select(item.url)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
