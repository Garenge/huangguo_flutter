import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/app_log.dart';
import '../services/playback_coordinator.dart';
import '../services/playback_session.dart';
import '../services/playback_settings_service.dart';
import 'app_video_player.dart';
import 'playback_scope.dart';

class CompressionTestPreview extends StatefulWidget {
  const CompressionTestPreview({super.key});

  @override
  State<CompressionTestPreview> createState() => CompressionTestPreviewState();
}

class CompressionTestPreviewState extends State<CompressionTestPreview>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  PlaybackSession? _session;
  PlaybackSettingsService? _ownedSettings;
  Future<void> _pending = Future.value();
  Future<void>? _releaseFuture;
  int _generation = 0;
  bool _loading = false;
  String _title = '选择视频后点击预览';
  String? _error;
  String? _path;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session != null) return;
    final scope = PlaybackScope.maybeOf(context);
    _session = PlaybackSession(
      scope?.settings ?? (_ownedSettings = PlaybackSettingsService()),
      scope?.coordinator ?? PlaybackCoordinator(),
    );
  }

  Future<void> show(String path, String title) {
    final position = _controller?.value.position ?? Duration.zero;
    final generation = ++_generation;
    return _pending = _load(path, title, position, generation);
  }

  Future<void> _load(
    String path,
    String title,
    Duration position,
    int generation,
  ) async {
    final previous = _controller;
    _controller = null;
    _session!.controller = null;
    setState(() {
      _title = title;
      _path = path;
      _loading = true;
      _error = null;
    });
    VideoPlayerController? candidate;
    try {
      await previous?.dispose();
      await _session!.begin();
      candidate = VideoPlayerController.file(File(path));
      await candidate.initialize();
      if (!mounted || generation != _generation) {
        await candidate.dispose();
        return;
      }
      await candidate.seekTo(
        position > candidate.value.duration
            ? candidate.value.duration
            : position,
      );
      await _session!.attach(candidate);
      if (!mounted || generation != _generation) {
        await candidate.dispose();
        return;
      }
      setState(() {
        _controller = candidate;
        _loading = false;
      });
      await _session!.play();
    } catch (error, stack) {
      await candidate?.dispose();
      const AppLog(
        'compression_test_preview.dart',
      ).e('_load: 测试视频预览失败', error, stack);
      if (!mounted || generation != _generation) return;
      setState(() {
        _controller = null;
        _loading = false;
        _error = '预览失败：$error';
      });
    }
  }

  Future<void> release() => _releaseFuture ??= _release().whenComplete(() {
    _releaseFuture = null;
  });

  Future<void> _release() async {
    _generation++;
    await _pending;
    final previous = _controller;
    _controller = null;
    _session?.controller = null;
    await previous?.dispose();
    if (mounted) {
      setState(() {
        _loading = false;
        _path = null;
        _error = null;
        _title = '选择视频后点击预览';
      });
    }
  }

  @override
  void dispose() {
    unawaited(release());
    _session?.dispose();
    _ownedSettings?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_path == null) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        color: Colors.black,
        child: Text(_title, style: const TextStyle(color: Colors.white54)),
      );
    }
    return SizedBox(
      height: 220,
      child: AppVideoPlayer(
        controller: _controller,
        session: _session,
        title: _title,
        loading: _loading,
        error: _error,
        onRetry: () => show(_path!, _title),
      ),
    );
  }
}
