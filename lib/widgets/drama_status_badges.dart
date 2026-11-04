import 'package:flutter/material.dart';

/// 标记不跟随海报淡化，且提供文字和无障碍说明。
class DramaStatusBadges extends StatelessWidget {
  const DramaStatusBadges({
    super.key,
    required this.watched,
    required this.downloaded,
  });

  final bool watched;
  final bool downloaded;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      if (watched) _badge(Icons.visibility_outlined, '看过', Colors.white70),
      if (downloaded) _badge(Icons.check_circle, '有下载', Colors.greenAccent),
    ],
  );

  Widget _badge(IconData icon, String text, Color color) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    ),
  );
}
