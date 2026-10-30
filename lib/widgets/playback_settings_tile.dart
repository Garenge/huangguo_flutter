import 'package:flutter/material.dart';

import '../services/playback_settings_service.dart';

class PlaybackSettingsTile extends StatelessWidget {
  const PlaybackSettingsTile({super.key, required this.settings});

  final PlaybackSettingsService settings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        title: const Text('离开播放页时暂停'),
        subtitle: const Text('关闭后，切换 App 内页面继续播放；切到系统后台仍暂停'),
        value: settings.pauseOnLeave,
        onChanged: settings.setPauseOnLeave,
      ),
    ),
  );
}
