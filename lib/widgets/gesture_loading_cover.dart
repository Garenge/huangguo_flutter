import 'package:flutter/material.dart';

import '../services/gesture_lock_service.dart';

class GestureLoadingCover extends StatelessWidget {
  const GestureLoadingCover({super.key, required this.service});

  final GestureLockService service;

  @override
  Widget build(BuildContext context) => Center(
    child: service.loadFailed
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('暂时无法读取解锁设置'),
              TextButton(onPressed: service.retryLoad, child: const Text('重试')),
            ],
          )
        : const CircularProgressIndicator(),
  );
}
