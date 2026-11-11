import 'package:flutter/material.dart';

class PlaybackSourceInfo extends StatelessWidget {
  const PlaybackSourceInfo({
    super.key,
    required this.local,
    this.url,
    this.onCopy,
    this.onUseOnline,
  });

  final bool local;
  final String? url;
  final VoidCallback? onCopy;
  final VoidCallback? onUseOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey[900],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                local ? Icons.offline_pin_rounded : Icons.cloud_outlined,
                size: 16,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                local ? '本地播放' : '在线播放',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              if (url != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    url!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
                IconButton(
                  tooltip: '复制流地址',
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  color: Colors.orange,
                ),
              ],
            ],
          ),
          if (onUseOnline != null)
            TextButton(
              onPressed: onUseOnline,
              child: const Text('改用在线播放（将消耗流量）'),
            ),
        ],
      ),
    );
  }
}
