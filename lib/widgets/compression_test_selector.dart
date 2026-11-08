import 'package:flutter/material.dart';

import '../models/download_task.dart';
import '../services/download_catalog.dart';

class CompressionTestSelector extends StatelessWidget {
  const CompressionTestSelector({
    super.key,
    required this.tasks,
    required this.drama,
    required this.episode,
    required this.enabled,
    required this.onDramaChanged,
    required this.onEpisodeChanged,
  });

  final List<DownloadTask> tasks;
  final String? drama;
  final DownloadTask? episode;
  final bool enabled;
  final ValueChanged<String?> onDramaChanged;
  final ValueChanged<DownloadTask?> onEpisodeChanged;

  @override
  Widget build(BuildContext context) {
    final groups = DownloadCatalog.groupAndSort(tasks, DownloadSortMode.name);
    final episodes = [...?groups[drama]]..sort(_compareEpisodes);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _dramaField(groups)),
        const SizedBox(width: 12),
        Expanded(child: _episodeField(episodes)),
      ],
    );
  }

  int _compareEpisodes(DownloadTask a, DownloadTask b) {
    final aNumber = int.tryParse(
      RegExp(r'\d+').firstMatch(a.ep)?.group(0) ?? '',
    );
    final bNumber = int.tryParse(
      RegExp(r'\d+').firstMatch(b.ep)?.group(0) ?? '',
    );
    if (aNumber != null && bNumber != null && aNumber != bNumber) {
      return aNumber.compareTo(bNumber);
    }
    return a.episodeName.compareTo(b.episodeName);
  }

  Widget _dramaField(Map<String, List<DownloadTask>> groups) {
    return DropdownButtonFormField<String>(
      key: ValueKey('compression-drama-$drama'),
      initialValue: drama,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '选择剧名'),
      items: groups.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(
                entry.value.first.dramaName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: enabled ? onDramaChanged : null,
    );
  }

  Widget _episodeField(List<DownloadTask> episodes) {
    return DropdownButtonFormField<String>(
      key: ValueKey('compression-episode-${episode?.id}-$drama'),
      initialValue: episode?.id,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '选择集数'),
      items: episodes
          .map(
            (task) => DropdownMenuItem(
              value: task.id,
              child: Text(
                task.episodeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: enabled && drama != null
          ? (id) => onEpisodeChanged(
              episodes.where((task) => task.id == id).firstOrNull,
            )
          : null,
    );
  }
}
