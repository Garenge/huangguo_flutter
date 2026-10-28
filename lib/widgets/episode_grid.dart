import 'package:flutter/material.dart';
import '../models/episode.dart';

class EpisodeGrid extends StatelessWidget {
  final List<Episode> episodes;
  final String? currentEp;
  final void Function(Episode episode) onTap;

  const EpisodeGrid({
    super.key,
    required this.episodes,
    this.currentEp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '\u6ca1\u6709\u89e3\u6790\u5230\u5267\u96c6',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: episodes.map((ep) {
        final isCurrent = ep.ep == currentEp;
        return ActionChip(
          label: Text(
            ep.name,
            style: TextStyle(
              color: isCurrent ? Colors.black : Colors.white,
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          backgroundColor: isCurrent
              ? Colors.orange
              : Colors.white.withOpacity(0.1),
          side: BorderSide.none,
          onPressed: () => onTap(ep),
        );
      }).toList(),
    );
  }
}
